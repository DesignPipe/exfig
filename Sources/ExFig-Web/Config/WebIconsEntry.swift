import ExFigConfig
import ExFigCore
import Foundation

/// Typealias for backward compatibility with consumers.
public typealias WebIconsEntry = Web.IconsEntry

// MARK: - Convenience Extensions

public extension Web.IconsEntry {
    /// Returns an IconsSourceInput for use with IconsExportContext.
    func iconsSourceInput(darkFileId: String? = nil) -> IconsSourceInput {
        IconsSourceInput(
            sourceKind: resolvedSourceKind,
            figmaFileId: resolvedFileId,
            darkFileId: darkFileId,
            frameName: figmaFrameName ?? "Icons",
            pageName: figmaPageName,
            useSingleFile: darkFileId == nil && variablesDarkMode == nil,
            darkModeSuffix: "_dark",
            rtlProperty: rtlProperty,
            nameValidateRegexp: nameValidateRegexp,
            nameReplaceRegexp: nameReplaceRegexp,
            penpotBaseURL: resolvedPenpotBaseURL,
            variablesCollectionName: variablesDarkMode?.collectionName,
            variablesLightModeName: variablesDarkMode?.lightModeName,
            variablesDarkModeName: variablesDarkMode?.darkModeName,
            variablesPrimitivesModeName: variablesDarkMode?.primitivesModeName
        )
    }

    /// Effective name style, defaulting to snake_case.
    var effectiveNameStyle: NameStyle {
        guard let nameStyle else { return .snakeCase }
        return nameStyle.coreNameStyle
    }

    /// Whether to generate React components, defaulting to true.
    var effectiveGenerateReactComponents: Bool {
        generateReactComponents ?? true
    }

    /// Effective icon size, defaulting to 24.
    var effectiveIconSize: Int {
        iconSize ?? 24
    }

    // MARK: - Entry-Level Override Resolution

    /// Resolved templates path: entry override or platform config fallback.
    func resolvedTemplatesPath(fallback: URL?) -> URL? {
        templatesPath.map { URL(fileURLWithPath: $0) } ?? fallback
    }
}
