import ExFig_Android
import ExFig_Flutter
import ExFig_iOS
import ExFig_Web

// swiftlint:disable file_length
import ExFigConfig
import ExFigCore
import FigmaAPI
import Foundation
import Logging

/// Image format for loader configuration.
enum ImagesLoaderFormat {
    case svg
    case png
    case webp
}

/// Source format for fetching from Figma API.
enum ImagesSourceFormat {
    case png // Download PNG from Figma API (default)
    case svg // Download SVG and rasterize locally with resvg
}

/// Configuration for loading images from a specific Figma frame.
struct ImagesLoaderConfig {
    /// Entry-level Figma file ID override (takes priority over platform-level).
    let entryFileId: String?

    /// Figma frame name to load images from.
    let frameName: String

    /// Optional page name to filter images by.
    let pageName: String?

    /// Custom scales for raster images.
    let scales: [Double]?

    /// Image format (for Android/Flutter). iOS always uses PNG.
    let format: ImagesLoaderFormat?

    /// Source format for fetching from Figma API.
    /// When .svg, downloads SVG and rasterizes locally with resvg.
    let sourceFormat: ImagesSourceFormat

    /// Figma component property name for RTL variant detection.
    let rtlProperty: String?

    /// Creates config for a specific iOS images entry.
    static func forIOS(entry: iOSImagesEntry, params: PKLConfig) -> ImagesLoaderConfig {
        ImagesLoaderConfig(
            entryFileId: entry.figmaFileId,
            frameName: entry.figmaFrameName ?? params.common?.images?.figmaFrameName ?? "Illustrations",
            pageName: entry.figmaPageName ?? params.common?.images?.figmaPageName,
            scales: entry.scales,
            format: nil, // iOS always uses PNG output
            sourceFormat: convertSourceFormat(entry.sourceFormat),
            rtlProperty: entry.rtlProperty
        )
    }

    /// Creates config for a specific Android images entry.
    static func forAndroid(entry: AndroidImagesEntry, params: PKLConfig) -> ImagesLoaderConfig {
        ImagesLoaderConfig(
            entryFileId: entry.figmaFileId,
            frameName: entry.figmaFrameName ?? params.common?.images?.figmaFrameName ?? "Illustrations",
            pageName: entry.figmaPageName ?? params.common?.images?.figmaPageName,
            scales: entry.scales,
            format: convertAndroidFormat(entry.format),
            sourceFormat: convertSourceFormat(entry.sourceFormat),
            rtlProperty: entry.rtlProperty
        )
    }

    /// Creates config for a specific Flutter images entry.
    static func forFlutter(entry: FlutterImagesEntry, params: PKLConfig) -> ImagesLoaderConfig {
        ImagesLoaderConfig(
            entryFileId: entry.figmaFileId,
            frameName: entry.figmaFrameName ?? params.common?.images?.figmaFrameName ?? "Illustrations",
            pageName: entry.figmaPageName ?? params.common?.images?.figmaPageName,
            scales: entry.scales,
            format: entry.format.flatMap { convertFlutterFormat($0) },
            sourceFormat: convertSourceFormat(entry.sourceFormat),
            rtlProperty: entry.rtlProperty
        )
    }

    /// Creates config for a specific Web images entry.
    static func forWeb(entry: WebImagesEntry, params: PKLConfig) -> ImagesLoaderConfig {
        ImagesLoaderConfig(
            entryFileId: entry.figmaFileId,
            frameName: entry.figmaFrameName ?? params.common?.images?.figmaFrameName ?? "Illustrations",
            pageName: entry.figmaPageName ?? params.common?.images?.figmaPageName,
            scales: nil,
            format: .svg, // Web uses SVG by default
            sourceFormat: .svg, // Web always uses SVG source
            rtlProperty: entry.rtlProperty
        )
    }

    /// Creates default config from params (for backward compatibility).
    static func defaultConfig(params: PKLConfig) -> ImagesLoaderConfig {
        ImagesLoaderConfig(
            entryFileId: nil,
            frameName: params.common?.images?.figmaFrameName ?? "Illustrations",
            pageName: params.common?.images?.figmaPageName,
            scales: nil,
            format: nil,
            sourceFormat: .png,
            rtlProperty: Component.defaultRTLProperty
        )
    }

