// swiftlint:disable file_length
import ExFig_Android
import ExFig_Flutter
import ExFig_iOS
import ExFig_Web
import ExFigCore
import FigmaAPI
import Foundation
import Logging

/// Output type for icons loading operations.
typealias IconsLoaderOutput = (light: [ImagePack], dark: [ImagePack]?)

/// Output type for icons loading with granular cache tracking.
struct IconsLoaderResultWithHashes {
    let light: [ImagePack]
    let dark: [ImagePack]?
    /// Computed hashes for granular cache update (fileId → (nodeId → hash)).
    let computedHashes: [String: [NodeId: String]]
    /// Whether all icons were skipped by granular cache.
    let allSkipped: Bool
    /// All asset metadata before filtering (for Code Connect and template generation).
    /// Use `allAssetMetadata.map(\.name)` to get names for template generation.
    let allAssetMetadata: [AssetMetadata]
}

/// Configuration for loading icons, supporting both single-entry and multi-entry modes.
struct IconsLoaderConfig {
    /// Entry-level Figma file ID override (takes priority over platform-level).
    let entryFileId: String?

    /// Figma frame name to load icons from.
    let frameName: String

    /// Optional page name to filter icons by.
    let pageName: String?

    /// Icon format for iOS (pdf or svg). Android always uses svg.
    let format: VectorFormat?

    /// Render mode for iOS icons.
    let renderMode: XcodeRenderMode?
    let renderModeDefaultSuffix: String?
    let renderModeOriginalSuffix: String?
    let renderModeTemplateSuffix: String?

    /// Figma component property name for RTL variant detection.
    let rtlProperty: String?

    /// Creates config for a specific iOS icons entry.
    static func forIOS(entry: iOSIconsEntry, params: PKLConfig) -> IconsLoaderConfig {
        IconsLoaderConfig(
            entryFileId: entry.figmaFileId,
            frameName: entry.figmaFrameName ?? params.common?.icons?.figmaFrameName ?? "Icons",
            pageName: entry.figmaPageName ?? params.common?.icons?.figmaPageName,
            format: VectorFormat(rawValue: entry.format.rawValue) ?? .svg,
            renderMode: entry.coreRenderMode,
            renderModeDefaultSuffix: entry.renderModeDefaultSuffix,
            renderModeOriginalSuffix: entry.renderModeOriginalSuffix,
            renderModeTemplateSuffix: entry.renderModeTemplateSuffix,
            rtlProperty: entry.rtlProperty
        )
    }

    /// Creates config for Android (no iOS-specific fields needed).
    static func forAndroid(entry: AndroidIconsEntry, params: PKLConfig) -> IconsLoaderConfig {
        IconsLoaderConfig(
            entryFileId: entry.figmaFileId,
            frameName: entry.figmaFrameName ?? params.common?.icons?.figmaFrameName ?? "Icons",
            pageName: entry.figmaPageName ?? params.common?.icons?.figmaPageName,
            format: nil,
            renderMode: nil,
            renderModeDefaultSuffix: nil,
            renderModeOriginalSuffix: nil,
            renderModeTemplateSuffix: nil,
            rtlProperty: entry.rtlProperty
        )
    }

    /// Creates config for Flutter (no iOS-specific fields needed).
    static func forFlutter(entry: FlutterIconsEntry, params: PKLConfig) -> IconsLoaderConfig {
        IconsLoaderConfig(
            entryFileId: entry.figmaFileId,
            frameName: entry.figmaFrameName ?? params.common?.icons?.figmaFrameName ?? "Icons",
            pageName: entry.figmaPageName ?? params.common?.icons?.figmaPageName,
            format: nil,
            renderMode: nil,
            renderModeDefaultSuffix: nil,
            renderModeOriginalSuffix: nil,
            renderModeTemplateSuffix: nil,
            rtlProperty: entry.rtlProperty
        )
    }

    /// Creates config for Web (no iOS-specific fields needed).
    static func forWeb(entry: WebIconsEntry, params: PKLConfig) -> IconsLoaderConfig {
        IconsLoaderConfig(
            entryFileId: entry.figmaFileId,
            frameName: entry.figmaFrameName ?? params.common?.icons?.figmaFrameName ?? "Icons",
            pageName: entry.figmaPageName ?? params.common?.icons?.figmaPageName,
            format: nil,
            renderMode: nil,
            renderModeDefaultSuffix: nil,
            renderModeOriginalSuffix: nil,
            renderModeTemplateSuffix: nil,
            rtlProperty: entry.rtlProperty
        )
    }

