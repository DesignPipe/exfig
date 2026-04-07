// swiftlint:disable file_length type_body_length
import ExFigCore
import FigmaAPI
import Foundation
import Logging

/// Callback for reporting batch progress (completed, total)
typealias BatchProgressCallback = @Sendable (Int, Int) -> Void

/// Result containing loaded images and optional granular cache data.
struct ImageLoaderResult {
    let light: [ImagePack]
    let dark: [ImagePack]?

    /// Node hashes computed during load (for granular cache update).
    /// Map of fileId -> (nodeId -> hash).
    let computedHashes: [String: [NodeId: String]]

    /// Whether granular cache filtered all nodes (nothing to export).
    let skippedByGranularCache: Bool
}

/// Result of loading images with granular cache tracking.
struct ImagesWithHashesResult {
    let packs: [ImagePack]
    let computedHashes: [NodeId: String]
    let allSkipped: Bool
    /// All asset metadata before filtering (for Code Connect and template generation).
    let allAssetMetadata: [AssetMetadata]
}

/// Base class for loading images from Figma.
/// Provides shared functionality for IconsLoader and ImagesLoader.
class ImageLoaderBase: @unchecked Sendable {
    let client: Client
    let params: PKLConfig
    let platform: Platform
    let logger: Logger

    /// Optional granular cache manager for per-node change detection.
    var granularCacheManager: GranularCacheManager?

    /// Optional components cache for deduplicating Components API calls across entries.
    var componentsCache: ComponentsCache?

    init(client: Client, params: PKLConfig, platform: Platform, logger: Logger) {
        self.client = client
        self.params = params
        self.platform = platform
        self.logger = logger
    }

    /// Returns the light file ID, throwing an error if not configured.
    /// Entry-level `entryFileId` takes priority over platform-level `figma.lightFileId`.
    func requireLightFileId(entryFileId: String? = nil) throws -> String {
        if let entryFileId {
            return entryFileId
        }
        guard let figmaParams = params.figma else {
            throw ExFigError.custom(errorString:
                "figma section is required for icons/images export."
            )
        }
        guard let fileId = figmaParams.lightFileId else {
            throw ExFigError.custom(errorString:
                "figma.lightFileId is required for icons/images export."
            )
        }
        return fileId
    }

    // MARK: - Component Loading

    /// Fetches image components from a Figma file filtered by frame name and platform.
    /// When `rtlProperty` is set, RTL active variants (matching `rtlActiveValues`) are filtered out.
    func fetchImageComponents(
        fileId: String,
        frameName: String,
        pageName: String? = nil,
        filter: String? = nil,
        rtlProperty: String? = Component.defaultRTLProperty,
        rtlActiveValues: [String]? = nil
    ) async throws -> [NodeId: Component] {
        let allComponents = try await loadComponents(fileId: fileId)
        var components = allComponents
            .filter {
                $0.containingFrame.name == frameName
                    && (pageName == nil || $0.containingFrame.pageName == pageName)
                    && $0.useForPlatform(platform)
            }

        if let pageName, components.isEmpty {
            let frameComponents = allComponents.filter { $0.containingFrame.name == frameName }
            if !frameComponents.isEmpty {
                let availablePages = Set(frameComponents.compactMap(\.containingFrame.pageName))
                let pages = availablePages.sorted().joined(separator: ", ")
                logger.info(
                    "Page filter '\(pageName)' matched no components in frame '\(frameName)'. Available pages: \(pages)"
                )
            }
        }

        // Skip RTL active variants: the base (inactive) icon is sufficient —
        // platforms mirror it at runtime (iOS languageDirection, Android autoMirrored).
        let beforeRTLFilter = components.count
        components = components.filter {
            !$0.shouldSkipAsRTLVariant(propertyName: rtlProperty, activeValues: rtlActiveValues)
        }
        let rtlSkipped = beforeRTLFilter - components.count
        if rtlSkipped > 0 {
            let activeDesc = (rtlActiveValues ?? ["On"]).joined(separator: "/")
            logger.info("Filtered out \(rtlSkipped) RTL=\(activeDesc) variant(s) from '\(frameName)'")
        }

        if let filter {
            let assetsFilter = AssetsFilter(filter: filter)
            components = components.filter { component -> Bool in
                assetsFilter.match(name: component.iconName)
            }
        }

        return Dictionary(uniqueKeysWithValues: components.map { ($0.nodeId, $0) })
    }