    private static func convertAndroidFormat(_ format: AndroidImageFormat) -> ImagesLoaderFormat {
        switch format {
        case .svg: .svg
        case .png: .png
        case .webp: .webp
        }
    }

    private static func convertFlutterFormat(_ format: FlutterImageFormat) -> ImagesLoaderFormat {
        switch format {
        case .svg: .svg
        case .png: .png
        case .webp: .webp
        }
    }

    private static func convertSourceFormat(_ sourceFormat: Common.SourceFormat?) -> ImagesSourceFormat {
        switch sourceFormat {
        case .svg: .svg
        case .png, nil: .png
        }
    }
}

/// Output type for images loading operations.
typealias ImagesLoaderOutput = (light: [ImagePack], dark: [ImagePack]?)

/// Output type for images loading with granular cache tracking (vector images only).
struct ImagesLoaderResultWithHashes {
    let light: [ImagePack]
    let dark: [ImagePack]?
    /// Computed hashes for granular cache update (fileId → (nodeId → hash)).
    let computedHashes: [String: [NodeId: String]]
    /// Whether all images were skipped by granular cache.
    let allSkipped: Bool
    /// All asset metadata before filtering (for Code Connect and template generation).
    /// Use `allAssetMetadata.map(\.name)` to get names for template generation.
    let allAssetMetadata: [AssetMetadata]
}

/// Loads images (illustrations) from Figma files.
final class ImagesLoader: ImageLoaderBase, @unchecked Sendable { // swiftlint:disable:this type_body_length
    private let config: ImagesLoaderConfig

    init(
        client: Client,
        params: PKLConfig,
        platform: Platform,
        logger: Logger,
        config: ImagesLoaderConfig? = nil
    ) {
        self.config = config ?? ImagesLoaderConfig.defaultConfig(params: params)
        super.init(client: client, params: params, platform: platform, logger: logger)
    }

    private var frameName: String {
        config.frameName
    }

    private var pageName: String? {
        config.pageName
    }

    /// Custom scales from config, or nil to use defaults.
    private var configScales: [Double]? {
        config.scales
    }

    /// Image format from config, determines raster vs vector loading.
    private var configFormat: ImagesLoaderFormat? {
        config.format
    }

    /// Whether the configured format is raster (PNG/WebP) or vector (SVG).
    private var isRasterFormat: Bool {
        switch (platform, configFormat) {
        case (.ios, _):
            // iOS always uses raster (PNG)
            true
        case (.android, .png), (.android, .webp), (.flutter, .png), (.flutter, .webp):
            true
        case (.android, .svg), (.flutter, .svg):
            false
        case (.android, nil), (.flutter, nil):
            // Default to raster for backward compatibility
            true
        case (.web, .svg), (.web, nil):
            // Web uses SVG by default
            false
        case (.web, .png), (.web, .webp):
            true
        }
    }

    /// Whether to use SVG as source format from Figma API.
    /// When true, SVG is fetched from Figma and rasterized locally with resvg.
    private var useSVGSource: Bool {
        config.sourceFormat == .svg
    }

    /// The source format to use when fetching from Figma API.
    var sourceFormat: ImagesSourceFormat {
        config.sourceFormat
    }

    /// Loads images from Figma, supporting both single-file and separate light/dark file modes.
    func load(
        filter: String? = nil,
        onBatchProgress: @escaping BatchProgressCallback = { _, _ in }
    ) async throws -> ImagesLoaderOutput {
        if let useSingleFile = params.common?.images?.useSingleFile, useSingleFile {
            try await loadFromSingleFile(filter: filter, onBatchProgress: onBatchProgress)
        } else {
            try await loadFromLightAndDarkFile(filter: filter, onBatchProgress: onBatchProgress)
        }
    }

