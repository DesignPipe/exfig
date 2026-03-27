import ExFigCore
import FigmaAPI

// swiftlint:disable:next large_tuple
typealias ColorsLoaderOutput = (light: [Color], dark: [Color]?, lightHC: [Color]?, darkHC: [Color]?)

/// Loads colors from Figma
final class ColorsLoader: Sendable {
    private let client: Client
    private let figmaParams: PKLConfig.Figma
    private let colorParams: PKLConfig.Common.Colors?
    private let filter: String?

    init(
        client: Client,
        figmaParams: PKLConfig.Figma,
        colorParams: PKLConfig.Common.Colors?,
        filter: String?
    ) {
        self.client = client
        self.figmaParams = figmaParams
        self.colorParams = colorParams
        self.filter = filter
    }

    func load() async throws -> ColorsLoaderOutput {
        guard figmaParams.lightFileId != nil else {
            throw ExFigError.custom(errorString:
                "figma.lightFileId is required for legacy Styles API colors export. " +
                    "Use common.variablesColors or multi-entry colors format instead."
            )
        }
        guard colorParams?.suffixDarkMode != nil else {
            return try await loadColorsFromLightAndDarkFile()
        }
        return try await loadColorsFromSingleFile()
    }

    private func loadColorsFromLightAndDarkFile() async throws -> ColorsLoaderOutput {
        // Build list of files to load
        // swiftlint:disable:next force_unwrapping
        var filesToLoad: [(key: String, fileId: String)] = [
            ("light", figmaParams.lightFileId!),
        ]

        if let darkFileId = figmaParams.darkFileId {
            filesToLoad.append(("dark", darkFileId))
        }
        if let lightHCFileId = figmaParams.lightHighContrastFileId {
            filesToLoad.append(("lightHC", lightHCFileId))
        }
        if let darkHCFileId = figmaParams.darkHighContrastFileId {
            filesToLoad.append(("darkHC", darkHCFileId))
        }

        // Load all files in parallel
        let results = try await withThrowingTaskGroup(
            of: (String, [Color]).self
        ) { [self] group in
            for (key, fileId) in filesToLoad {
                group.addTask { [key, fileId] in
                    let colors = try await self.loadColors(fileId: fileId)
                    return (key, colors)
                }
            }

            var colorsByKey: [String: [Color]] = [:]
            for try await (key, colors) in group {
                colorsByKey[key] = colors
            }
            return colorsByKey
        }

        guard let lightColors = results["light"] else {
            throw ExFigError.stylesNotFound
        }

        return (
            lightColors,
            results["dark"],
            results["lightHC"],
            results["darkHC"]
        )
    }

    private func loadColorsFromSingleFile() async throws -> ColorsLoaderOutput {
        // swiftlint:disable:next force_unwrapping
        let colors = try await loadColors(fileId: figmaParams.lightFileId!)

        let darkSuffix = colorParams?.suffixDarkMode?.suffix ?? "_dark"
        let lightHCSuffix = colorParams?.lightHCModeSuffix ?? "_lightHC"
        let darkHCSuffix = colorParams?.darkHCModeSuffix ?? "_darkHC"

        let lightColors = colors
            .filter {
                !$0.name.hasSuffix(darkSuffix) &&
                    !$0.name.hasSuffix(lightHCSuffix) &&
                    !$0.name.hasSuffix(darkHCSuffix)
            }
        let darkColors = filteredColors(colors, suffix: darkSuffix)
        let lightHCColors = filteredColors(colors, suffix: lightHCSuffix)
        let darkHCColors = filteredColors(colors, suffix: darkHCSuffix)
        return (lightColors, darkColors, lightHCColors, darkHCColors)
    }

    private func filteredColors(_ colors: [Color], suffix: String) -> [Color] {
        colors
            .filter { $0.name.hasSuffix(suffix) }
            .map { color -> Color in
                var newColor = color
                newColor.name = String(color.name.dropLast(suffix.count))
                return newColor
            }
    }

    private func loadColors(fileId: String) async throws -> [Color] {
        var styles = try await loadStyles(fileId: fileId)

        if let filter {
            let assetsFilter = AssetsFilter(filter: filter)
            styles = styles.filter { style -> Bool in
                assetsFilter.match(name: style.name)
            }
        }

        guard !styles.isEmpty else {
            throw ExFigError.stylesNotFound
        }

        let nodes = try await loadNodes(fileId: fileId, nodeIds: styles.map(\.nodeId))
        return nodesAndStylesToColors(nodes: nodes, styles: styles)
    }

    /// Соотносит массив Style и Node чтобы получит массив Color
    private func nodesAndStylesToColors(nodes: [NodeId: Node], styles: [Style]) -> [Color] {
        styles.compactMap { style -> Color? in
            guard let node = nodes[style.nodeId] else { return nil }
            guard let fill = node.document.fills.first?.asSolid else { return nil }
            let alpha: Double = fill.opacity ?? fill.color.a
            let platform = Platform(rawValue: style.description)

            return Color(
                name: style.name,
                platform: platform,
                red: fill.color.r,
                green: fill.color.g,
                blue: fill.color.b,
                alpha: alpha
            )
        }
    }

    private func loadStyles(fileId: String) async throws -> [Style] {
        let endpoint = StylesEndpoint(fileId: fileId)
        let styles = try await client.request(endpoint)
        return styles.filter {
            $0.styleType == .fill && useStyle($0)
        }
    }

    private func useStyle(_ style: Style) -> Bool {
        guard !style.description.isEmpty else {
            return true // Цвет общий
        }
        return !style.description.contains("none")
    }

    private func loadNodes(fileId: String, nodeIds: [String]) async throws -> [NodeId: Node] {
        let endpoint = NodesEndpoint(fileId: fileId, nodeIds: nodeIds)
        return try await client.request(endpoint)
    }
}
