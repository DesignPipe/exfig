import Foundation

// MARK: - Typography Export Context

/// Context for typography export operations.
///
/// Extends `ExportContext` with typography-specific functionality
/// like loading and processing text styles.
public protocol TypographyExportContext: ExportContext {
    /// Loads text styles from Figma.
    ///
    /// - Parameters:
    ///   - source: Text styles source configuration.
    /// - Returns: Loaded text styles output.
    func loadTypography(
        from source: TypographySourceInput
    ) async throws -> TypographyLoadOutput

    /// Processes text styles into platform-specific format.
    ///
    /// - Parameters:
    ///   - textStyles: Raw text styles from Figma.
    ///   - platform: Target platform.
    ///   - nameValidateRegexp: Regex pattern for validating/filtering names.
    ///   - nameReplaceRegexp: Replacement pattern using captured groups.
    ///   - nameStyle: Naming style for generated code.
    /// - Returns: Processed text styles.
    func processTypography(
        _ textStyles: TypographyLoadOutput,
        platform: Platform,
        nameValidateRegexp: String?,
        nameReplaceRegexp: String?,
        nameStyle: NameStyle
    ) throws -> TypographyProcessResult
}

/// Input for loading typography from Figma.
public struct TypographySourceInput: Sendable {
    /// Design source kind (default: `.figma`).
    public let sourceKind: DesignSourceKind

    /// Figma file ID containing text styles.
    public let fileId: String

    /// Optional timeout for Figma API requests.
    public let timeout: TimeInterval?

    public init(
        sourceKind: DesignSourceKind = .figma,
        fileId: String,
        timeout: TimeInterval? = nil
    ) {
        self.sourceKind = sourceKind
        self.fileId = fileId
        self.timeout = timeout
    }
}

/// Output from typography loading.
public struct TypographyLoadOutput: Sendable {
    /// Loaded text styles from Figma.
    public let textStyles: [TextStyle]

    public init(textStyles: [TextStyle]) {
        self.textStyles = textStyles
    }
}

/// Result from typography processing.
public struct TypographyProcessResult: Sendable {
    /// Processed text styles ready for export.
    public let textStyles: [TextStyle]

    /// Optional warning message (e.g., filtered names).
    public let warning: String?

    public init(textStyles: [TextStyle], warning: String? = nil) {
        self.textStyles = textStyles
        self.warning = warning
    }
}
