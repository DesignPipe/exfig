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
