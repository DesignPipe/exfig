import ArgumentParser
import ExFigCore
import FigmaAPI
import Foundation

// MARK: - Download Typography

extension ExFigCommand.Download {
    /// Downloads typography/text styles from Figma as JSON.
    struct DownloadTypography: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "typography",
            abstract: "Downloads typography from Figma as JSON"
        )

        @OptionGroup
        var globalOptions: GlobalOptions

        @OptionGroup
        var options: ExFigOptions

        @OptionGroup
        var jsonOptions: JSONExportOptions

        @OptionGroup
        var faultToleranceOptions: FaultToleranceOptions

        func run() async throws {
            ExFigCommand.initializeTerminalUI(verbose: globalOptions.verbose, quiet: globalOptions.quiet)
            let ui = ExFigCommand.terminalUI!

            let baseClient = try FigmaClient(
                accessToken: options.requireFigmaToken(),
                timeout: options.params.figma?.timeout
            )
            let rateLimiter = faultToleranceOptions.createRateLimiter()
            let client = faultToleranceOptions.createRateLimitedClient(
                wrapping: baseClient,
                rateLimiter: rateLimiter,
                onRetry: { attempt, error in
                    ui.warning("Retry \(attempt) after error: \(error.localizedDescription)")
                }
            )

            ui.info("Downloading typography from Figma...")

            let outputPath = jsonOptions.output ?? "typography.json"
            let outputURL = URL(fileURLWithPath: outputPath)

            guard let figmaParams = options.params.figma else {
                throw ExFigError.custom(errorString: "figma section is required for typography download.")
            }

            let textStyles = try await ui.withSpinner("Fetching text styles...") {
                let loader = TextStylesLoader(client: client, params: figmaParams)
                return try await loader.load()
            }

            switch jsonOptions.format {
            case .w3c:
                try TypographyExportHelper.exportW3C(
                    textStyles: textStyles,
                    outputURL: outputURL,
                    compact: jsonOptions.compact,
                    w3cVersion: jsonOptions.w3cVersion
                )

            case .raw:
                guard let fileId = figmaParams.lightFileId else {
                    throw ExFigError.custom(errorString:
                        "figma.lightFileId is required for raw typography download."
                    )
                }
                try TypographyExportHelper.exportRaw(
                    textStyles: textStyles,
                    fileId: fileId,
                    outputURL: outputURL,
                    compact: jsonOptions.compact
                )
            }

            ui.success("Exported typography to \(outputPath)")
        }
    }
}

// MARK: - Raw Typography Data Structure

struct RawTextStyleEntry: Encodable {
    let name: String
    let fontName: String
    let fontSize: Double
    let fontStyle: String?
    let lineHeight: Double?
    let letterSpacing: Double
    let textCase: String

    init(from style: TextStyle) {
        name = style.name
        fontName = style.fontName
        fontSize = style.fontSize
        fontStyle = style.fontStyle?.rawValue
        lineHeight = style.lineHeight
        letterSpacing = style.letterSpacing
        textCase = style.textCase.rawValue
    }
}
