import Foundation

// MARK: - Icons Export Context

/// Context for icons export operations.
///
/// Extends `ExportContext` with icons-specific functionality
/// like loading icons from Figma frames and processing them.
public protocol IconsExportContext: ExportContext {
    /// Loads icons from a Figma frame.
    ///
    /// - Parameter source: Icons source configuration.
    /// - Returns: Loaded icons output (light, dark variants).
    func loadIcons(from source: IconsSourceInput) async throws -> IconsLoadOutput

    /// Processes icons into platform-specific format.
    ///
    /// - Parameters:
    ///   - icons: Raw icons from Figma.
    ///   - platform: Target platform.
    ///   - nameValidateRegexp: Optional regex for name validation.
    ///   - nameReplaceRegexp: Optional regex for name replacement.
    ///   - nameStyle: Naming style for generated code.
    /// - Returns: Processed icon pairs.
    func processIcons(
        _ icons: IconsLoadOutput,
        platform: Platform,
        nameValidateRegexp: String?,
        nameReplaceRegexp: String?,
        nameStyle: NameStyle
    ) throws -> IconsProcessResult

    /// Downloads remote files with progress reporting.
    ///
    /// In batch mode, uses `PipelinedDownloader` with shared queue for ~45% speedup.
    /// In standalone mode, uses direct file downloader.
    ///
    /// - Parameters:
    ///   - files: Files to download (may contain remote URLs).
    ///   - progressTitle: Title for the progress bar.
    /// - Returns: Files with downloaded data populated.
    func downloadFiles(
        _ files: [FileContents],
        progressTitle: String
    ) async throws -> [FileContents]

    /// Runs an operation with a progress bar.
    ///
    /// - Parameters:
    ///   - title: Progress bar title.
    ///   - total: Total number of items.
    ///   - operation: The operation to run, receives progress callback.
    /// - Returns: The operation result.
    func withProgress<T: Sendable>(
        _ title: String,
        total: Int,
        operation: @escaping @Sendable (ProgressReporter) async throws -> T
    ) async throws -> T
}

/// Input for loading icons from Figma.
public struct IconsSourceInput: Sendable {
    /// Design source kind (default: `.figma`).
    public let sourceKind: DesignSourceKind

    /// Optional entry-level Figma file ID override.
    public let figmaFileId: String?

    /// Optional dark mode file ID (if separate files for light/dark).
    public let darkFileId: String?

    /// The frame name containing icons.
    public let frameName: String

    /// Optional page name to filter icons by.
    public let pageName: String?

    /// Icon format (svg or pdf, iOS only).
    public let format: VectorFormat

    /// Whether to use single file with dark mode suffix.
    public let useSingleFile: Bool

    /// Suffix for dark mode icons when using single file.
    public let darkModeSuffix: String

    /// iOS render mode settings.
    public let renderMode: XcodeRenderMode?
    public let renderModeDefaultSuffix: String?
    public let renderModeOriginalSuffix: String?
    public let renderModeTemplateSuffix: String?

    /// Figma component property name for RTL variant detection.
    /// Default: `"RTL"`. Set to `nil` to disable variant-based RTL detection.
    public let rtlProperty: String?

    /// Name validation regex.
    public let nameValidateRegexp: String?

    /// Name replacement regex.
    public let nameReplaceRegexp: String?

    /// Penpot instance base URL (used when sourceKind == .penpot).
    public let penpotBaseURL: String?

    /// Variable collection name for dark mode generation via Figma Variables.
    public let variablesCollectionName: String?

    /// Light mode name in the variables collection.
    public let variablesLightModeName: String?

    /// Dark mode name in the variables collection.
    public let variablesDarkModeName: String?

    /// Primitives mode name for resolving variable aliases.
    public let variablesPrimitivesModeName: String?

    /// Figma file ID for loading variables (when primitives are in a separate library file).
    public let variablesFileId: String?

