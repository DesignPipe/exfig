import ExFigConfig
import ExFigCore
import Foundation

/// Typealias for backward compatibility with consumers.
public typealias AndroidImagesEntry = Android.ImagesEntry

/// Typealias for generated Android ImageFormat.
public typealias AndroidImageFormat = Android.ImageFormat

/// Typealias for generated WebpOptions.
public typealias WebpOptions = Common.WebpOptions

// MARK: - WebpOptions Convenience

public extension Common.WebpOptions {
    /// Whether to use lossless encoding.
    var lossless: Bool {
        encoding == .lossless
    }

    /// Converts to protocol-level WebpConverterOptions.
    var converterOptions: WebpConverterOptions {
        WebpConverterOptions(lossless: lossless, quality: quality)
    }
}

// MARK: - Convenience Extensions

public extension Android.ImagesEntry {
    /// Returns an ImagesSourceInput for use with ImagesExportContext.
    func imagesSourceInput(darkFileId: String? = nil) -> ImagesSourceInput {
        ImagesSourceInput(
            sourceKind: resolvedSourceKind,
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

    /// URL for Code Connect Kotlin file output.
    var codeConnectKotlinURL: URL? {
        codeConnectKotlin.map { URL(fileURLWithPath: $0) }
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

    /// Effective scales for Android.
    var effectiveScales: [Double] {
        scales?.map { Double($0) } ?? [1.0, 1.5, 2.0, 3.0, 4.0]
    }

    /// Converts entry's WebP options to protocol-level WebpConverterOptions.
    var webpConverterOptions: WebpConverterOptions? {
        webpOptions?.converterOptions
    }

    /// Effective name style, defaulting to snake_case.
    var effectiveNameStyle: NameStyle {
        guard let nameStyle else { return .snakeCase }
        return nameStyle.coreNameStyle
    }

    /// Converts generated ImageFormat to ExFigCore ImageOutputFormat.
    ///
    /// - Note: Android images don't support SVG as output format.
    ///   When SVG is specified, falls back to PNG. A warning is logged at the export call site
    ///   in `AndroidImagesExport` when this fallback is triggered.
    var coreOutputFormat: ImageOutputFormat {
        switch format {
        case .png: .png
        case .webp: .webp
        case .svg: .png
        }
    }

    /// Whether the format is SVG (which falls back to PNG for images).
    var isSvgFallback: Bool {
        format == .svg
    }

    // MARK: - Entry-Level Override Resolution

    /// Resolved mainRes path: entry override or platform config fallback.
    func resolvedMainRes(fallback: URL) -> URL {
        mainRes.map { URL(fileURLWithPath: $0) } ?? fallback
    }

    /// Resolved templates path: entry override or platform config fallback.
    func resolvedTemplatesPath(fallback: URL?) -> URL? {
        templatesPath.map { URL(fileURLWithPath: $0) } ?? fallback
    }
}
