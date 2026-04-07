import ExFigConfig
import ExFigCore
import Foundation

/// Typealias for backward compatibility with consumers.
public typealias AndroidIconsEntry = Android.IconsEntry

/// Typealias for generated ComposeIconFormat.
public typealias ComposeIconFormat = Android.ComposeIconFormat

// MARK: - Convenience Extensions

public extension Android.IconsEntry {
    /// Returns an IconsSourceInput for use with IconsExportContext.
    func iconsSourceInput(darkFileId: String? = nil) -> IconsSourceInput {
        IconsSourceInput(
            sourceKind: resolvedSourceKind,
            figmaFileId: resolvedFileId,
            darkFileId: darkFileId,
            frameName: figmaFrameName ?? "Icons",
            pageName: figmaPageName,
            format: .svg,
            useSingleFile: darkFileId == nil && variablesDarkMode == nil,
            darkModeSuffix: "_dark",
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

    /// Effective name style, defaulting to snake_case.
    var effectiveNameStyle: NameStyle {
        guard let nameStyle else { return .snakeCase }
        return nameStyle.coreNameStyle
    }

    /// Effective package name for Code Connect: prefers `codeConnectPackageName`, falls back to `composePackageName`.
    var effectiveCodeConnectPackageName: String? {
        codeConnectPackageName ?? composePackageName
    }

    /// URL for Code Connect Kotlin file output.
    var codeConnectKotlinURL: URL? {
        codeConnectKotlin.map { URL(fileURLWithPath: $0) }
    }

    /// Effective compose format, defaulting to resourceReference.
    var effectiveComposeFormat: Android.ComposeIconFormat {
        composeFormat ?? .resourceReference
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
