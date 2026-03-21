import ExFigConfig
import ExFigCore
import Foundation

/// Typealias for backward compatibility with consumers.
public typealias WebImagesEntry = Web.ImagesEntry

// MARK: - Convenience Extensions

public extension Web.ImagesEntry {
    /// Returns an ImagesSourceInput for use with ImagesExportContext.
    func imagesSourceInput(darkFileId: String? = nil) -> ImagesSourceInput {
        ImagesSourceInput(
            sourceKind: resolvedSourceKind,
            figmaFileId: resolvedFileId,
            darkFileId: darkFileId,
            frameName: figmaFrameName ?? "Images",
            pageName: figmaPageName,
            sourceFormat: .svg,
            scales: [1.0],
            useSingleFile: darkFileId == nil,
            darkModeSuffix: "_dark",
            rtlProperty: rtlProperty,
            nameValidateRegexp: nameValidateRegexp,
            nameReplaceRegexp: nameReplaceRegexp,
            penpotBaseURL: resolvedPenpotBaseURL
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

    // MARK: - Entry-Level Override Resolution

    /// Resolved templates path: entry override or platform config fallback.
    func resolvedTemplatesPath(fallback: URL?) -> URL? {
        templatesPath.map { URL(fileURLWithPath: $0) } ?? fallback
    }
}