    /// Result of fetching components with granular cache filtering.
    struct GranularFilterResult {
        let components: [NodeId: Component]
        let computedHashes: [NodeId: String]
        let allSkipped: Bool
        /// All asset metadata before filtering (for Code Connect and template generation).
        /// Use `allAssetMetadata.map(\.name)` to get names for template generation.
        let allAssetMetadata: [AssetMetadata]
    }

    /// Fetches components with optional granular cache filtering.
    ///
    /// If `granularCacheManager` is set, this will:
    /// 1. Fetch all matching components
    /// 2. Compute hashes for each component
    /// 3. Filter to only components that have changed
    /// 4. Return computed hashes for cache update
    func fetchImageComponentsWithGranularCache(
        fileId: String,
        frameName: String,
        pageName: String? = nil,
        filter: String? = nil,
        rtlProperty: String? = Component.defaultRTLProperty,
        rtlActiveValues: [String]? = nil
    ) async throws -> GranularFilterResult {
        let allComponents = try await fetchImageComponents(
            fileId: fileId,
            frameName: frameName,
            pageName: pageName,
            filter: filter,
            rtlProperty: rtlProperty,
            rtlActiveValues: rtlActiveValues
        )

        logger.debug(
            "Granular cache: fileId=\(fileId), frameName=\(frameName), components before filter=\(allComponents.count)"
        )

        // Build metadata for all assets (for Code Connect and template generation)
        // Use component set data for variants: iconName for name, codeConnectNodeId for node ID.
        // Figma Code Connect rejects variant node IDs — requires top-level component/component set IDs.
        let allAssetMetadata = allComponents.map { _, component in
            AssetMetadata(name: component.iconName, nodeId: component.codeConnectNodeId, fileId: fileId)
        }

        guard let manager = granularCacheManager, !allComponents.isEmpty else {
            // No granular cache - return all components
            return GranularFilterResult(
                components: allComponents,
                computedHashes: [:],
                allSkipped: false,
                allAssetMetadata: allAssetMetadata
            )
        }

        // Apply granular cache filtering
        let result = try await manager.filterChangedComponents(
            fileId: fileId,
            components: allComponents
        )

        logger.debug(
            """
            Granular cache: changedComponents=\(result.changedComponents.count), \
            computedHashes=\(result.computedHashes.count)
            """
        )

        let allSkipped = result.changedComponents.isEmpty && !allComponents.isEmpty

        if allSkipped {
            logger.info(
                "Granular cache: All \(allComponents.count) components unchanged, skipping export"
            )
        } else if result.changedComponents.count < allComponents.count {
            let changed = result.changedComponents.count
            let total = allComponents.count
            logger.info("Granular cache: \(changed)/\(total) components changed")
        }

        return GranularFilterResult(
            components: result.changedComponents,
            computedHashes: result.computedHashes,
            allSkipped: allSkipped,
            allAssetMetadata: allAssetMetadata
        )
    }

    /// Fetches components with granular cache filtering and light/dark pairing.
    ///
    /// When using `useSingleFile` mode with dark mode suffix, if either the light
    /// or dark version of a component changes, both versions are included in the result.
    /// This ensures that the `ImagesProcessor` validation passes (it requires matching pairs).
    func fetchImageComponentsWithGranularCacheAndPairing(
        fileId: String,
        frameName: String,
        pageName: String? = nil,
        filter: String? = nil,
        darkModeSuffix: String,
        rtlProperty: String? = Component.defaultRTLProperty,
        rtlActiveValues: [String]? = nil
    ) async throws -> GranularFilterResult {
        let allComponents = try await fetchImageComponents(
            fileId: fileId, frameName: frameName, pageName: pageName, filter: filter, rtlProperty: rtlProperty,
            rtlActiveValues: rtlActiveValues
        )
        let allAssetMetadata = allComponents.map { _, component in
            AssetMetadata(name: component.iconName, nodeId: component.codeConnectNodeId, fileId: fileId)
        }

        guard let manager = granularCacheManager, !allComponents.isEmpty else {
            return GranularFilterResult(
                components: allComponents, computedHashes: [:],
                allSkipped: false, allAssetMetadata: allAssetMetadata
            )
        }

        let result = try await manager.filterChangedComponents(
            fileId: fileId, components: allComponents
        )

        if result.changedComponents.isEmpty {
            logger.info(
                "Granular cache: All \(allComponents.count) components unchanged, skipping export"
            )
            return GranularFilterResult(
                components: [:], computedHashes: result.computedHashes,
                allSkipped: true, allAssetMetadata: allAssetMetadata
            )
        }

        let pairedComponents = buildPairedComponents(
            allComponents: allComponents,
            changedComponents: result.changedComponents,
            darkModeSuffix: darkModeSuffix
        )

        logGranularCachePairingStats(
            changed: result.changedComponents.count, paired: pairedComponents.count,
            total: allComponents.count
        )

        return GranularFilterResult(
            components: pairedComponents, computedHashes: result.computedHashes,
            allSkipped: false, allAssetMetadata: allAssetMetadata
        )
    }

