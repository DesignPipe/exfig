import ExFigConfig
import ExFigCore
import FigmaAPI
import Foundation
import Logging

enum SourceFactory {
    static func createColorsSource(
        for input: ColorsSourceInput,
        client: Client?,
        ui: TerminalUI,
        filter: String?
    ) throws -> any ColorsSource {
        switch input.sourceKind {
        case .figma:
            guard let client else { throw ExFigError.accessTokenNotFound }
            return FigmaColorsSource(client: client, ui: ui, filter: filter)
        case .tokensFile:
            return TokensFileColorsSource(ui: ui)
        case .penpot:
            return PenpotColorsSource(ui: ui)
        case .tokensStudio, .sketchFile:
            throw ExFigError.unsupportedSourceKind(input.sourceKind, assetType: "colors")
        }
    }

    // swiftlint:disable:next function_parameter_count
    static func createComponentsSource(
        for sourceKind: DesignSourceKind,
        client: Client?,
        params: PKLConfig,
        platform: Platform,
        logger: Logger,
        filter: String?,
        ui: TerminalUI,
        variablesCache: VariablesCache? = nil,
        componentsCache: ComponentsCache? = nil
    ) throws -> any ComponentsSource {
        switch sourceKind {
        case .figma:
            guard let client else { throw ExFigError.accessTokenNotFound }
            return FigmaComponentsSource(
                client: client,
                params: params,
                platform: platform,
                logger: logger,
                filter: filter,
                variablesCache: variablesCache,
                componentsCache: componentsCache
            )
        case .penpot:
            return PenpotComponentsSource(ui: ui)
        case .tokensFile, .tokensStudio, .sketchFile:
            throw ExFigError.unsupportedSourceKind(sourceKind, assetType: "icons/images")
        }
    }

    static func createTypographySource(
        for sourceKind: DesignSourceKind,
        client: Client?,
        ui: TerminalUI
    ) throws -> any TypographySource {
        switch sourceKind {
        case .figma:
            guard let client else { throw ExFigError.accessTokenNotFound }
            return FigmaTypographySource(client: client)
        case .penpot:
            return PenpotTypographySource(ui: ui)
        case .tokensFile, .tokensStudio, .sketchFile:
            throw ExFigError.unsupportedSourceKind(sourceKind, assetType: "typography")
        }
    }
}