    /// Creates default config using common.icons.figmaFrameName or "Icons".
    static func defaultConfig(params: PKLConfig) -> IconsLoaderConfig {
        IconsLoaderConfig(
            entryFileId: nil,
            frameName: params.common?.icons?.figmaFrameName ?? "Icons",
            pageName: params.common?.icons?.figmaPageName,
            format: nil,
            renderMode: nil,
            renderModeDefaultSuffix: nil,
            renderModeOriginalSuffix: nil,
            renderModeTemplateSuffix: nil,
            rtlProperty: Component.defaultRTLProperty
        )
    }
}

/// Loads icons from Figma files.
final class IconsLoader: ImageLoaderBase, @unchecked Sendable {
    private let config: IconsLoaderConfig

    init(
        client: Client,
        params: PKLConfig,
        platform: Platform,
        logger: Logger,
        config: IconsLoaderConfig? = nil
    ) {
        self.config = config ?? IconsLoaderConfig.defaultConfig(params: params)
        super.init(client: client, params: params, platform: platform, logger: logger)
    }

    private var frameName: String {
        config.frameName
    }

    private var pageName: String? {
        config.pageName
    }

    /// Loads icons from Figma, supporting both single-file and separate light/dark file modes.
    func load(
        filter: String? = nil,
        onBatchProgress: @escaping BatchProgressCallback = { _, _ in }
    ) async throws -> IconsLoaderOutput {
        if params.common?.icons?.suffixDarkMode != nil {
            try await loadFromSingleFile(filter: filter, onBatchProgress: onBatchProgress)
        } else {
            try await loadFromLightAndDarkFile(filter: filter, onBatchProgress: onBatchProgress)
        }
    }