    /// Extracts the base name from a component name by removing the dark mode suffix if present.
    private func baseName(for name: String, darkModeSuffix: String) -> String {
        name.hasSuffix(darkModeSuffix) ? String(name.dropLast(darkModeSuffix.count)) : name
    }

    /// Builds paired components map including both light and dark versions when either changes.
    private func buildPairedComponents(
        allComponents: [NodeId: Component],
        changedComponents: [NodeId: Component],
        darkModeSuffix: String
    ) -> [NodeId: Component] {
        let changedBaseNames = Set(changedComponents.values.map {
            baseName(for: $0.iconName, darkModeSuffix: darkModeSuffix)
        })
        return allComponents.filter { _, component in
            changedBaseNames.contains(baseName(for: component.iconName, darkModeSuffix: darkModeSuffix))
        }
    }

    /// Logs granular cache statistics with pairing info.
    private func logGranularCachePairingStats(changed: Int, paired: Int, total: Int) {
        if paired > changed {
            logger.info("Granular cache: \(changed)/\(total) changed, \(paired) with pairs")
        } else {
            logger.info("Granular cache: \(changed)/\(total) components changed")
        }
    }

    /// Loads vector images (SVG/PDF) from Figma.
    func loadVectorImages(
        fileId: String,
        frameName: String,
        pageName: String? = nil,
        params: FormatParams,
        filter: String? = nil,
        rtlProperty: String? = Component.defaultRTLProperty,
        rtlActiveValues: [String]? = nil,
        onBatchProgress: @escaping BatchProgressCallback = { _, _ in }
    ) async throws -> [ImagePack] {
        let imagesDict = try await fetchImageComponents(
            fileId: fileId, frameName: frameName, pageName: pageName, filter: filter, rtlProperty: rtlProperty,
            rtlActiveValues: rtlActiveValues
        )
        return try await loadVectorImagesFromComponents(
            fileId: fileId,
            frameName: frameName,
            components: imagesDict,
            params: params,
            rtlProperty: rtlProperty,
            rtlActiveValues: rtlActiveValues,
            onBatchProgress: onBatchProgress
        )
    }

    /// Loads vector images with granular cache tracking.
    ///
    /// When `granularCacheManager` is set, this method:
    /// 1. Fetches all matching components
    /// 2. Computes content hashes for granular change detection
    /// 3. Filters to only changed components (if cache exists)
    /// 4. Returns computed hashes for cache update after export
    func loadVectorImagesWithGranularCache(
        fileId: String,
        frameName: String,
        pageName: String? = nil,
        params: FormatParams,
        filter: String? = nil,
        rtlProperty: String? = Component.defaultRTLProperty,
        rtlActiveValues: [String]? = nil,
        onBatchProgress: @escaping BatchProgressCallback = { _, _ in }
    ) async throws -> ImagesWithHashesResult {
        let filterResult = try await fetchImageComponentsWithGranularCache(
            fileId: fileId, frameName: frameName, pageName: pageName, filter: filter, rtlProperty: rtlProperty,
            rtlActiveValues: rtlActiveValues
        )
        return try await loadVectorImagesFromGranularFilterResult(
            fileId: fileId,
            frameName: frameName,
            filterResult: filterResult,
            params: params,
            rtlProperty: rtlProperty,
            rtlActiveValues: rtlActiveValues,
            onBatchProgress: onBatchProgress
        )
    }

