import ArgumentParser
import ExFigConfig
import ExFigCore
import FigmaAPI
import Foundation

extension ExFigCommand {
    struct Lint: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "lint",
            abstract: "Lint Figma file structure against config",
            discussion: """
            Validates that the Figma file follows the conventions required by your ExFig config.
            Checks naming conventions, frame/page structure, variable bindings, dark mode setup, and more.

            Examples:
              exfig lint -i exfig.pkl                              # Lint one config
              exfig lint -i exfig.pkl --lint-config lint.pkl        # Add lint-only policies
              exfig lint -i exfig.pkl --rules naming-convention    # Filter rules
              exfig lint -i exfig.pkl --format json                # JSON output for CI
              exfig lint -i exfig.pkl --severity error             # Only errors
            """
        )

        @OptionGroup
        var globalOptions: GlobalOptions

        @OptionGroup
        var options: ExFigOptions

        @OptionGroup
        var faultToleranceOptions: FaultToleranceOptions

        @Option(name: .long, help: "Comma-separated list of rule IDs to run")
        var rules: String?

        @Option(name: .long, help: "Output format: text or json")
        var format: LintOutputFormat = .text

        @Option(name: .long, help: "Minimum severity: error, warning, or info")
        var severity: LintSeverity = .info

        @Option(
            name: .long,
            help: "Path to optional lint-only PKL config. Defaults to lint.pkl next to the input config."
        )
        var lintConfig: String?

        func run() async throws {
            // JSON mode: force quiet to keep stdout clean for machine parsing
            let effectiveVerbose = globalOptions.verbose
            let effectiveQuiet = format == .json ? true : globalOptions.quiet

            ExFigCommand.initializeTerminalUI(
                verbose: effectiveVerbose, quiet: effectiveQuiet
            )
            ExFigCommand.checkSchemaVersionIfNeeded()
            let ui = ExFigCommand.terminalUI!

            let ruleFilter: Set<String>? = rules.map {
                Set($0.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) })
            }

            let figma = options.params.figma
            let client = resolveClient(
                accessToken: options.accessToken,
                timeout: figma?.timeout,
                rateLimit: figma?.rateLimit,
                maxRetries: figma?.maxRetries,
                options: faultToleranceOptions,
                ui: ui
            )

            let cache = LintDataCache()
            let overlayConfig = try await LintConfigLoader.load(
                explicitPath: lintConfig,
                mainConfigPath: options.input
            )
            let context = LintContext(
                config: options.params,
                lintConfig: overlayConfig,
                client: client,
                cache: cache,
                ui: ui
            )
            let engine = LintEngine.default

            let diagnostics = try await ui.withSpinnerMessage(
                "Linting..."
            ) { updateMessage in
                try await engine.run(
                    context: context,
                    ruleFilter: ruleFilter,
                    minSeverity: severity
                ) { message in
                    updateMessage(message)
                }
            }

            let reporter = LintReporter(
                format: format,
                useColors: ui.outputMode == .normal
            )
            try reporter.report(diagnostics: diagnostics, ui: ui)

            if diagnostics.contains(where: { $0.severity == .error }) {
                throw ExitCode.failure
            }
        }
    }
}
