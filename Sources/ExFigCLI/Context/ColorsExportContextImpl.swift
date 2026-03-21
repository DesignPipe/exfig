import ExFigCore
import FigmaAPI
import Foundation

/// Concrete implementation of `ColorsExportContext` for the ExFig CLI.
///
/// Bridges between the plugin system and ExFig's internal services:
/// - Uses injected `ColorsSource` for design data loading
/// - Uses `ColorsProcessor` for platform-specific processing
/// - Uses `ExFigCommand.fileWriter` for file output
/// - Uses `TerminalUI` for progress and logging
struct ColorsExportContextImpl: ColorsExportContext {
    let client: Client
    let colorsSource: any ColorsSource
    let ui: TerminalUI
    let filter: String?
    let isBatchMode: Bool

    init(
        client: Client,
        colorsSource: any ColorsSource,
        ui: TerminalUI,
        filter: String? = nil,
        isBatchMode: Bool = false
    ) {
        self.client = client
        self.colorsSource = colorsSource
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

    // MARK: - ColorsExportContext

    func loadColors(from source: ColorsSourceInput) async throws -> ColorsLoadOutput {
        try await colorsSource.loadColors(from: source)
    }

    func processColors(
        _ colors: ColorsLoadOutput,
        platform: Platform,
        nameValidateRegexp: String?,
        nameReplaceRegexp: String?,
        nameStyle: NameStyle
    ) throws -> ColorsProcessResult {
        let processor = ColorsProcessor(
            platform: platform,
            nameValidateRegexp: nameValidateRegexp,
            nameReplaceRegexp: nameReplaceRegexp,
            nameStyle: nameStyle
        )

        let result = processor.process(
            light: colors.light,
            dark: colors.dark.isEmpty ? nil : colors.dark,
            lightHC: colors.lightHC.isEmpty ? nil : colors.lightHC,
            darkHC: colors.darkHC.isEmpty ? nil : colors.darkHC
        )

        return try ColorsProcessResult(
            colorPairs: result.get(),
            warning: result.warning.map { WarningFormatter().format($0, compact: isBatchMode) }
        )
    }
}
