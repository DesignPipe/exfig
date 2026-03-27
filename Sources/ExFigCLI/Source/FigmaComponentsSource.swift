import ExFigConfig
import ExFigCore
import FigmaAPI
import Foundation
import Logging

struct FigmaComponentsSource: ComponentsSource {
    let client: Client
    let params: PKLConfig
    let platform: Platform
    let logger: Logger
    let filter: String?
    let variablesCache: VariablesCache?

    func loadIcons(from input: IconsSourceInput) async throws -> IconsLoadOutput {
        let config = IconsLoaderConfig(
            entryFileId: input.figmaFileId,
            frameName: input.frameName,
            pageName: input.pageName,
            format: input.format,
            renderMode: input.renderMode,
            renderModeDefaultSuffix: input.renderModeDefaultSuffix,
            renderModeOriginalSuffix: input.renderModeOriginalSuffix,
            renderModeTemplateSuffix: input.renderModeTemplateSuffix,
            rtlProperty: input.rtlProperty
        )

        let loader = IconsLoader(
            client: client,
            params: params,
            platform: platform,
            logger: logger,
            config: config
        )

        let result = try await loader.load(filter: filter)

        // Variable-mode dark generation: resolve variable bindings and replace colors in SVGs
        let hasPartialConfig = input.variablesCollectionName != nil
            || input.variablesLightModeName != nil
            || input.variablesDarkModeName != nil
        if let collectionName = input.variablesCollectionName,
           let lightModeName = input.variablesLightModeName,
           let darkModeName = input.variablesDarkModeName
        {
            guard let fileId = input.figmaFileId ?? params.figma?.lightFileId, !fileId.isEmpty else {
                logger.warning("Variable-mode dark generation requires a Figma file ID, skipping")
                return IconsLoadOutput(light: result.light, dark: [])
            }
            let generator = VariableModeDarkGenerator(client: client, logger: logger, variablesCache: variablesCache)
            let darkPacks = try await generator.generateDarkVariants(
                lightPacks: result.light,
                config: .init(
                    fileId: fileId,
                    collectionName: collectionName,
                    lightModeName: lightModeName,
                    darkModeName: darkModeName,
                    primitivesModeName: input.variablesPrimitivesModeName,
                    variablesFileId: input.variablesFileId
                )
            )
            return IconsLoadOutput(light: result.light, dark: darkPacks)
        } else if hasPartialConfig {
            let col = input.variablesCollectionName ?? "nil"
            let light = input.variablesLightModeName ?? "nil"
            let dark = input.variablesDarkModeName ?? "nil"
            logger.warning(
                "Variable-mode dark: incomplete config — collection=\(col) light=\(light) dark=\(dark)"
            )
        }

        return IconsLoadOutput(
            light: result.light,
            dark: result.dark ?? []
        )
    }

    func loadImages(from input: ImagesSourceInput) async throws -> ImagesLoadOutput {
        let loaderSourceFormat: ImagesSourceFormat = input.sourceFormat == .svg ? .svg : .png

        let config = ImagesLoaderConfig(
            entryFileId: input.figmaFileId,
            frameName: input.frameName,
            pageName: input.pageName,
            scales: input.scales,
            format: nil,
            sourceFormat: loaderSourceFormat,
            rtlProperty: input.rtlProperty
        )

        let loader = ImagesLoader(
            client: client,
            params: params,
            platform: platform,
            logger: logger,
            config: config
        )

        let result = try await loader.load(filter: filter)

        return ImagesLoadOutput(
            light: result.light,
            dark: result.dark ?? []
        )
    }
}