    /// Loads vector images with granular cache tracking and light/dark pairing.
    ///
    /// When using `useSingleFile` mode with dark mode suffix, if either the light
    /// or dark version of a component changes, both versions are fetched and exported.
    /// This ensures that the `ImagesProcessor` validation passes (it requires matching pairs).
    func loadVectorImagesWithGranularCacheAndPairing(
        fileId: String,
        frameName: String,
        pageName: String? = nil,
        params: FormatParams,
        filter: String? = nil,
        darkModeSuffix: String,
        rtlProperty: String? = Component.defaultRTLProperty,
        rtlActiveValues: [String]? = nil,
        onBatchProgress: @escaping BatchProgressCallback = { _, _ in }
    ) async throws -> ImagesWithHashesResult {
        let filterResult = try await fetchImageComponentsWithGranularCacheAndPairing(
            fileId: fileId,
            frameName: frameName,
            pageName: pageName,
            filter: filter,
            darkModeSuffix: darkModeSuffix,
            rtlProperty: rtlProperty,
            rtlActiveValues: rtlActiveValues
        )
        return try await loadVectorImagesFromGranularFilterResult(
            fileId: fileId,
            frameName: frameName,
            filterResult: filterResult,
            params: params,
            rtlProperty: rtlProperty,
            rtlActiveValues: rtlActiveValues,
            onBatchProgress: onBatchProgress
        )
    }

    // MARK: - Private Vector Image Helpers

    /// Core implementation for loading vector images from pre-fetched components.
    private func loadVectorImagesFromComponents(
        fileId: String,
        frameName: String,
        components: [NodeId: Component],
        params: FormatParams,
        rtlProperty: String? = Component.defaultRTLProperty,
        rtlActiveValues: [String]? = nil,
        onBatchProgress: @escaping BatchProgressCallback
    ) async throws -> [ImagePack] {
        var imagesDict = components

        guard !imagesDict.isEmpty else {
            throw ExFigError.componentsNotFound(frameName: frameName, pageName: nil)
        }

        imagesDict = filterEmptyNameComponents(imagesDict)

        logger.info("Fetching \(imagesDict.count) images from '\(frameName)'...")
        let imageIdToImagePath = try await loadImages(
            fileId: fileId,
            imagesDict: imagesDict,
            params: params,
            onBatchProgress: onBatchProgress
        )

        imagesDict = removeFailedComponents(imagesDict, fetchedPaths: imageIdToImagePath)

        return createVectorImagePacks(
            imagesDict: imagesDict,
            imageIdToImagePath: imageIdToImagePath,
            format: params.format,
            fileId: fileId,
            rtlProperty: rtlProperty,
            rtlActiveValues: rtlActiveValues
        )
    }

    /// Loads vector images from a granular filter result, handling the early-skip case.
    private func loadVectorImagesFromGranularFilterResult(
        fileId: String,
        frameName: String,
        filterResult: GranularFilterResult,
        params: FormatParams,
        rtlProperty: String? = Component.defaultRTLProperty,
        rtlActiveValues: [String]? = nil,
        onBatchProgress: @escaping BatchProgressCallback
    ) async throws -> ImagesWithHashesResult {
        if filterResult.allSkipped {
            return ImagesWithHashesResult(
                packs: [],
                computedHashes: filterResult.computedHashes,
                allSkipped: true,
                allAssetMetadata: filterResult.allAssetMetadata
            )
        }

        let packs = try await loadVectorImagesFromComponents(
            fileId: fileId,
            frameName: frameName,
            components: filterResult.components,
            params: params,
            rtlProperty: rtlProperty,
            rtlActiveValues: rtlActiveValues,
            onBatchProgress: onBatchProgress
        )

        return ImagesWithHashesResult(
            packs: packs,
            computedHashes: filterResult.computedHashes,
            allSkipped: false,
            allAssetMetadata: filterResult.allAssetMetadata
        )
    }

