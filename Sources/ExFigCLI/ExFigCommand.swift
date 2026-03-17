import ArgumentParser
import Foundation
import Logging
import SVGKit

enum ExFigError: LocalizedError {
    case invalidFileName(String)
    case stylesNotFound
    case componentsNotFound(frameName: String?, pageName: String?)
    case accessTokenNotFound
    case colorsAssetsFolderNotSpecified
    case configurationError(String)
    case custom(errorString: String)

    var errorDescription: String? {
        switch self {
        case let .invalidFileName(name):
            "Invalid file name: \(name)"
        case .stylesNotFound:
            "Styles not found in Figma file"
        case let .componentsNotFound(frameName, pageName):
            if let frameName, let pageName {
                "No components found in frame '\(frameName)' on page '\(pageName)'"
            } else if let frameName {
                "No components found in frame '\(frameName)'"
            } else {
                "Components not found in Figma file"
            }
        case .accessTokenNotFound:
            "FIGMA_PERSONAL_TOKEN not set"
        case .colorsAssetsFolderNotSpecified:
            "Config missing: ios.colors.assetsFolder"
        case let .configurationError(message):
            "Config error: \(message)"
        case let .custom(errorString):
            errorString
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidFileName:
            "Use alphanumeric characters, underscores, and hyphens only"
        case .stylesNotFound:
            "Publish Styles to the Team Library in Figma"
        case let .componentsNotFound(_, pageName):
            if pageName != nil {
                "Check that figmaPageName matches exactly (case-sensitive). "
                    + "Publish Components to the Team Library in Figma."
            } else {
                "Publish Components to the Team Library in Figma"
            }
        case .accessTokenNotFound:
            "Run: export FIGMA_PERSONAL_TOKEN=your_token"
        case .colorsAssetsFolderNotSpecified:
            "Add ios.colors.assetsFolder to your config file"
        case .configurationError, .custom:
            nil
        }
    }
}

@main
struct ExFigCommand: AsyncParsableCommand {
    static let version = "v2.8.1"

    static let svgFileConverter = NativeVectorDrawableConverter()
    static let fileWriter = FileWriter()
    static let logger = Logger(label: "com.designpipe.exfig")

    /// Shared terminal UI instance (initialized by subcommands)
    nonisolated(unsafe) static var terminalUI: TerminalUI!

    static let configuration = CommandConfiguration(
        commandName: "exfig",
        abstract: "Exports resources from Figma",
        discussion: """
        Version: \(version)

        Exports resources (colors, icons, images) from Figma to Xcode / Android Studio / Flutter project.

        Requires FIGMA_PERSONAL_TOKEN environment variable to be set.
        """,
        version: version,
        subcommands: [
            ExportColors.self,
            ExportIcons.self,
            ExportImages.self,
            ExportTypography.self,
            GenerateConfigFile.self,
            ExtractSchemas.self,
            FetchImages.self,
            Download.self,
            Tokens.self,
            Batch.self,
            MCPServe.self,
        ],
        defaultSubcommand: ExportColors.self
    )
}

// MARK: - TerminalUI Initialization

extension ExFigCommand {
    /// Initialize TerminalUI with global options
    static func initializeTerminalUI(verbose: Bool, quiet: Bool) {
        let outputMode = TTYDetector.effectiveMode(verbose: verbose, quiet: quiet)

        // Bootstrap logging system to use our custom handler
        // This ensures all Logger output goes through TerminalOutputManager
        ExFigLogging.bootstrap(outputMode: outputMode)

        terminalUI = TerminalUI(outputMode: outputMode)
        terminalUI.installSignalHandlers()
    }

    /// Checks if extracted schemas match the current CLI version and warns if not.
    static func checkSchemaVersionIfNeeded() {
        guard let ui = terminalUI else { return }

        switch SchemaExtractor.checkVersion() {
        case .matched, .noSchemasDirectory:
            break
        case let .mismatch(schemasVersion, cliVersion):
            ui.warning(
                "Extracted schemas (\(schemasVersion)) don't match ExFig version (\(cliVersion)). "
                    + "Run `exfig schemas --force` to update."
            )
        case .noVersionFile:
            // Schemas exist but no version file — extracted by an older version
            ui.warning(
                "Local schemas in .exfig/schemas/ have no version info. "
                    + "Run `exfig schemas --force` to update, or remove the directory if using package:// imports."
            )
        }
    }
}
