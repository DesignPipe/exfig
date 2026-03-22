import ExFigCore
import Foundation
import PenpotAPI

struct PenpotTypographySource: TypographySource {
    let ui: TerminalUI

    func loadTypography(from input: TypographySourceInput) async throws -> TypographyLoadOutput {
        let effectiveBaseURL = input.penpotBaseURL ?? BasePenpotClient.defaultBaseURL
        let client = try PenpotClientFactory.makeClient(baseURL: effectiveBaseURL)

        let fileResponse = try await client.request(GetFileEndpoint(fileId: input.fileId))

        guard let typographies = fileResponse.data.typographies else {
            ui.warning("Penpot file '\(fileResponse.name)' has no library typographies")
            return TypographyLoadOutput(textStyles: [])
        }

        var textStyles: [TextStyle] = []

        for (_, typography) in typographies.sorted(by: { $0.key < $1.key }) {
            guard let fontSize = typography.fontSize else {
                ui.warning("Typography '\(typography.name)' has unparseable font-size — skipping")
                continue
            }

            let name = if let path = typography.path {
                path + "/" + typography.name
            } else {
                typography.name
            }

            let textCase = mapTextTransform(typography.textTransform)

            if typography.letterSpacing == nil {
                ui.warning("Typography '\(typography.name)' has no letter-spacing — defaulting to 0")
            }

            textStyles.append(TextStyle(
                name: name,
                fontName: typography.fontFamily,
                fontSize: fontSize,
                fontStyle: nil,
                lineHeight: typography.lineHeight,
                letterSpacing: typography.letterSpacing ?? 0,
                textCase: textCase
            ))
        }

        return TypographyLoadOutput(textStyles: textStyles)
    }

    // MARK: - Private

    private func mapTextTransform(_ transform: String?) -> TextStyle.TextCase {
        switch transform {
        case "uppercase":
            return .uppercased
        case "lowercase":
            return .lowercased
        case nil, "none":
            return .original
        default:
            ui.warning("Unknown text transform '\(transform!)' — using original")
            return .original
        }
    }
}