    /// Filters out components with empty names and logs warnings for them.
    private func filterEmptyNameComponents(_ components: [NodeId: Component]) -> [NodeId: Component] {
        components.filter { _, component in
            if component.iconName.trimmingCharacters(in: .whitespaces).isEmpty {
                logger.warning(
                    """
                    Found a component with empty name.
                    Page name: \(component.containingFrame.pageName ?? "nil")
                    Frame: \(component.containingFrame.name ?? "nil")
                    Description: \(component.description ?? "nil")
                    The component wont be exported. Fix component name in the Figma file and try again.
                    """
                )
                return false
            }
            return true
        }
    }

    /// Removes components that failed to fetch from the images dict.
    private func removeFailedComponents(
        _ components: [NodeId: Component],
        fetchedPaths: [NodeId: ImagePath]
    ) -> [NodeId: Component] {
        let badNodeIds = Set(components.keys).symmetricDifference(Set(fetchedPaths.keys))
        var result = components
        for nodeId in badNodeIds {
            result.removeValue(forKey: nodeId)
        }
        return result
    }

    /// Creates image packs from components and their fetched image paths.
    private func createVectorImagePacks(
        imagesDict: [NodeId: Component],
        imageIdToImagePath: [NodeId: ImagePath],
        format: String,
        fileId: String,
        rtlProperty: String? = Component.defaultRTLProperty,
        rtlActiveValues: [String]? = nil
    ) -> [ImagePack] {
        let groups = Dictionary(grouping: imagesDict) {
            $1.iconName.parseNameAndIdiom(platform: platform).name
        }

        return groups.compactMap { packName, components -> ImagePack? in
            let packImages = components.compactMap { nodeId, component -> Image? in
                guard let urlString = imageIdToImagePath[nodeId],
                      let url = URL(string: urlString)
                else {
                    return nil
                }
                let (name, idiom) = component.iconName.parseNameAndIdiom(platform: platform)
                return Image(
                    name: name,
                    scale: .all,
                    idiom: idiom,
                    url: url,
                    format: format,
                    isRTL: component.useRTL(rtlProperty: rtlProperty)
                )
            }
            let primaryNodeId = components.first.map(\.1.codeConnectNodeId)
            return ImagePack(
                name: packName,
                images: packImages,
                platform: platform,
                nodeId: primaryNodeId,
                fileId: fileId
            )
        }
    }

    /// Loads PNG images from Figma at multiple scales.
    func loadPNGImages(
        fileId: String,
        frameName: String,
        pageName: String? = nil,
        filter: String? = nil,
        scales: [Double],
        rtlProperty: String? = Component.defaultRTLProperty,
        rtlActiveValues: [String]? = nil,
        onBatchProgress: @escaping BatchProgressCallback = { _, _ in }
    ) async throws -> [ImagePack] {
        let imagesDict = try await fetchImageComponents(
            fileId: fileId, frameName: frameName, pageName: pageName, filter: filter, rtlProperty: rtlProperty,
            rtlActiveValues: rtlActiveValues
        )
        return try await loadPNGImagesFromComponents(
            fileId: fileId,
            components: imagesDict,
            scales: scales,
            onBatchProgress: onBatchProgress
        )
    }

    /// Loads PNG/raster images with granular cache tracking.
    ///
    /// When `granularCacheManager` is set, this method:
    /// 1. Fetches all matching components
    /// 2. Computes content hashes for granular change detection
    /// 3. Filters to only changed components (if cache exists)
    /// 4. Returns computed hashes for cache update after export
    func loadPNGImagesWithGranularCache(
        fileId: String,
        frameName: String,
        pageName: String? = nil,
        filter: String? = nil,
        scales: [Double],
        rtlProperty: String? = Component.defaultRTLProperty,
        rtlActiveValues: [String]? = nil,
        onBatchProgress: @escaping BatchProgressCallback = { _, _ in }
    ) async throws -> ImagesWithHashesResult {
        let filterResult = try await fetchImageComponentsWithGranularCache(
            fileId: fileId, frameName: frameName, pageName: pageName, filter: filter, rtlProperty: rtlProperty,
            rtlActiveValues: rtlActiveValues
        )

        if filterResult.allSkipped {
            return ImagesWithHashesResult(
                packs: [],
                computedHashes: filterResult.computedHashes,
                allSkipped: true,
                allAssetMetadata: filterResult.allAssetMetadata
            )
        }

        let packs = try await loadPNGImagesFromComponents(
            fileId: fileId,
            components: filterResult.components,
            scales: scales,
            onBatchProgress: onBatchProgress
        )

        return ImagesWithHashesResult(
            packs: packs,
            computedHashes: filterResult.computedHashes,
            allSkipped: false,
            allAssetMetadata: filterResult.allAssetMetadata
        )
    }

