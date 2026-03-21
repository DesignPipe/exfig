import ExFigCore
import Foundation

struct TokensFileColorsSource: ColorsSource {
    let ui: TerminalUI

    func loadColors(from input: ColorsSourceInput) async throws -> ColorsLoadOutput {
        guard let config = input.sourceConfig as? TokensFileColorsConfig else {
            throw ExFigError.configurationError(
                "TokensFileColorsSource requires TokensFileColorsConfig, got \(type(of: input.sourceConfig))"
            )
        }

        var source = try TokensFileSource.parse(fileAt: config.filePath)
        try source.resolveAliases()

        for warning in source.warnings {
            ui.warning(warning)
        }

        var colors = source.toColors()

        if let groupFilter = config.groupFilter {
            let prefix = groupFilter.replacingOccurrences(of: ".", with: "/") + "/"
            colors = colors.filter { $0.name.hasPrefix(prefix) }
        }

        return ColorsLoadOutput(light: colors)
    }
}