    public init(
        sourceKind: DesignSourceKind = .figma,
        figmaFileId: String? = nil,
        darkFileId: String? = nil,
        frameName: String,
        pageName: String? = nil,
        format: VectorFormat = .svg,
        useSingleFile: Bool = false,
        darkModeSuffix: String = "_dark",
        renderMode: XcodeRenderMode? = nil,
        renderModeDefaultSuffix: String? = nil,
        renderModeOriginalSuffix: String? = nil,
        renderModeTemplateSuffix: String? = nil,
        rtlProperty: String? = "RTL",
        nameValidateRegexp: String? = nil,
        nameReplaceRegexp: String? = nil,
        penpotBaseURL: String? = nil,
        variablesCollectionName: String? = nil,
        variablesLightModeName: String? = nil,
        variablesDarkModeName: String? = nil,
        variablesPrimitivesModeName: String? = nil,
        variablesFileId: String? = nil
    ) {
        self.sourceKind = sourceKind
        self.figmaFileId = figmaFileId
        self.darkFileId = darkFileId
        self.frameName = frameName
        self.pageName = pageName
        self.format = format
        self.useSingleFile = useSingleFile
        self.darkModeSuffix = darkModeSuffix
        self.renderMode = renderMode
        self.renderModeDefaultSuffix = renderModeDefaultSuffix
        self.renderModeOriginalSuffix = renderModeOriginalSuffix
        self.renderModeTemplateSuffix = renderModeTemplateSuffix
        self.rtlProperty = rtlProperty
        self.nameValidateRegexp = nameValidateRegexp
        self.nameReplaceRegexp = nameReplaceRegexp
        self.penpotBaseURL = penpotBaseURL
        self.variablesCollectionName = variablesCollectionName
        self.variablesLightModeName = variablesLightModeName
        self.variablesDarkModeName = variablesDarkModeName
        self.variablesPrimitivesModeName = variablesPrimitivesModeName
        self.variablesFileId = variablesFileId
    }
}

/// Vector format for icons.
public enum VectorFormat: String, Sendable, Decodable {
    case svg
    case pdf
}

/// Output from icons loading.
public struct IconsLoadOutput: Sendable {
    public let light: [ImagePack]
    public let dark: [ImagePack]

    public init(
        light: [ImagePack],
        dark: [ImagePack] = []
    ) {
        self.light = light
        self.dark = dark
    }
}

/// Result from icons processing.
public struct IconsProcessResult: Sendable {
    public let iconPairs: [AssetPair<ImagePack>]
    public let warning: String?

    public init(iconPairs: [AssetPair<ImagePack>], warning: String? = nil) {
        self.iconPairs = iconPairs
        self.warning = warning
    }
}

/// Protocol for reporting progress updates.
public protocol ProgressReporter: Sendable {
    /// Updates progress to specific value.
    func update(current: Int)

    /// Increments progress by one.
    func increment()
}

// MARK: - Granular Cache Support

/// Extended icons load output with granular cache hashes.
///
/// Used when granular cache is enabled to return both icons and
/// computed hashes for cache updates.
public struct IconsLoadOutputWithHashes: Sendable {
    /// Loaded light mode icons.
    public let light: [ImagePack]

    /// Loaded dark mode icons (if available).
    public let dark: [ImagePack]

    /// Computed content hashes for cache update (fileId → (nodeId → hash)).
    public let computedHashes: [String: [String: String]]

    /// Whether all icons were skipped (unchanged from cache).
    public let allSkipped: Bool

    /// All asset metadata (for template generation even when icons skipped).
    public let allAssetMetadata: [AssetMetadata]

    public init(
        light: [ImagePack],
        dark: [ImagePack] = [],
        computedHashes: [String: [String: String]] = [:],
        allSkipped: Bool = false,
        allAssetMetadata: [AssetMetadata] = []
    ) {
        self.light = light
        self.dark = dark
        self.computedHashes = computedHashes
        self.allSkipped = allSkipped
        self.allAssetMetadata = allAssetMetadata
    }

