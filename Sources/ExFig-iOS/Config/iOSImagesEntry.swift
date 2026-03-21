// swiftlint:disable type_name

import ExFigConfig
import ExFigCore
import Foundation

/// Typealias for backward compatibility with consumers.
public typealias iOSImagesEntry = iOS.ImagesEntry

// MARK: - Convenience Extensions

public extension iOS.ImagesEntry {
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

    /// Effective output format, defaulting to PNG.
    var effectiveOutputFormat: ImageOutputFormat {
        guard let outputFormat else { return .png }
        guard let core = ImageOutputFormat(rawValue: outputFormat.rawValue) else {
            preconditionFailure(
                "Unsupported ImageOutputFormat '\(outputFormat.rawValue)'. "
                    + "This may indicate a PKL schema version mismatch."
            )
        }
        return core
    }

    /// Effective scales, defaulting to iOS standard [1.0, 2.0, 3.0].
    var effectiveScales: [Double] {
        scales?.map { Double($0) } ?? [1.0, 2.0, 3.0]
    }

    /// Converts PKL NameStyle to ExFigCore NameStyle.
    var coreNameStyle: NameStyle {
        nameStyle.coreNameStyle
    }

    /// Path to generate UIImage extension as URL.
    var imageSwiftURL: URL? {
        imageSwift.map { URL(fileURLWithPath: $0) }
    }

    /// Path to generate SwiftUI Image extension as URL.
    var swiftUIImageSwiftURL: URL? {
        swiftUIImageSwift.map { URL(fileURLWithPath: $0) }
    }

    /// Path to generate Figma Code Connect Swift file as URL.
    var codeConnectSwiftURL: URL? {
        codeConnectSwift.map { URL(fileURLWithPath: $0) }
    }

    /// Converts PKL XcodeRenderMode to ExFigCore XcodeRenderMode.
    var coreRenderMode: XcodeRenderMode? {
        guard let renderMode else { return nil }
        guard let mode = XcodeRenderMode(rawValue: renderMode.rawValue) else {
            preconditionFailure(
                "Unsupported XcodeRenderMode '\(renderMode.rawValue)'. "
                    + "This may indicate a PKL schema version mismatch."
            )
        }
        return mode
    }

    /// Converts entry's HEIC options to protocol-level HeicConverterOptions.
    var heicConverterOptions: HeicConverterOptions? {
        guard let opts = heicOptions else { return nil }
        let encoding: HeicConverterOptions.Encoding? = opts.encoding.map { enc in
            guard let core = HeicConverterOptions.Encoding(rawValue: enc.rawValue) else {
                preconditionFailure(
                    "Unsupported HeicEncoding '\(enc.rawValue)'. "
                        + "This may indicate a PKL schema version mismatch."
                )
            }
            return core
        }
        return HeicConverterOptions(encoding: encoding, quality: opts.quality)
    }

    // MARK: - Entry-Level Override Resolution

    /// Resolved xcassets path: entry override or platform config fallback.
    func resolvedXcassetsPath(fallback: URL?) -> URL? {
        xcassetsPath.map { URL(fileURLWithPath: $0) } ?? fallback
    }

    /// Resolved templates path: entry override or platform config fallback.
    func resolvedTemplatesPath(fallback: URL?) -> URL? {
        templatesPath.map { URL(fileURLWithPath: $0) } ?? fallback
    }
}

// swiftlint:enable type_name
