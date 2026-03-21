import ExFigConfig
import ExFigCore
import Foundation

/// Typealias for backward compatibility with consumers.
public typealias FlutterIconsEntry = Flutter.IconsEntry

// MARK: - Convenience Extensions

public extension Flutter.IconsEntry {
    /// Returns an IconsSourceInput for use with IconsExportContext.
    func iconsSourceInput(darkFileId: String? = nil) -> IconsSourceInput {
        IconsSourceInput(
            sourceKind: resolvedSourceKind,
            figmaFileId: figmaFileId,
            darkFileId: darkFileId,
            frameName: figmaFrameName ?? "Icons",
            pageName: figmaPageName,
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

    // MARK: - Entry-Level Override Resolution

    /// Resolved templates path: entry override or platform config fallback.
    func resolvedTemplatesPath(fallback: URL?) -> URL? {
        templatesPath.map { URL(fileURLWithPath: $0) } ?? fallback
    }
}
