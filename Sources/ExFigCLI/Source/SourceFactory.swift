import ExFigConfig
import ExFigCore
import FigmaAPI
import Foundation
import Logging

enum SourceFactory {
    static func createColorsSource(
        for input: ColorsSourceInput,
        client: Client,
        ui: TerminalUI,
        filter: String?
    ) throws -> any ColorsSource {
        switch input.sourceKind {
        case .figma:
            FigmaColorsSource(client: client, ui: ui, filter: filter)
        case .tokensFile:
            TokensFileColorsSource(ui: ui)
        case .penpot, .tokensStudio, .sketchFile:
            throw ExFigError.unsupportedSourceKind(input.sourceKind)
        }
    }

    // swiftlint:disable:next function_parameter_count
    static func createComponentsSource(
        for sourceKind: DesignSourceKind,
        client: Client,
        params: PKLConfig,
        platform: Platform,
        logger: Logger,
        filter: String?
    ) throws -> any ComponentsSource {
        switch sourceKind {
        case .figma:
            FigmaComponentsSource(
                client: client,
                params: params,
                platform: platform,
                logger: logger,
                filter: filter
            )
        case .penpot, .tokensFile, .tokensStudio, .sketchFile:
            throw ExFigError.unsupportedSourceKind(sourceKind)
        }
    }

    static func createTypographySource(
        for sourceKind: DesignSourceKind,
        client: Client
    ) throws -> any TypographySource {
        switch sourceKind {
        case .figma:
            FigmaTypographySource(client: client)
        case .penpot, .tokensFile, .tokensStudio, .sketchFile:
            throw ExFigError.unsupportedSourceKind(sourceKind)
        }
    }
}
