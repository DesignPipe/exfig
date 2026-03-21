// swiftlint:disable file_length
import Foundation

// MARK: - Images Export Context

/// Context for images export operations.
///
/// Extends `ExportContext` with images-specific functionality
/// like loading images from Figma frames and format conversion.
public protocol ImagesExportContext: ExportContext {
    /// Loads images from a Figma frame.
    ///
    /// - Parameter source: Images source configuration.
    /// - Returns: Loaded images output (light, dark variants).
    func loadImages(from source: ImagesSourceInput) async throws -> ImagesLoadOutput

    /// Processes images into platform-specific format.
    ///
    /// - Parameters:
    ///   - images: Raw images from Figma.
    ///   - platform: Target platform.
    ///   - nameValidateRegexp: Optional regex for name validation.
    ///   - nameReplaceRegexp: Optional regex for name replacement.
    ///   - nameStyle: Naming style for generated code.
    /// - Returns: Processed image pairs.
    func processImages(
        _ images: ImagesLoadOutput,
        platform: Platform,
        nameValidateRegexp: String?,
        nameReplaceRegexp: String?,
        nameStyle: NameStyle
    ) throws -> ImagesProcessResult

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

    /// Converts images to a different format (e.g., PNG to HEIC).
    ///
    /// - Parameters:
    ///   - files: Files to convert (must be already downloaded).
    ///   - outputFormat: Target format.
    ///   - heicOptions: Optional HEIC encoding options (used when outputFormat is .heic).
    ///   - webpOptions: Optional WebP encoding options (used when outputFormat is .webp).
    ///   - progressTitle: Title for progress bar.
    /// - Returns: Converted files.
    func convertFormat(
        _ files: [FileContents],
        to outputFormat: ImageOutputFormat,
        heicOptions: HeicConverterOptions?,
        webpOptions: WebpConverterOptions?,
        progressTitle: String
    ) async throws -> [FileContents]

    // swiftlint:disable function_parameter_count

    /// Rasterizes SVG files to raster format at specified scales.
    ///
    /// - Parameters:
    ///   - files: SVG files to rasterize.
    ///   - scales: Scale factors (e.g., [1.0, 2.0, 3.0] for iOS).
    ///   - outputFormat: Target raster format (png, heic, or webp).
    ///   - heicOptions: Optional HEIC encoding options (used when outputFormat is .heic).
    ///   - webpOptions: Optional WebP encoding options (used when outputFormat is .webp).
    ///   - progressTitle: Title for progress bar.
    /// - Returns: Rasterized files at all scales.
    func rasterizeSVGs(
        _ files: [FileContents],
        scales: [Double],
        to outputFormat: ImageOutputFormat,
        heicOptions: HeicConverterOptions?,
        webpOptions: WebpConverterOptions?,
        progressTitle: String
    ) async throws -> [FileContents]

    // swiftlint:enable function_parameter_count

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

// MARK: - Default Parameters

public extension ImagesExportContext {
    /// Convenience overload with nil options for backward compatibility.
    func convertFormat(
        _ files: [FileContents],
        to outputFormat: ImageOutputFormat,
        progressTitle: String
    ) async throws -> [FileContents] {
        try await convertFormat(
            files, to: outputFormat,
            heicOptions: nil, webpOptions: nil,
            progressTitle: progressTitle
        )
    }

    /// Convenience overload with nil options for backward compatibility.
    func rasterizeSVGs(
        _ files: [FileContents],
        scales: [Double],
        to outputFormat: ImageOutputFormat,
        progressTitle: String
    ) async throws -> [FileContents] {
        try await rasterizeSVGs(
            files, scales: scales, to: outputFormat,
            heicOptions: nil, webpOptions: nil,
            progressTitle: progressTitle
        )
    }