    /// Loads images with granular cache tracking for per-node change detection.
    ///
    /// Note: Granular cache only applies to vector images (SVG format). For raster
    /// images (PNG/WebP), this method falls back to regular loading since they use
    /// multi-scale exports with different component loading.
    ///
    /// When `granularCacheManager` is set, this method computes hashes for each image
    /// component and filters to only changed images. Returns computed hashes for
    /// cache update after successful export.
    func loadWithGranularCache(
        filter: String? = nil,
        onBatchProgress: @escaping BatchProgressCallback = { _, _ in }
    ) async throws -> ImagesLoaderResultWithHashes {
        if let useSingleFile = params.common?.images?.useSingleFile, useSingleFile {
            try await loadFromSingleFileWithGranularCache(
                filter: filter, onBatchProgress: onBatchProgress
            )
        } else {
            try await loadFromLightAndDarkFileWithGranularCache(
                filter: filter, onBatchProgress: onBatchProgress
            )
        }
    }

    // MARK: - Private Loading Methods

    private func loadFromSingleFile(
        filter: String? = nil,
        onBatchProgress: @escaping BatchProgressCallback
    ) async throws -> ImagesLoaderOutput {
        let darkSuffix = params.common?.images?.darkModeSuffix ?? "_dark"
        let fileId = try requireLightFileId(entryFileId: config.entryFileId)

        if isRasterFormat, !useSVGSource {
            // PNG source: fetch PNG at multiple scales from Figma
            let scales = getScales(customScales: configScales)

            let images = try await loadPNGImages(
                fileId: fileId,
                frameName: frameName,
                pageName: pageName,
                filter: filter,
                scales: scales,
                rtlProperty: config.rtlProperty,
                onBatchProgress: onBatchProgress
            )
            let (lightImages, darkImages) = splitByDarkMode(images, darkSuffix: darkSuffix)
            return (lightImages, darkImages)
        } else {
            // SVG source or vector output: fetch SVG from Figma
            // For SVG source with raster output, export code will rasterize locally
            let pack = try await loadVectorImages(
                fileId: fileId,
                frameName: frameName,
                pageName: pageName,
                params: SVGParams(),
                filter: filter,
                rtlProperty: config.rtlProperty,
                onBatchProgress: onBatchProgress
            )
            let (lightPack, darkPack) = splitByDarkMode(pack, darkSuffix: darkSuffix)
            return (lightPack, darkPack)
        }
    }

    private func loadFromLightAndDarkFile(
        filter: String? = nil,
        onBatchProgress: @escaping BatchProgressCallback
    ) async throws -> ImagesLoaderOutput {
        // Build list of files to load
        let lightFileId = try requireLightFileId(entryFileId: config.entryFileId)
        var filesToLoad: [(key: String, fileId: String)] = [
            ("light", lightFileId),
        ]
        if let darkFileId = params.figma?.darkFileId {
            filesToLoad.append(("dark", darkFileId))
        }

        if isRasterFormat, !useSVGSource {
            // PNG source: fetch PNG at multiple scales from Figma
            return try await loadRasterImagesFromMultipleFiles(
                filesToLoad: filesToLoad,
                filter: filter,
                onBatchProgress: onBatchProgress
            )
        } else {
            // SVG source or vector output: fetch SVG from Figma
            return try await loadVectorImagesFromMultipleFiles(
                filesToLoad: filesToLoad,
                filter: filter,
                onBatchProgress: onBatchProgress
            )
        }
    }

    private func loadRasterImagesFromMultipleFiles(
        filesToLoad: [(key: String, fileId: String)],
        filter: String?,
        onBatchProgress: @escaping BatchProgressCallback
    ) async throws -> ImagesLoaderOutput {
        let scales = getScales(customScales: configScales)

        // Load all files in parallel for PNG/WebP
        let results = try await withThrowingTaskGroup(
            of: (String, [ImagePack]).self
        ) { [self] group in
            for (key, fileId) in filesToLoad {
                group.addTask { [key, fileId, filter, scales, onBatchProgress] in
                    let images = try await self.loadPNGImages(
                        fileId: fileId,
                        frameName: self.frameName,
                        pageName: self.pageName,
                        filter: filter,
                        scales: scales,
                        rtlProperty: self.config.rtlProperty,
                        onBatchProgress: onBatchProgress
                    )
                    return (key, images)
                }
            }

            var imagesByKey: [String: [ImagePack]] = [:]
            for try await (key, images) in group {
                imagesByKey[key] = images
            }
            return imagesByKey
        }

        guard let lightImages = results["light"] else {
            throw ExFigError.componentsNotFound(frameName: frameName, pageName: pageName)
        }

        return (lightImages, results["dark"])
    }

