import ExFigCore
import FigmaAPI
import Foundation

/// Concrete implementation of `TypographyExportContext` for the ExFig CLI.
///
/// Bridges between the plugin system and ExFig's internal services:
/// - Uses `TextStylesLoader` for Figma data loading
/// - Uses `TypographyProcessor` for platform-specific processing
/// - Uses `ExFigCommand.fileWriter` for file output
/// - Uses `TerminalUI` for progress and logging
struct TypographyExportContextImpl: TypographyExportContext {
    let client: Client
    let typographySource: any TypographySource
    let ui: TerminalUI
    let filter: String?
    let isBatchMode: Bool

    init(
        client: Client,
        typographySource: any TypographySource,
        ui: TerminalUI,
        filter: String? = nil,
        isBatchMode: Bool = false
    ) {
        self.client = client
        self.typographySource = typographySource
        self.ui = ui
        self.filter = filter
        self.isBatchMode = isBatchMode
    }

    // MARK: - ExportContext

    func writeFiles(_ files: [FileContents]) throws {
        try ExFigCommand.fileWriter.write(files: files)
    }

    func info(_ message: String) {
        ui.info(message)
    }

    func warning(_ message: String) {
        ui.warning(message)
    }

    func success(_ message: String) {
        ui.success(message)
    }

    func withSpinner<T: Sendable>(
        _ message: String,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await ui.withSpinner(message, operation: operation)
    }

    // MARK: - TypographyExportContext

    func loadTypography(from source: TypographySourceInput) async throws -> TypographyLoadOutput {
        try await typographySource.loadTypography(from: source)
    }

    func processTypography(
        _ textStyles: TypographyLoadOutput,
        platform: Platform,
        nameValidateRegexp: String?,
        nameReplaceRegexp: String?,
        nameStyle: NameStyle
    ) throws -> TypographyProcessResult {
        let processor = TypographyProcessor(
            platform: platform,
            nameValidateRegexp: nameValidateRegexp,
            nameReplaceRegexp: nameReplaceRegexp,
            nameStyle: nameStyle
        )

        let result = processor.process(assets: textStyles.textStyles)

        return try TypographyProcessResult(
            textStyles: result.get(),
            warning: result.warning.map { WarningFormatter().format($0, compact: isBatchMode) }
        )
    }
}