    /// Convenience overload with only HEIC options for backward compatibility.
    func rasterizeSVGs(
        _ files: [FileContents],
        scales: [Double],
        to outputFormat: ImageOutputFormat,
        heicOptions: HeicConverterOptions?,
        progressTitle: String
    ) async throws -> [FileContents] {
        try await rasterizeSVGs(
            files, scales: scales, to: outputFormat,
            heicOptions: heicOptions, webpOptions: nil,
            progressTitle: progressTitle
        )
    }

    /// Convenience overload with only WebP options.
    func rasterizeSVGs(
        _ files: [FileContents],
        scales: [Double],
        to outputFormat: ImageOutputFormat,
        webpOptions: WebpConverterOptions?,
        progressTitle: String
    ) async throws -> [FileContents] {
        try await rasterizeSVGs(
            files, scales: scales, to: outputFormat,
            heicOptions: nil, webpOptions: webpOptions,
            progressTitle: progressTitle
        )
    }
}

/// Input for loading images from Figma.
public struct ImagesSourceInput: Sendable {
    /// Design source kind (default: `.figma`).
    public let sourceKind: DesignSourceKind

    /// Optional entry-level Figma file ID override.
    public let figmaFileId: String?

    /// Optional dark mode file ID (if separate files for light/dark).
    public let darkFileId: String?

    /// The frame name containing images.
    public let frameName: String

    /// Optional page name to filter images by.
    public let pageName: String?

    /// Source format for images (png or svg).
    public let sourceFormat: ImageSourceFormat

    /// Scales to request from Figma (for raster images).
    public let scales: [Double]

    /// Whether to use single file with dark mode suffix.
    public let useSingleFile: Bool

    /// Suffix for dark mode images when using single file.
    public let darkModeSuffix: String

    /// Figma component property name for RTL variant detection.
    /// Default: `"RTL"`. Set to `nil` to disable variant-based RTL detection.
    public let rtlProperty: String?

    /// Name validation regex.
    public let nameValidateRegexp: String?

    /// Name replacement regex.
    public let nameReplaceRegexp: String?

    /// Penpot instance base URL (used when sourceKind == .penpot).
    public let penpotBaseURL: String?

    public init(
        sourceKind: DesignSourceKind = .figma,
        figmaFileId: String? = nil,
        darkFileId: String? = nil,
        frameName: String,
        pageName: String? = nil,
        sourceFormat: ImageSourceFormat = .png,
        scales: [Double] = [1.0, 2.0, 3.0],
        useSingleFile: Bool = false,
        darkModeSuffix: String = "_dark",
        rtlProperty: String? = "RTL",
        nameValidateRegexp: String? = nil,
        nameReplaceRegexp: String? = nil,
        penpotBaseURL: String? = nil
    ) {
        self.sourceKind = sourceKind
        self.figmaFileId = figmaFileId
        self.darkFileId = darkFileId
        self.frameName = frameName
        self.pageName = pageName
        self.sourceFormat = sourceFormat
        self.scales = scales
        self.useSingleFile = useSingleFile
        self.darkModeSuffix = darkModeSuffix
        self.rtlProperty = rtlProperty
        self.nameValidateRegexp = nameValidateRegexp
        self.nameReplaceRegexp = nameReplaceRegexp
        self.penpotBaseURL = penpotBaseURL
    }
}

/// Source format for images from Figma.
public enum ImageSourceFormat: String, Sendable, Decodable {
    case png
    case svg
}

/// Output format for images.
public enum ImageOutputFormat: String, Sendable, Decodable {
    case png
    case heic
    case webp
}

/// Output from images loading.
public struct ImagesLoadOutput: Sendable {
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

/// Result from images processing.
public struct ImagesProcessResult: Sendable {
    public let imagePairs: [AssetPair<ImagePack>]
    public let warning: String?