    // MARK: - Private PNG Image Helpers

    /// Core implementation for loading PNG images from pre-fetched components.
    private func loadPNGImagesFromComponents(
        fileId: String,
        components: [NodeId: Component],
        scales: [Double],
        onBatchProgress: @escaping BatchProgressCallback
    ) async throws -> [ImagePack] {
        guard !components.isEmpty else {
            throw ExFigError.componentsNotFound(frameName: nil, pageName: nil)
        }

        let batchSize = 100
        let batchesPerScale = (components.count + batchSize - 1) / batchSize
        let totalBatches = batchesPerScale * scales.count
        let sharedCounter = CompletedBatchCounter()

        let images = try await loadImagesForAllScales(
            fileId: fileId,
            imagesDict: components,
            scales: scales,
            sharedCounter: sharedCounter,
            totalBatches: totalBatches,
            onBatchProgress: onBatchProgress
        )

        return createPNGImagePacks(
            imagesDict: components,
            imagesByScale: images,
            scales: scales,
            fileId: fileId
        )
    }

    /// Creates image packs from components and their fetched image paths at multiple scales.
    private func createPNGImagePacks(
        imagesDict: [NodeId: Component],
        imagesByScale: [Double: [NodeId: ImagePath]],
        scales: [Double],
        fileId: String
    ) -> [ImagePack] {
        let groups = Dictionary(grouping: imagesDict) {
            $1.iconName.parseNameAndIdiom(platform: platform).name
        }

        return groups.compactMap { packName, components -> ImagePack? in
            let packImages = components.flatMap { nodeId, component -> [Image] in
                let (name, idiom) = component.iconName.parseNameAndIdiom(platform: platform)
                return scales.compactMap { scale -> Image? in
                    guard let urlString = imagesByScale[scale]?[nodeId],
                          let url = URL(string: urlString)
                    else {
                        return nil
                    }
                    return Image(
                        name: name,
                        scale: .individual(scale),
                        idiom: idiom,
                        url: url,
                        format: "png"
                    )
                }
            }
            let primaryNodeId = components.first.map(\.1.codeConnectNodeId)
            return ImagePack(
                name: packName,
                images: packImages,
                platform: platform,
                nodeId: primaryNodeId,
                fileId: fileId
            )
        }
    }

    // MARK: - Scale Helpers

    /// Returns valid scales for the given platform, optionally filtered by custom scales.
    func getScales(customScales: [Double]?) -> [Double] {
        let validScales: [Double] = platform == .android ? [1, 2, 3, 1.5, 4.0] : [1, 2, 3]
        let filtered = customScales?.filter { validScales.contains($0) } ?? []
        return filtered.isEmpty ? validScales : filtered
    }

    // MARK: - Dark Mode Helpers

    /// Splits image packs into light and dark based on suffix.
    func splitByDarkMode(
        _ packs: [ImagePack],
        darkSuffix: String
    ) -> (light: [ImagePack], dark: [ImagePack]) {
        let lightPacks = packs.filter { !$0.name.hasSuffix(darkSuffix) }
        let darkPacks =
            packs
                .filter { $0.name.hasSuffix(darkSuffix) }
                .map { pack -> ImagePack in
                    var newPack = pack
                    newPack.name = String(pack.name.dropLast(darkSuffix.count))
                    return newPack
                }
        return (lightPacks, darkPacks)
    }

    // MARK: - Private Figma API Methods

