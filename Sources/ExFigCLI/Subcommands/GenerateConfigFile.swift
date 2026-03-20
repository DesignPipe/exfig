import ArgumentParser
import ExFigCore
import Foundation

extension Platform: ExpressibleByArgument {}

extension ExFigCommand {
    struct GenerateConfigFile: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "init",
            abstract: "Generates config file",
            discussion: """
            Generates exfig.pkl config file in the current directory.

            When --platform is omitted in an interactive terminal, a guided wizard
            configures file IDs and asset types interactively.

            Examples:
              exfig init              Interactive wizard (TTY only)
              exfig init -p ios       Generate iOS config template
              exfig init -p android   Generate Android config template
            """
        )

        @OptionGroup
        var globalOptions: GlobalOptions

        @Option(
            name: .shortAndLong,
            help: "Platform: ios, android, flutter, or web. Prompted interactively if omitted in TTY."
        )
        var platform: Platform?

        func run() async throws {
            ExFigCommand.initializeTerminalUI(verbose: globalOptions.verbose, quiet: globalOptions.quiet)
            let ui = ExFigCommand.terminalUI!

            let destination = FileManager.default.currentDirectoryPath + "/" + ExFigOptions.defaultConfigFilename

            // Check if file exists and ask for confirmation
            if FileManager.default.fileExists(atPath: destination) {
                let result = try handleExistingFile(at: destination, ui: ui)
                if !result { return }
            }

            // Determine file contents: wizard or direct template
            let rawContents: String
            let wizardResult: InitWizardResult?

            if let platform {
                // Direct flag — use full template
                rawContents = templateForPlatform(platform)
                wizardResult = nil
            } else if TTYDetector.isTTY {
                // Interactive wizard
                let result = InitWizard.run()
                let template = templateForPlatform(result.platform)
                rawContents = InitWizard.applyResult(result, to: template)
                wizardResult = result
            } else {
                // Non-TTY without --platform
                throw ValidationError("Missing required option: --platform. Use -p ios|android|flutter|web.")
            }

            // Substitute local schema paths with published package URIs
            let fileContents = Self.substitutePackageURI(in: rawContents)

            // Write new config file
            try writeConfigFile(
                contents: fileContents,
                to: destination,
                ui: ui,
                wizardResult: wizardResult
            )
        }

        /// Replace `.exfig/schemas/` paths with published `package://` URIs using current CLI version.
        static func substitutePackageURI(in template: String) -> String {
            let version = ExFigCommand.version // e.g. "v2.8.1"
            let semver = version.hasPrefix("v") ? String(version.dropFirst()) : version
            let packagePrefix =
                "package://github.com/DesignPipe/exfig/releases/download/\(version)/exfig@\(semver)#/"
            return template.replacingOccurrences(of: ".exfig/schemas/", with: packagePrefix)
        }

        /// Return the full PKL template for a given platform.
        private func templateForPlatform(_ platform: Platform) -> String {
            switch platform {
            case .android: androidConfigFileContents
            case .ios: iosConfigFileContents
            case .flutter: flutterConfigFileContents
            case .web: webConfigFileContents
            }
        }

        /// Handles existing file: prompts for confirmation and removes if approved.
        /// - Returns: `true` to proceed with overwrite, `false` if user cancelled
        private func handleExistingFile(at destination: String, ui: TerminalUI) throws -> Bool {
            if !TTYDetector.isTTY {
                ui.error("Config file already exists at: \(destination)")
                throw ExFigError
                    .custom(
                        errorString: "Config file already exists. Delete it manually or run in interactive mode."
                    )
            }

            ui.warning("Config file already exists at: \(destination)")

            let overwrite = NooraUI.yesOrNoPrompt(
                question: "Overwrite existing config file?",
                defaultAnswer: false,
                description: "The current exfig.pkl will be replaced"
            )

            if !overwrite {
                ui.info("Operation cancelled.")
                return false
            }

            // Remove existing file
            do {
                try FileManager.default.removeItem(atPath: destination)
                ui.debug("Removed existing config file at: \(destination)")
            } catch {
                let message = "Failed to remove existing config file: \(error.localizedDescription)"
                throw ExFigError.custom(errorString: message)
            }

            return true
        }

        private func writeConfigFile(
            contents: String,
            to destination: String,
            ui: TerminalUI,
            wizardResult: InitWizardResult? = nil
        ) throws {
            guard let fileData = contents.data(using: .utf8) else {
                throw ExFigError.custom(errorString: "Failed to encode config file contents")
            }

            let success = FileManager.default.createFile(atPath: destination, contents: fileData, attributes: nil)
            if success {
                ui.success("Config file generated: \(destination)")
                ui.info("")
                ui.info("Next steps:")

                // When wizard provided file IDs, skip "edit file IDs" step
                let stepOffset: Int
                if wizardResult != nil {
                    stepOffset = 1
                } else {
                    ui.info("1. Edit \(ExFigOptions.defaultConfigFilename) with your Figma file IDs")
                    stepOffset = 2
                }

                if ProcessInfo.processInfo.environment["FIGMA_PERSONAL_TOKEN"] == nil {
                    ui.info("\(stepOffset). Set your Figma token (missing):")
                    ui.info("   export FIGMA_PERSONAL_TOKEN=your_token_here")
                } else {
                    ui.info("\(stepOffset). Figma token detected in environment ✅")
                }

                ui.info("\(stepOffset + 1). Run export commands:")
                if let result = wizardResult {
                    for assetType in result.selectedAssetTypes {
                        ui.info("   exfig \(assetType.commandName)")
                    }
                } else {
                    ui.info("   exfig colors")
                    ui.info("   exfig icons")
                    ui.info("   exfig images")
                    ui.info("   exfig typography")
                }
            } else {
                throw ExFigError.custom(errorString: "Unable to create config file at: \(destination)")
            }
        }
    }
}