    public init(imagePairs: [AssetPair<ImagePack>], warning: String? = nil) {
        self.imagePairs = imagePairs
        self.warning = warning
    }
}

// MARK: - Granular Cache Support

/// Extended images load output with granular cache hashes.
///
/// Used when granular cache is enabled to return both images and
/// computed hashes for cache updates.
public struct ImagesLoadOutputWithHashes: Sendable {
    /// Loaded light mode images.
    public let light: [ImagePack]

    /// Loaded dark mode images (if available).
    public let dark: [ImagePack]

    /// Computed content hashes for cache update (fileId → (nodeId → hash)).
    public let computedHashes: [String: [String: String]]

    /// Whether all images were skipped (unchanged from cache).
    public let allSkipped: Bool

    /// All asset metadata (for template generation even when images skipped).
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

    /// Converts to basic ImagesLoadOutput (without cache info).
    public var asLoadOutput: ImagesLoadOutput {
        ImagesLoadOutput(light: light, dark: dark)
    }
}

/// Context protocol extension for granular cache support.
///
/// Plugins can optionally use this protocol when granular cache is enabled.
/// The default implementation falls back to regular loading.
public protocol ImagesExportContextWithGranularCache: ImagesExportContext {
    /// Whether granular cache is enabled.
    var isGranularCacheEnabled: Bool { get }

    /// Loads images with granular cache support.
    ///
    /// When granular cache is enabled, filters components to only changed ones
    /// and returns computed hashes for cache updates.
    ///
    /// - Parameters:
    ///   - source: Images source configuration.
    ///   - onProgress: Optional progress callback (current, total).
    /// - Returns: Images with hash information for cache.
    func loadImagesWithGranularCache(
        from source: ImagesSourceInput,
        onProgress: (@Sendable (Int, Int) -> Void)?
    ) async throws -> ImagesLoadOutputWithHashes

    /// Processes image names for template generation.
    ///
    /// Applies the same name transformations as processImages() but only
    /// returns processed names. Used for generating templates with all images
    /// when granular cache skips unchanged images.
    ///
    /// - Parameters:
    ///   - names: Raw image names from Figma.
    ///   - nameValidateRegexp: Optional regex for name validation.
    ///   - nameReplaceRegexp: Optional regex for name replacement.
    ///   - nameStyle: Naming style for generated code.
    /// - Returns: Processed image names.
    func processImageNames(
        _ names: [String],
        nameValidateRegexp: String?,
        nameReplaceRegexp: String?,
        nameStyle: NameStyle
    ) -> [String]
}

// MARK: - Images Export Result

/// Result of images export operation.
///
/// Contains export statistics and granular cache information
/// for batch mode and cache updates.
public struct ImagesExportResult: Sendable {
    /// Number of images successfully exported.
    public let count: Int

    /// Number of images skipped due to granular cache (unchanged).
    public let skippedCount: Int

    /// Computed content hashes for cache update (fileId → (nodeId → hash)).
    public let computedHashes: [String: [String: String]]

    /// All asset metadata for template generation.
    public let allAssetMetadata: [AssetMetadata]

    public init(
        count: Int,
        skippedCount: Int = 0,
        computedHashes: [String: [String: String]] = [:],
        allAssetMetadata: [AssetMetadata] = []
    ) {
        self.count = count
        self.skippedCount = skippedCount
        self.computedHashes = computedHashes
        self.allAssetMetadata = allAssetMetadata
    }

    /// Creates a simple result with just count (no granular cache).
    public static func simple(count: Int) -> ImagesExportResult {
        ImagesExportResult(count: count)
    }

    /// Merges multiple results into one.
    public static func merge(_ results: [ImagesExportResult]) -> ImagesExportResult {
        var totalCount = 0
        var totalSkipped = 0
        var allHashes: [String: [String: String]] = [:]
        var allMetadata: [AssetMetadata] = []

        for result in results {
            totalCount += result.count
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

        return ImagesExportResult(
            count: totalCount,
            skippedCount: totalSkipped,
            computedHashes: allHashes,
            allAssetMetadata: allMetadata
        )
    }
}