    private func loadComponents(fileId: String) async throws -> [Component] {
        // Check pre-fetched components first (batch optimization)
        if let preFetched = BatchContextStorage.context?.components,
           let components = preFetched.components(for: fileId)
        {
            logger.debug("Using pre-fetched components for \(fileId) (\(components.count) components)")
            return components
        }

        // Check components cache (standalone multi-entry dedup)
        if let cache = componentsCache {
            return try await cache.get(fileId: fileId) {
                try await self.client.request(ComponentsEndpoint(fileId: fileId))
            }
        }

        // Fall back to direct API request (single entry)
        let endpoint = ComponentsEndpoint(fileId: fileId)
        return try await client.request(endpoint)
    }

    /// Loads images for all scales in parallel.
    private func loadImagesForAllScales( // swiftlint:disable:this function_parameter_count
        fileId: String,
        imagesDict: [NodeId: Component],
        scales: [Double],
        sharedCounter: CompletedBatchCounter,
        totalBatches: Int,
        onBatchProgress: @escaping BatchProgressCallback
    ) async throws -> [Double: [NodeId: ImagePath]] {
        try await withThrowingTaskGroup(
            of: (Double, [NodeId: ImagePath]).self
        ) { [self] group in
            for scale in scales {
                group.addTask { [fileId, imagesDict, sharedCounter, totalBatches, onBatchProgress] in
                    let result = try await self.loadImages(
                        fileId: fileId,
                        imagesDict: imagesDict,
                        params: PNGParams(scale: scale),
                        sharedCounter: sharedCounter,
                        totalBatches: totalBatches,
                        onBatchProgress: onBatchProgress
                    )
                    return (scale, result)
                }
            }
            var results: [Double: [NodeId: ImagePath]] = [:]
            for try await (scale, dict) in group {
                results[scale] = dict
            }
            return results
        }
    }

    private func loadImages(
        fileId: String,
        imagesDict: [NodeId: Component],
        params: FormatParams,
        sharedCounter: CompletedBatchCounter? = nil,
        totalBatches totalBatchesOverride: Int? = nil,
        onBatchProgress: @escaping BatchProgressCallback
    ) async throws -> [NodeId: ImagePath] {
        let batchSize = 100
        // Conservative concurrency limit to respect Figma API rate limits
        // (10-20 requests/min depending on plan)
        let maxConcurrentBatches = 3

        let nodeIds: [NodeId] = imagesDict.keys.map { $0 }
        let batches = nodeIds.chunked(into: batchSize)

        // Use shared counter and total if provided (for multi-scale loading),
        // otherwise create local counter (for single-scale/vector loading)
        let completedCounter = sharedCounter ?? CompletedBatchCounter()
        let totalBatches = totalBatchesOverride ?? batches.count

        // Capture format info for thread-safe closure (FormatParams is a class)
        let format = params.format
        let scale = params.scale

        // Load batches in parallel with limited concurrency
        let allResults = try await withThrowingTaskGroup(
            of: [(NodeId, ImagePath)].self
        ) { [self] group in
            var results: [[(NodeId, ImagePath)]] = []
            var activeTasks = 0

            for batch in batches {
                // If we've reached max concurrency, wait for one to complete
                if activeTasks >= maxConcurrentBatches {
                    if let batchResult = try await group.next() {
                        results.append(batchResult)
                        activeTasks -= 1
                        let completed = completedCounter.increment()
                        onBatchProgress(completed, totalBatches)
                    }
                }

                // Start new batch task
                group.addTask { [batch, fileId, format, scale, imagesDict] in
                    try await self.loadImageBatch(
                        fileId: fileId,
                        nodeIds: batch,
                        format: format,
                        scale: scale,
                        imagesDict: imagesDict
                    )
                }
                activeTasks += 1
            }

            // Collect remaining results
            for try await batchResult in group {
                results.append(batchResult)
                let completed = completedCounter.increment()
                onBatchProgress(completed, totalBatches)
            }

            return results.flatMap { $0 }
        }

        return Dictionary(uniqueKeysWithValues: allResults)
    }

