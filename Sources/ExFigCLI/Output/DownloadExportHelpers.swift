import ExFigCore
import FigmaAPI
import Foundation

// MARK: - Raw Asset Entry (unified for icons and images)

/// Unified structure for raw asset export (icons, images).
struct RawAssetEntry: Encodable {
    let name: String
    let nodeId: String
    let description: String?
    let exportUrl: String

    init(from component: Component, url: String) {
        name = component.name
        nodeId = component.nodeId
        description = component.description
        exportUrl = url
    }
}

// MARK: - Asset Export Helpers

/// Shared helpers for exporting assets (icons, images) to JSON.
enum AssetExportHelper {
    /// Builds format params for Figma image export.
    static func makeFormatParams(format: String, scale: Double) -> FormatParams {
        switch format {
        case "svg": SVGParams()
        case "pdf": PDFParams()
        case "png": PNGParams(scale: scale)
        default: FormatParams(scale: scale, format: format)
        }
    }

    /// Exports components to W3C format and writes to file.
    static func exportW3C(
        components: [NodeId: Component],
        exportUrls: [NodeId: String],
        fileId: String? = nil,
        outputURL: URL,
        compact: Bool,
        w3cVersion: W3CVersion = .v2025
    ) throws {
        let assets = components.compactMap { nodeId, component -> AssetToken? in
            guard let url = exportUrls[nodeId] else { return nil }
            return AssetToken(
                name: component.name,
                url: url,
                description: component.description,
                nodeId: component.nodeId,
                fileId: fileId
            )
        }

        let exporter = W3CTokensExporter(version: w3cVersion)
        let tokens = exporter.exportAssets(assets: assets)
        let jsonData = try exporter.serializeToJSON(tokens, compact: compact)

        try jsonData.write(to: outputURL)
    }

    /// Exports components to raw format and writes to file.
    static func exportRaw(
        components: [NodeId: Component],
        exportUrls: [NodeId: String],
        fileId: String,
        outputURL: URL,
        compact: Bool
    ) throws {
        let rawData = components.compactMap { nodeId, component -> RawAssetEntry? in
            guard let url = exportUrls[nodeId] else { return nil }
            return RawAssetEntry(from: component, url: url)
        }

        let metadata = RawExportMetadata(
            name: fileId,
            fileId: fileId,
            exfigVersion: ExFigCommand.version
        )

        let output = RawExportOutput(source: metadata, data: rawData)
        let exporter = RawExporter()
        let jsonData = try exporter.serialize(output, compact: compact)

        try jsonData.write(to: outputURL)
    }

    /// Fetches components from a frame and optionally filters them.
    static func fetchComponents(
        client: Client,
        fileId: String,
        frameName: String,
        pageName: String? = nil,
        filter: String?
    ) async throws -> [NodeId: Component] {
        let endpoint = ComponentsEndpoint(fileId: fileId)
        let allComponents = try await client.request(endpoint)
        var comps = allComponents
            .filter {
                $0.containingFrame.name == frameName
                    && (pageName == nil || $0.containingFrame.pageName == pageName)
            }

        if let pageName, comps.isEmpty {
            let frameComponents = allComponents.filter { $0.containingFrame.name == frameName }
            if !frameComponents.isEmpty {
                let availablePages = Set(frameComponents.compactMap(\.containingFrame.pageName))
                let pages = availablePages.sorted().joined(separator: ", ")
                ExFigCommand.logger.info(
                    "Page filter '\(pageName)' matched no components in frame '\(frameName)'. Available pages: \(pages)"
                )
            }
        }

        if let filter {
            let assetsFilter = AssetsFilter(filter: filter)
            comps = comps.filter { assetsFilter.match(name: $0.name) }
        }

        return Dictionary(uniqueKeysWithValues: comps.map { ($0.nodeId, $0) })
    }

    /// Gets export URLs for components.
    static func getExportUrls(
        client: Client,
        fileId: String,
        nodeIds: [NodeId],
        format: String,
        scale: Double
    ) async throws -> [NodeId: String] {
        let params = makeFormatParams(format: format, scale: scale)
        let endpoint = ImageEndpoint(fileId: fileId, nodeIds: nodeIds, params: params)
        let result = try await client.request(endpoint)
        return result.compactMapValues { $0 }
    }
}