    /// Loads icons with granular cache tracking for per-node change detection.
    ///
    /// When `granularCacheManager` is set, this method computes hashes for each icon
    /// component and filters to only changed icons. Returns computed hashes for
    /// cache update after successful export.
    func loadWithGranularCache(
        filter: String? = nil,
        onBatchProgress: @escaping BatchProgressCallback = { _, _ in }
    ) async throws -> IconsLoaderResultWithHashes {
        if params.common?.icons?.suffixDarkMode != nil {
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
    ) async throws -> IconsLoaderOutput {
        let formatParams = makeFormatParams()
        let fileId = try requireLightFileId(entryFileId: config.entryFileId)

        let icons = try await loadVectorImages(
            fileId: fileId,
            frameName: frameName,
            pageName: pageName,
            params: formatParams,
            filter: filter,
            rtlProperty: config.rtlProperty,
            onBatchProgress: onBatchProgress
        )

        let darkSuffix = params.common?.icons?.suffixDarkMode?.suffix ?? "_dark"
        let (lightIcons, darkIcons) = splitByDarkMode(icons, darkSuffix: darkSuffix)

        return (
            lightIcons.map { updateRenderMode($0) },
            darkIcons.map { updateRenderMode($0) }
        )
    }

    private func loadFromLightAndDarkFile(
        filter: String? = nil,
        onBatchProgress: @escaping BatchProgressCallback
    ) async throws -> IconsLoaderOutput {
        // Build list of files to load
        let lightFileId = try requireLightFileId(entryFileId: config.entryFileId)
        var filesToLoad: [(key: String, fileId: String)] = [
            ("light", lightFileId),
        ]
        if let darkFileId = params.figma?.darkFileId {
            filesToLoad.append(("dark", darkFileId))
        }

        // Load all files in parallel
        let results = try await withThrowingTaskGroup(
            of: (String, [ImagePack]).self
        ) { [self] group in
            for (key, fileId) in filesToLoad {
                group.addTask { [key, fileId, filter, onBatchProgress] in
                    // Create format params inside task to avoid Sendable issues
                    let formatParams = self.makeFormatParams()

                    let icons = try await self.loadVectorImages(
                        fileId: fileId,
                        frameName: self.frameName,
                        pageName: self.pageName,
                        params: formatParams,
                        filter: filter,
                        rtlProperty: self.config.rtlProperty,
                        onBatchProgress: onBatchProgress
                    ).map { self.updateRenderMode($0) }
                    return (key, icons)
                }
            }

            var iconsByKey: [String: [ImagePack]] = [:]
            for try await (key, icons) in group {
                iconsByKey[key] = icons
            }
            return iconsByKey
        }

        guard let lightIcons = results["light"] else {
            throw ExFigError.componentsNotFound(frameName: frameName, pageName: pageName)
        }

        return (lightIcons, results["dark"])
    }

    // MARK: - Helpers

    private func makeFormatParams() -> FormatParams {
        switch (platform, config.format) {
        case (.android, _), (.flutter, _), (.web, _), (.ios, .svg):
            SVGParams()
        case (.ios, _):
            PDFParams()
        }
    }

    private func updateRenderMode(_ icon: ImagePack) -> ImagePack {
        // Filtering at suffixes
        var renderMode = config.renderMode ?? .template
        let defaultSuffix = renderMode == .template ? config.renderModeDefaultSuffix : nil
        let originalSuffix = renderMode == .template ? config.renderModeOriginalSuffix : nil
        let templateSuffix = renderMode != .template ? config.renderModeTemplateSuffix : nil
        var suffix: String?

        if let defaultSuffix, icon.name.hasSuffix(defaultSuffix) {
            renderMode = .default
            suffix = defaultSuffix
        } else if let originalSuffix, icon.name.hasSuffix(originalSuffix) {
            renderMode = .original
            suffix = originalSuffix
        } else if let templateSuffix, icon.name.hasSuffix(templateSuffix) {
            renderMode = .template
            suffix = templateSuffix
        }
        var newIcon = icon
        newIcon.name = String(icon.name.dropLast(suffix?.count ?? 0))
        newIcon.renderMode = renderMode
        return newIcon
    }

    // MARK: - Granular Cache Methods

    private func loadFromSingleFileWithGranularCache(
        filter: String? = nil,
        onBatchProgress: @escaping BatchProgressCallback
    ) async throws -> IconsLoaderResultWithHashes {
        let formatParams = makeFormatParams()
        let fileId = try requireLightFileId(entryFileId: config.entryFileId)
        let darkSuffix = params.common?.icons?.suffixDarkMode?.suffix ?? "_dark"

        // Use pairing-aware method to ensure light/dark pairs are exported together
        let result = try await loadVectorImagesWithGranularCacheAndPairing(
            fileId: fileId,
            frameName: frameName,
            pageName: pageName,
            params: formatParams,
            filter: filter,
            darkModeSuffix: darkSuffix,
            rtlProperty: config.rtlProperty,
            onBatchProgress: onBatchProgress
        )

        // Filter out dark mode metadata - they should not appear as separate properties
        let lightOnlyMetadata = result.allAssetMetadata.filter { !$0.name.hasSuffix(darkSuffix) }

        if result.allSkipped {
            return IconsLoaderResultWithHashes(
                light: [],
                dark: nil,
                computedHashes: [fileId: result.computedHashes],
                allSkipped: true,
                allAssetMetadata: lightOnlyMetadata
            )
        }

        let (lightIcons, darkIcons) = splitByDarkMode(result.packs, darkSuffix: darkSuffix)

        return IconsLoaderResultWithHashes(
            light: lightIcons.map { updateRenderMode($0) },
            dark: darkIcons.map { updateRenderMode($0) },
            computedHashes: [fileId: result.computedHashes],
            allSkipped: false,
            allAssetMetadata: lightOnlyMetadata
        )
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

    // swiftlint:disable:next function_body_length
    private func loadFromLightAndDarkFileWithGranularCache(
        filter: String? = nil,
        onBatchProgress: @escaping BatchProgressCallback
    ) async throws -> IconsLoaderResultWithHashes {
        // Build list of files to load
        let lightFileId = try requireLightFileId(entryFileId: config.entryFileId)
        var filesToLoad: [(key: String, fileId: String)] = [
            ("light", lightFileId),
        ]
        if let darkFileId = params.figma?.darkFileId {
            filesToLoad.append(("dark", darkFileId))
        }

        // Load all files in parallel
        let results = try await withThrowingTaskGroup(of: FileGranularResult.self) { [self] group in
            for (key, fileId) in filesToLoad {
                group.addTask { [key, fileId, filter, onBatchProgress] in
                    let formatParams = self.makeFormatParams()

                    let result = try await self.loadVectorImagesWithGranularCache(
                        fileId: fileId,
                        frameName: self.frameName,
                        pageName: self.pageName,
                        params: formatParams,
                        filter: filter,
                        rtlProperty: self.config.rtlProperty,
                        onBatchProgress: onBatchProgress
                    )

                    let packs = result.packs.map { self.updateRenderMode($0) }
                    return FileGranularResult(
                        key: key,
                        fileId: fileId,
                        packs: packs,
                        hashes: result.computedHashes,
                        allSkipped: result.allSkipped,
                        allAssetMetadata: result.allAssetMetadata
                    )
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
            return IconsLoaderResultWithHashes(
                light: [],
                dark: nil,
                computedHashes: computedHashes,
                allSkipped: true,
                allAssetMetadata: allAssetMetadata
            )
        }

        // Extract light and dark icons
        guard let lightResult else {
            throw ExFigError.componentsNotFound(frameName: frameName, pageName: pageName)
        }

        let darkResult = results.first(where: { $0.key == "dark" })

        return IconsLoaderResultWithHashes(
            light: lightResult.packs,
            dark: darkResult?.packs,
            computedHashes: computedHashes,
            allSkipped: false,
            allAssetMetadata: allAssetMetadata
        )
    }
}