    private func loadImageBatch(
        fileId: String,
        nodeIds: [NodeId],
        format: String,
        scale: Double?,
        imagesDict: [NodeId: Component]
    ) async throws -> [(NodeId, ImagePath)] {
        // Recreate FormatParams inside task to avoid Sendable issues
        let params: FormatParams =
            switch format {
            case "svg": SVGParams()
            case "pdf": PDFParams()
            case "png" where scale != nil: PNGParams(scale: scale!)
            default: FormatParams(scale: scale, format: format)
            }

        let endpoint = ImageEndpoint(fileId: fileId, nodeIds: nodeIds, params: params)
        let dict = try await client.request(endpoint)

        return dict.compactMap { nodeId, imagePath in
            if let imagePath {
                return (nodeId, imagePath)
            } else {
                let component = imagesDict[nodeId]
                let iconName = component?.iconName ?? ""
                let variantName = component?.name ?? ""
                let displayName = iconName == variantName ? iconName : "\(iconName) (\(variantName))"
                let errorMsg =
                    "Unable to get image for node with id = \(nodeId). "
                        + "Please check that component \(displayName) in the Figma file is not empty. Skipping..."
                logger.error("\(errorMsg)")
                return nil
            }
        }
    }
}

// MARK: - String Utils

extension String {
    /// Cached regex for parsing idiom suffix (e.g., "icon~ipad" -> name: "icon", idiom: "ipad")
    private static let idiomRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "(.*)~(.*)$"
    )

    func parseNameAndIdiom(platform: Platform) -> (name: String, idiom: String) {
        switch platform {
        case .android, .flutter, .web:
            return (self, "")
        case .ios:
            guard let regex = Self.idiomRegex,
                  let match = regex.firstMatch(in: self, range: NSRange(startIndex..., in: self)),
                  let name = Range(match.range(at: 1), in: self),
                  let idiom = Range(match.range(at: 2), in: self)
            else {
                return (self, "")
            }
            return (String(self[name]), String(self[idiom]))
        }
    }
}

// MARK: - Component Extensions

public extension Component {
    /// Checks if component should be used for the specified platform based on its description.
    func useForPlatform(_ platform: Platform) -> Bool {
        guard let description, !description.isEmpty else {
            return true
        }

        let platformKeywords = ["ios", "android", "none"]
        let containsAnyKeyword = platformKeywords.contains { description.contains($0) }

        if !containsAnyKeyword {
            return true
        }

        switch platform {
        case .ios:
            return description.contains("ios")
        case .android:
            return description.contains("android")
        case .flutter, .web:
            return false
        }
    }

    /// Real icon name: component set name for variants, own name otherwise.
    var iconName: String {
        containingFrame.containingComponentSet?.name ?? name
    }

    /// Node ID for Code Connect: component set ID for variants, own ID otherwise.
    /// Figma Code Connect rejects variant node IDs — use this to avoid
    /// "node is not a top level component or component set" errors.
    var codeConnectNodeId: String {
        containingFrame.containingComponentSet?.nodeId ?? nodeId
    }

    /// Extracts the RTL variant value from the component name (e.g. "Off" from "RTL=Off").
    /// Parses "Property=Value, Property2=Value2" format used by Figma variant components.
    func rtlVariantValue(propertyName: String) -> String? {
        for pair in name.split(separator: ",") {
            let trimmed = pair.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: "=", maxSplits: 1)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, parts[0] == propertyName {
                return parts[1]
            }
        }
        return nil
    }

    /// Default Figma component property name for RTL variant detection.
    static let defaultRTLProperty = "RTL"

    /// Whether this component should be skipped (RTL active variant).
    func shouldSkipAsRTLVariant(propertyName: String?, activeValues: [String]? = nil) -> Bool {
        guard let prop = propertyName, !prop.isEmpty else { return false }
        guard let value = rtlVariantValue(propertyName: prop) else { return false }
        let active = activeValues ?? ["On"]
        return active.contains(value)
    }

    /// Determines RTL support: variant property (primary), then description (fallback).
    func useRTL(rtlProperty: String? = nil) -> Bool {
        // 1. Variant-based detection (primary)
        if let prop = rtlProperty, !prop.isEmpty, rtlVariantValue(propertyName: prop) != nil {
            return true // Presence of RTL variant = icon supports RTL
        }
        // 2. Fallback: description
        guard let description, !description.isEmpty else { return false }
        return description.localizedCaseInsensitiveContains("rtl")
    }
}

// MARK: - Thread-safe Counter

/// Thread-safe counter for tracking completed batches across concurrent tasks.
final class CompletedBatchCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    /// Increments the counter and returns the new value.
    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count
    }
}
