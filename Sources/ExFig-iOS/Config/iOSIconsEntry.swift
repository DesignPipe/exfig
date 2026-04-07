// swiftlint:disable type_name

import ExFigConfig
import ExFigCore
import Foundation

/// Typealias for backward compatibility with consumers.
public typealias iOSIconsEntry = iOS.IconsEntry

// MARK: - Convenience Extensions

public extension iOS.IconsEntry {
    /// Returns an IconsSourceInput for use with IconsExportContext.
    func iconsSourceInput(darkFileId: String? = nil) -> IconsSourceInput {
        IconsSourceInput(
            sourceKind: resolvedSourceKind,
            figmaFileId: resolvedFileId,
            darkFileId: darkFileId,
            frameName: figmaFrameName ?? "Icons",
            pageName: figmaPageName,
            format: coreVectorFormat,
            useSingleFile: darkFileId == nil && variablesDarkMode == nil,
            darkModeSuffix: "_dark",
            renderMode: coreRenderMode,
            renderModeDefaultSuffix: renderModeDefaultSuffix,
            renderModeOriginalSuffix: renderModeOriginalSuffix,
            renderModeTemplateSuffix: renderModeTemplateSuffix,
            rtlProperty: rtlProperty,
            rtlActiveValues: rtlActiveValues,
            nameValidateRegexp: nameValidateRegexp,
            nameReplaceRegexp: nameReplaceRegexp,
            penpotBaseURL: resolvedPenpotBaseURL,
            variablesCollectionName: variablesDarkMode?.collectionName,
            variablesLightModeName: variablesDarkMode?.lightModeName,
            variablesDarkModeName: variablesDarkMode?.darkModeName,
            variablesPrimitivesModeName: variablesDarkMode?.primitivesModeName,
            variablesFileId: variablesDarkMode?.variablesFileId
        )
    }

    /// Converts PKL VectorFormat to ExFigCore VectorFormat.
    var coreVectorFormat: VectorFormat {
        guard let fmt = VectorFormat(rawValue: format.rawValue) else {
            preconditionFailure(
                "Unsupported VectorFormat '\(format.rawValue)'. "
                    + "This may indicate a PKL schema version mismatch."
            )
        }
        return fmt
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