    private func loadVectorImagesFromMultipleFiles(
        filesToLoad: [(key: String, fileId: String)],
        filter: String?,
        onBatchProgress: @escaping BatchProgressCallback
    ) async throws -> ImagesLoaderOutput {
        // Load all files in parallel for SVG
        let results = try await withThrowingTaskGroup(
            of: (String, [ImagePack]).self
        ) { [self] group in
            for (key, fileId) in filesToLoad {
                group.addTask { [key, fileId, filter, onBatchProgress] in
                    let packs = try await self.loadVectorImages(
                        fileId: fileId,
                        frameName: self.frameName,
                        pageName: self.pageName,
                        params: SVGParams(),
                        filter: filter,
                        rtlProperty: self.config.rtlProperty,
                        onBatchProgress: onBatchProgress
                    )
                    return (key, packs)
                }
            }

            var packsByKey: [String: [ImagePack]] = [:]
            for try await (key, packs) in group {
                packsByKey[key] = packs
            }
            return packsByKey
        }

        guard let lightPacks = results["light"] else {
            throw ExFigError.componentsNotFound(frameName: frameName, pageName: pageName)
        }

        return (lightPacks, results["dark"])
    }

    // MARK: - Granular Cache Methods

    private func loadFromSingleFileWithGranularCache( // swiftlint:disable:this function_body_length
        filter: String? = nil,
        onBatchProgress: @escaping BatchProgressCallback
    ) async throws -> ImagesLoaderResultWithHashes {
        let fileId = try requireLightFileId(entryFileId: config.entryFileId)
        let darkSuffix = params.common?.images?.darkModeSuffix ?? "_dark"

        if isRasterFormat, !useSVGSource {
            // PNG source: Raster images (PNG/WebP) with granular cache
            let scales = getScales(customScales: configScales)

            let result = try await loadPNGImagesWithGranularCache(
                fileId: fileId,
                frameName: frameName,
                pageName: pageName,
                filter: filter,
                scales: scales,
                rtlProperty: config.rtlProperty,
                onBatchProgress: onBatchProgress
            )

            // Filter out dark mode metadata - they should not appear as separate properties
            let lightOnlyMetadata = result.allAssetMetadata.filter { !$0.name.hasSuffix(darkSuffix) }

            if result.allSkipped {
                return ImagesLoaderResultWithHashes(
                    light: [],
                    dark: nil,
                    computedHashes: [fileId: result.computedHashes],
                    allSkipped: true,
                    allAssetMetadata: lightOnlyMetadata
                )
            }

            let (lightImages, darkImages) = splitByDarkMode(result.packs, darkSuffix: darkSuffix)
            return ImagesLoaderResultWithHashes(
                light: lightImages,
                dark: darkImages,
                computedHashes: [fileId: result.computedHashes],
                allSkipped: false,
                allAssetMetadata: lightOnlyMetadata
            )
        } else {
            // SVG source or vector output: fetch SVG with granular cache
            let result = try await loadVectorImagesWithGranularCache(
                fileId: fileId,
                frameName: frameName,
                pageName: pageName,
                params: SVGParams(),
                filter: filter,
                rtlProperty: config.rtlProperty,
                onBatchProgress: onBatchProgress
            )

            // Filter out dark mode metadata - they should not appear as separate properties
            let lightOnlyMetadata = result.allAssetMetadata.filter { !$0.name.hasSuffix(darkSuffix) }

            if result.allSkipped {
                return ImagesLoaderResultWithHashes(
                    light: [],
                    dark: nil,
                    computedHashes: [fileId: result.computedHashes],
                    allSkipped: true,
                    allAssetMetadata: lightOnlyMetadata
                )
            }

            let (lightPacks, darkPacks) = splitByDarkMode(result.packs, darkSuffix: darkSuffix)
            return ImagesLoaderResultWithHashes(
                light: lightPacks,
                dark: darkPacks,
                computedHashes: [fileId: result.computedHashes],
                allSkipped: false,
                allAssetMetadata: lightOnlyMetadata
            )
        }
    }