// MARK: - Color Export Helpers

/// Shared helpers for exporting colors to JSON.
enum ColorExportHelper {
    /// Converts ColorsLoaderOutput to mode-indexed dictionary for W3C export.
    static func buildColorsByMode(from colors: ColorsLoaderOutput) -> [String: [Color]] {
        var colorsByMode: [String: [Color]] = [:]
        colorsByMode["Light"] = colors.light

        if let dark = colors.dark {
            colorsByMode["Dark"] = dark
        }
        if let lightHC = colors.lightHC {
            colorsByMode["Contrast Light"] = lightHC
        }
        if let darkHC = colors.darkHC {
            colorsByMode["Contrast Dark"] = darkHC
        }

        return colorsByMode
    }

    /// Converts ColorsLoaderOutput to raw data structure.
    static func convertToRawData(_ colors: ColorsLoaderOutput) -> RawColorsData {
        RawColorsData(
            light: colors.light.map { RawColorEntry(from: $0) },
            dark: colors.dark?.map { RawColorEntry(from: $0) },
            lightHC: colors.lightHC?.map { RawColorEntry(from: $0) },
            darkHC: colors.darkHC?.map { RawColorEntry(from: $0) }
        )
    }

    /// Mode key to display name mapping used by buildColorsByMode.
    static let modeKeyToName: [String: String] = [
        "light": "Light",
        "dark": "Dark",
        "lightHC": "Contrast Light",
        "darkHC": "Contrast Dark",
    ]

    /// Exports colors to W3C format and writes to file.
    static func exportW3C(
        colors: ColorsLoaderOutput,
        descriptions: [String: String] = [:],
        metadata: [String: ColorTokenMetadata] = [:],
        aliases: ColorsVariablesLoader.ColorAliases = [:],
        outputURL: URL,
        compact: Bool,
        w3cVersion: W3CVersion = .v2025
    ) throws {
        let colorsByMode = buildColorsByMode(from: colors)

        let exporter = W3CTokensExporter(version: w3cVersion)
        let tokens = exporter.exportColors(
            colorsByMode: colorsByMode,
            descriptions: descriptions,
            metadata: metadata,
            aliases: aliases,
            modeKeyToName: modeKeyToName
        )
        let jsonData = try exporter.serializeToJSON(tokens, compact: compact)

        try jsonData.write(to: outputURL)
    }

    /// Exports colors to raw format and writes to file.
    static func exportRaw(
        colors: ColorsLoaderOutput,
        fileId: String,
        outputURL: URL,
        compact: Bool
    ) throws {
        let rawData = convertToRawData(colors)

        let metadata = RawExportMetadata(
            name: fileId,
            fileId: fileId,
            exfigVersion: ExFigCommand.version
        )

        let output = RawExportOutput(source: metadata, data: rawData)
        let exporter = RawExporter()
        let jsonData = try exporter.serialize(output, compact: compact)

        try jsonData.write(to: outputURL)
    }
}

// MARK: - Typography Export Helpers

/// Shared helpers for exporting typography to JSON.
enum TypographyExportHelper {
    /// Exports text styles to W3C format and writes to file.
    static func exportW3C(
        textStyles: [TextStyle],
        outputURL: URL,
        compact: Bool,
        w3cVersion: W3CVersion = .v2025
    ) throws {
        let exporter = W3CTokensExporter(version: w3cVersion)
        let tokens = exporter.exportTypography(textStyles: textStyles)
        let jsonData = try exporter.serializeToJSON(tokens, compact: compact)

        try jsonData.write(to: outputURL)
    }

    /// Exports text styles to raw format and writes to file.
    static func exportRaw(
        textStyles: [TextStyle],
        fileId: String,
        outputURL: URL,
        compact: Bool
    ) throws {
        let rawData = textStyles.map { RawTextStyleEntry(from: $0) }

        let metadata = RawExportMetadata(
            name: fileId,
            fileId: fileId,
            exfigVersion: ExFigCommand.version
        )

        let output = RawExportOutput(source: metadata, data: rawData)
        let exporter = RawExporter()
        let jsonData = try exporter.serialize(output, compact: compact)

        try jsonData.write(to: outputURL)
    }
}