    /// Converts to basic IconsLoadOutput (without cache info).
    public var asLoadOutput: IconsLoadOutput {
        IconsLoadOutput(light: light, dark: dark)
    }
}

/// Context protocol extension for granular cache support.
///
/// Plugins can optionally use this protocol when granular cache is enabled.
/// The default implementation falls back to regular loading.
public protocol IconsExportContextWithGranularCache: IconsExportContext {
    /// Whether granular cache is enabled.
    var isGranularCacheEnabled: Bool { get }

    /// Loads icons with granular cache support.
    ///
    /// When granular cache is enabled, filters components to only changed ones
    /// and returns computed hashes for cache updates.
    ///
    /// - Parameters:
    ///   - source: Icons source configuration.
    ///   - onProgress: Optional progress callback (current, total).
    /// - Returns: Icons with hash information for cache.
    func loadIconsWithGranularCache(
        from source: IconsSourceInput,
        onProgress: (@Sendable (Int, Int) -> Void)?
    ) async throws -> IconsLoadOutputWithHashes

    /// Processes icon names for template generation.
    ///
    /// Applies the same name transformations as processIcons() but only
    /// returns processed names. Used for generating templates with all icons
    /// when granular cache skips unchanged icons.
    ///
    /// - Parameters:
    ///   - names: Raw icon names from Figma.
    ///   - nameValidateRegexp: Optional regex for name validation.
    ///   - nameReplaceRegexp: Optional regex for name replacement.
    ///   - nameStyle: Naming style for generated code.
    /// - Returns: Processed icon names.
    func processIconNames(
        _ names: [String],
        nameValidateRegexp: String?,
        nameReplaceRegexp: String?,
        nameStyle: NameStyle
    ) -> [String]
}

// MARK: - Icons Export Result

/// Result of icons export operation.
///
/// Contains export statistics and granular cache information for batch mode.
public struct IconsExportResult: Sendable {
    /// Number of icons successfully exported.
    public let count: Int

    /// Number of dark mode variants generated.
    public let darkCount: Int

    /// Number of icons skipped due to granular cache (unchanged).
    public let skippedCount: Int

    /// Computed content hashes for cache update (fileId → (nodeId → hash)).
    public let computedHashes: [String: [String: String]]

    /// All asset metadata for template generation.
    public let allAssetMetadata: [AssetMetadata]

    public init(
        count: Int,
        darkCount: Int = 0,
        skippedCount: Int = 0,
        computedHashes: [String: [String: String]] = [:],
        allAssetMetadata: [AssetMetadata] = []
    ) {
        self.count = count
        self.darkCount = darkCount
        self.skippedCount = skippedCount
        self.computedHashes = computedHashes
        self.allAssetMetadata = allAssetMetadata
    }

    /// Creates a simple result with just count (no granular cache).
    public static func simple(count: Int, darkCount: Int = 0) -> IconsExportResult {
        IconsExportResult(count: count, darkCount: darkCount)
    }

    /// Merges multiple results into one.
    public static func merge(_ results: [IconsExportResult]) -> IconsExportResult {
        var totalCount = 0
        var totalDark = 0
        var totalSkipped = 0
        var allHashes: [String: [String: String]] = [:]
        var allMetadata: [AssetMetadata] = []

        for result in results {
            totalCount += result.count
            totalDark += result.darkCount
            totalSkipped += result.skippedCount

            // Merge hashes
            for (fileId, nodeHashes) in result.computedHashes {
                if allHashes[fileId] == nil {
                    allHashes[fileId] = nodeHashes
                } else {
                    allHashes[fileId]?.merge(nodeHashes) { _, new in new }
                }
            }

            allMetadata.append(contentsOf: result.allAssetMetadata)
        }

        return IconsExportResult(
            count: totalCount,
            darkCount: totalDark,
            skippedCount: totalSkipped,
            computedHashes: allHashes,
            allAssetMetadata: allMetadata
        )
    }
}
