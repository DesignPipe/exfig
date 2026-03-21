import ExFigConfig
import ExFigCore
import FigmaAPI
import Foundation

struct FigmaColorsSource: ColorsSource {
    let client: Client
    let ui: TerminalUI
    let filter: String?

    func loadColors(from input: ColorsSourceInput) async throws -> ColorsLoadOutput {
        guard let config = input.sourceConfig as? FigmaColorsConfig else {
            throw ExFigError.configurationError(
                "FigmaColorsSource requires FigmaColorsConfig, got \(type(of: input.sourceConfig))"
            )
        }

        let variableParams = Common.VariablesColors(
            tokensFileId: config.tokensFileId,
            tokensCollectionName: config.tokensCollectionName,
            lightModeName: config.lightModeName,
            darkModeName: config.darkModeName,
            lightHCModeName: config.lightHCModeName,
            darkHCModeName: config.darkHCModeName,
            primitivesModeName: config.primitivesModeName,
            nameValidateRegexp: input.nameValidateRegexp,
            nameReplaceRegexp: input.nameReplaceRegexp
        )

        let loader = ColorsVariablesLoader(
            client: client,
            variableParams: variableParams,
            filter: filter
        )

        let result = try await loader.load()

        for warning in result.warnings {
            ui.warning(warning)
        }

        return ColorsLoadOutput(
            light: result.output.light,
            dark: result.output.dark ?? [],
            lightHC: result.output.lightHC ?? [],
            darkHC: result.output.darkHC ?? []
        )
    }
}
