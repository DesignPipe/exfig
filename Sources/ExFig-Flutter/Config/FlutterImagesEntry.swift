import ExFigConfig
import ExFigCore
import Foundation

/// Typealias for backward compatibility with consumers.
public typealias FlutterImagesEntry = Flutter.ImagesEntry

/// Typealias for generated Flutter ImageFormat.
public typealias FlutterImageFormat = Flutter.ImageFormat

// MARK: - Convenience Extensions

public extension Flutter.ImagesEntry {
    /// Returns an ImagesSourceInput for use with ImagesExportContext.
    func imagesSourceInput(darkFileId: String? = nil) -> ImagesSourceInput {
        ImagesSourceInput(
            sourceKind: sourceKind?.coreSourceKind ?? .figma,
            figmaFileId: figmaFileId,
            darkFileId: darkFileId,
            frameName: figmaFrameName ?? "Images",
            pageName: figmaPageName,
            sourceFormat: effectiveSourceFormat,
            scales: effectiveScales,
            useSingleFile: darkFileId == nil,
            darkModeSuffix: "_dark",
            rtlProperty: rtlProperty,
            nameValidateRegexp: nameValidateRegexp,
            nameReplaceRegexp: nameReplaceRegexp
        )
    }

    /// Effective source format, defaulting to PNG.
    var effectiveSourceFormat: ImageSourceFormat {
        guard let sourceFormat else { return .png }
        guard let core = ImageSourceFormat(rawValue: sourceFormat.rawValue) else {
            preconditionFailure(
                "Unsupported ImageSourceFormat '\(sourceFormat.rawValue)'. "
                    + "This may indicate a PKL schema version mismatch."
            )
        }
        return core
    }

    /// Returns an ImagesSourceInput configured for SVG source.
    func svgSourceInput(darkFileId: String? = nil) -> ImagesSourceInput {
        ImagesSourceInput(
            sourceKind: sourceKind?.coreSourceKind ?? .figma,
            figmaFileId: figmaFileId,
            darkFileId: darkFileId,
            frameName: figmaFrameName ?? "Images",
            pageName: figmaPageName,
            sourceFormat: .svg,
            scales: [1.0],
            useSingleFile: darkFileId == nil,
            darkModeSuffix: "_dark",
            rtlProperty: rtlProperty,
            nameValidateRegexp: nameValidateRegexp,
            nameReplaceRegexp: nameReplaceRegexp
        )
    }

    /// Effective name style, defaulting to snake_case.
    var effectiveNameStyle: NameStyle {
        guard let nameStyle else { return .snakeCase }
        return nameStyle.coreNameStyle
    }

    /// Effective scales for Flutter.
    var effectiveScales: [Double] {
        scales?.map { Double($0) } ?? [1.0, 2.0, 3.0]
    }

    /// Effective output format.
    var effectiveFormat: Flutter.ImageFormat {
        format ?? .png
    }

    /// Format string for the output (png, webp, svg).
    var formatString: String {
        effectiveFormat.rawValue
    }

    /// Converts entry's WebP options to protocol-level WebpConverterOptions.
    var webpConverterOptions: WebpConverterOptions? {
        guard let opts = webpOptions else { return nil }
        return WebpConverterOptions(lossless: opts.encoding == .lossless, quality: opts.quality)
    }

    // MARK: - Entry-Level Override Resolution

    /// Resolved templates path: entry override or platform config fallback.
    func resolvedTemplatesPath(fallback: URL?) -> URL? {
        templatesPath.map { URL(fileURLWithPath: $0) } ?? fallback
    }
}
