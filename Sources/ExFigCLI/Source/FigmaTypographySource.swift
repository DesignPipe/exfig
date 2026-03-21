import ExFigCore
import FigmaAPI
import Foundation

struct FigmaTypographySource: TypographySource {
    let client: Client

    func loadTypography(from input: TypographySourceInput) async throws -> TypographyLoadOutput {
        let loader = TextStylesLoader(client: client, fileId: input.fileId)
        let textStyles = try await loader.load()
        return TypographyLoadOutput(textStyles: textStyles)
    }
}