    /// Result of loading a single file with granular cache.
    private struct FileGranularResult {
        let key: String
        let fileId: String
        let packs: [ImagePack]
        let hashes: [NodeId: String]
        let allSkipped: Bool
        let allAssetMetadata: [AssetMetadata]
    }

    private func loadFromLightAndDarkFileWithGranularCache( // swiftlint:disable:this function_body_length
        filter: String? = nil,
        onBatchProgress: @escaping BatchProgressCallback
    ) async throws -> ImagesLoaderResultWithHashes {
        // Build list of files to load
        let lightFileId = try requireLightFileId(entryFileId: config.entryFileId)
        var filesToLoad: [(key: String, fileId: String)] = [
            ("light", lightFileId),
        ]
        if let darkFileId = params.figma?.darkFileId {
            filesToLoad.append(("dark", darkFileId))
        }

        // Determine format and scales once (same for all files)
        // Use PNG loading only when raster format AND PNG source
        let usePNGLoading = isRasterFormat && !useSVGSource
        let scales = usePNGLoading ? getScales(customScales: configScales) : []

        // Load all files in parallel
        let results = try await withThrowingTaskGroup(of: FileGranularResult.self) { [self] group in
            for (key, fileId) in filesToLoad {
                group.addTask { [key, fileId, filter, onBatchProgress, usePNGLoading, scales] in
                    if usePNGLoading {
                        // PNG source: Raster images (PNG/WebP)
                        let result = try await self.loadPNGImagesWithGranularCache(
                            fileId: fileId,
                            frameName: self.frameName,
                            pageName: self.pageName,
                            filter: filter,
                            scales: scales,
                            rtlProperty: self.config.rtlProperty,
                            onBatchProgress: onBatchProgress
                        )
                        return FileGranularResult(
                            key: key,
                            fileId: fileId,
                            packs: result.packs,
                            hashes: result.computedHashes,
                            allSkipped: result.allSkipped,
                            allAssetMetadata: result.allAssetMetadata
                        )
                    } else {
                        // SVG source or vector output: fetch SVG
                        let result = try await self.loadVectorImagesWithGranularCache(
                            fileId: fileId,
                            frameName: self.frameName,
                            pageName: self.pageName,
                            params: SVGParams(),
                            filter: filter,
                            rtlProperty: self.config.rtlProperty,
                            onBatchProgress: onBatchProgress
                        )
                        return FileGranularResult(
                            key: key,
                            fileId: fileId,
                            packs: result.packs,
                            hashes: result.computedHashes,
                            allSkipped: result.allSkipped,
                            allAssetMetadata: result.allAssetMetadata
                        )
                    }
                }
            }

            var fileResults: [FileGranularResult] = []
            for try await result in group {
                fileResults.append(result)
            }
            return fileResults
        }

        // Build computed hashes map
        var computedHashes: [String: [NodeId: String]] = [:]
        for result in results {
            computedHashes[result.fileId] = result.hashes
        }

        // Collect all metadata from light file (primary source for template/Code Connect generation)
        let lightResult = results.first(where: { $0.key == "light" })
        let allAssetMetadata = lightResult?.allAssetMetadata ?? []

        // Check if all files were skipped
        let allSkipped = results.allSatisfy(\.allSkipped)
        if allSkipped {
            return ImagesLoaderResultWithHashes(
                light: [],
                dark: nil,
                computedHashes: computedHashes,
                allSkipped: true,
                allAssetMetadata: allAssetMetadata
            )
        }

        // Extract light and dark packs
        guard let lightResult else {
            throw ExFigError.componentsNotFound(frameName: frameName, pageName: pageName)
        }

        let darkResult = results.first(where: { $0.key == "dark" })

        return ImagesLoaderResultWithHashes(
            light: lightResult.packs,
            dark: darkResult?.packs,
            computedHashes: computedHashes,
            allSkipped: false,
            allAssetMetadata: allAssetMetadata
        )
    }
}
