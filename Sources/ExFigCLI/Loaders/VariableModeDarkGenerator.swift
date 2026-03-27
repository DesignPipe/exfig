// swiftlint:disable file_length
import ExFigCore
import FigmaAPI
import Foundation
import Logging

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// swiftlint:disable type_body_length

/// Generates dark SVG variants from light SVGs by resolving Figma Variable bindings.
///
/// Given light icon packs and a variables collection with light/dark modes, this generator:
/// 1. Fetches variable definitions from the Figma Variables API
/// 2. Fetches icon nodes to discover `boundVariables` on fills/strokes
/// 3. Resolves each variable's dark mode value (following alias chains)
/// 4. Downloads light SVGs, replaces hex colors, and writes dark SVGs to temp files
struct VariableModeDarkGenerator {
    /// Maximum depth for resolving variable alias chains (prevents infinite recursion).
    private static let maxAliasDepth = 10

    struct Config {
        let fileId: String
        let collectionName: String
        let lightModeName: String
        let darkModeName: String
        let primitivesModeName: String?
        /// Separate file ID for loading variables (when primitives are in a library file).
        let variablesFileId: String?

        init(
            fileId: String,
            collectionName: String,
            lightModeName: String,
            darkModeName: String,
            primitivesModeName: String? = nil,
            variablesFileId: String? = nil
        ) {
            precondition(!fileId.isEmpty, "VariableModeDarkGenerator.Config.fileId must not be empty")
            self.fileId = fileId
            self.collectionName = collectionName
            self.lightModeName = lightModeName
            self.darkModeName = darkModeName
            self.primitivesModeName = primitivesModeName
            self.variablesFileId = variablesFileId
        }
    }

    /// Resolved mode IDs for variable resolution.
    struct ModeContext {
        let lightModeId: String
        let darkModeId: String
        let primitivesModeId: String?
    }

    let client: Client
    let logger: Logger
    let variablesCache: VariablesCache?

    init(client: Client, logger: Logger, variablesCache: VariablesCache? = nil) {
        self.client = client
        self.logger = logger
        self.variablesCache = variablesCache
    }

    /// Generates dark SVG variants by resolving variable bindings and replacing colors.
    ///
    /// - Parameters:
    ///   - lightPacks: Light mode icon packs (must be SVG format with Figma URLs).
    ///   - config: Variables collection configuration.
    /// - Returns: Dark mode icon packs with modified SVGs saved to temp files.
    func generateDarkVariants(
        lightPacks: [ImagePack],
        config: Config
    ) async throws -> [ImagePack] {
        guard !lightPacks.isEmpty else { return [] }

        // 1. Fetch variable definitions
        let localMeta = try await loadVariables(fileId: config.fileId)
        logger.debug("Variable-mode dark: loaded \(localMeta.variables.count) local variables")

        // When library file specified, load its variables for name-based cross-file resolution.
        // Variable IDs are file-scoped — alias targets from the icons file don't exist in the
        // library file by ID. We resolve by matching variable NAME across files.
        let libMeta: VariablesMeta?
        if let libFileId = config.variablesFileId, libFileId != config.fileId {
            let lib = try await loadVariables(fileId: libFileId)
            logger.debug("Variable-mode dark: loaded \(lib.variables.count) library variables from \(libFileId)")
            libMeta = lib
        } else {
            libMeta = nil
        }

        // Use local meta for ID-based lookups (matches node boundVariables)
        let variablesMeta = localMeta

        // 2. Find collection and extract mode IDs
        guard let modes = findModeIds(in: variablesMeta, config: config) else {
            let names = variablesMeta.variableCollections.values.map(\.name).sorted()
            logger.debug("Variable-mode dark: available collections: \(names)")
            logger.warning("""
            Variables dark mode: collection '\(config.collectionName)' not found or missing \
            modes '\(config.lightModeName)'/'\(config.darkModeName)'. \
            Available collections: \(variablesMeta.variableCollections.values.map(\.name).sorted()
                .joined(separator: ", "))
            """)
            return []
        }

        logger.debug("Variable-mode dark: modes light=\(modes.lightModeId) dark=\(modes.darkModeId)")

        // 3. Fetch nodes to discover boundVariables on paints
        let nodeIds = lightPacks.compactMap(\.nodeId)
        logger.debug("Variable-mode dark: \(nodeIds.count)/\(lightPacks.count) packs have nodeIds")

        guard !nodeIds.isEmpty else {
            logger.warning("Variable-mode dark generation: none of the light packs have node IDs, skipping")
            return []
        }

        let nodeMap = try await fetchNodesBatched(fileId: config.fileId, nodeIds: nodeIds)
        logger.debug("Variable-mode dark: fetched \(nodeMap.count) nodes")

        // 4. For each icon, build light→dark color map from boundVariables
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("exfig-variable-dark-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var cleanupNeeded = true
        defer {
            if cleanupNeeded {
                try? FileManager.default.removeItem(at: tempDir)
            }
        }

        let ctx = ResolutionContext(
            variablesMeta: variablesMeta,
            libMeta: libMeta,
            libNameIndex: libMeta.map { buildLibNameIndex(from: $0) },
            modes: modes,
            darkModeName: config.darkModeName
        )
        let darkPacks = try processLightPacks(
            lightPacks, nodeMap: nodeMap, ctx: ctx, tempDir: tempDir
        )

        // Keep temp dir alive — caller consumes the URLs during export, then OS cleans /tmp
        cleanupNeeded = false
        return darkPacks
    }

    // MARK: - Internal (testable)

    // swiftlint:disable cyclomatic_complexity

    func processLightPacks(
        _ lightPacks: [ImagePack],
        nodeMap: [String: Node],
        ctx: ResolutionContext,
        tempDir: URL
    ) throws -> [ImagePack] {
        var darkPacks: [ImagePack] = []

        for pack in lightPacks {
            guard let nodeId = pack.nodeId else {
                logger.warning("Icon '\(pack.name)' has no node ID, skipping dark generation")
                continue
            }

            guard let node = nodeMap[nodeId] else {
                logger.warning(
                    "Node '\(nodeId)' for icon '\(pack.name)' not returned by Figma API, skipping dark generation"
                )
                continue
            }

            let colorMap = buildColorMap(node: node, ctx: ctx, iconName: pack.name)

            guard !colorMap.isEmpty else {
                logger.debug("Icon '\(pack.name)' has no variable-bound colors, skipping dark generation")
                continue
            }

            guard let darkPack = try buildDarkPack(for: pack, colorMap: colorMap, tempDir: tempDir) else {
                continue
            }
            darkPacks.append(darkPack)
        }

        logger.debug("Variable-mode dark: generated \(darkPacks.count)/\(lightPacks.count) dark packs")
        return darkPacks
    }

    // swiftlint:enable cyclomatic_complexity

    // MARK: - Private

    private func buildDarkPack(
        for pack: ImagePack,
        colorMap: [String: ColorReplacement],
        tempDir: URL
    ) throws -> ImagePack? {
        guard let svgImage = pack.images.first else {
            logger.warning("Icon '\(pack.name)' has no images, skipping dark generation")
            return nil
        }

        let svgData: Data
        do {
            svgData = try Data(contentsOf: svgImage.url)
        } catch {
            logger.warning("Failed to read SVG for icon '\(pack.name)': \(error.localizedDescription)")
            return nil
        }

        guard let svgContent = String(data: svgData, encoding: .utf8) else {
            logger.warning("Icon '\(pack.name)' SVG is not valid UTF-8, skipping dark generation")
            return nil
        }

        let darkSVG = SVGColorReplacer.replaceColors(in: svgContent, colorMap: colorMap)

        let safeName = pack.name
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        let tempURL = tempDir.appendingPathComponent("\(safeName)_dark.svg")
        try Data(darkSVG.utf8).write(to: tempURL)

        return ImagePack(
            name: pack.name,
            images: [Image(
                name: pack.name,
                scale: .all,
                url: tempURL,
                format: "svg"
            )],
            platform: pack.platform,
            nodeId: pack.nodeId,
            fileId: pack.fileId
        )
    }

    /// Builds a name→variable index from library meta, warning on duplicate names.
    private func buildLibNameIndex(from meta: VariablesMeta) -> [String: VariableValue] {
        let grouped = Dictionary(grouping: meta.variables.values, by: \.name)
        var index: [String: VariableValue] = [:]
        for (name, vars) in grouped {
            if vars.count > 1 {
                logger.debug("Library file has \(vars.count) variables named '\(name)', using first match")
            }
            index[name] = vars[0]
        }
        return index
    }

    private func loadVariables(fileId: String) async throws -> VariablesMeta {
        if let cache = variablesCache {
            return try await cache.get(fileId: fileId) { [client] in
                try await client.request(VariablesEndpoint(fileId: fileId))
            }
        }
        return try await client.request(VariablesEndpoint(fileId: fileId))
    }

    func findModeIds(in meta: VariablesMeta, config: Config) -> ModeContext? {
        for collection in meta.variableCollections.values {
            guard collection.name == config.collectionName else { continue }

            var lightModeId: String?
            var darkModeId: String?
            var primitivesModeId: String?

            for mode in collection.modes {
                if mode.name == config.lightModeName {
                    lightModeId = mode.modeId
                } else if mode.name == config.darkModeName {
                    darkModeId = mode.modeId
                } else if mode.name == config.primitivesModeName {
                    primitivesModeId = mode.modeId
                }
            }

            guard let light = lightModeId, let dark = darkModeId else { continue }
            return ModeContext(lightModeId: light, darkModeId: dark, primitivesModeId: primitivesModeId)
        }
        return nil
    }

    /// Fetches nodes in batches of 100 (Figma API limit).
    private func fetchNodesBatched(
        fileId: String,
        nodeIds: [String]
    ) async throws -> [String: Node] {
        var allNodes: [String: Node] = [:]
        let batchSize = 100

        for batchStart in stride(from: 0, to: nodeIds.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, nodeIds.count)
            let batch = Array(nodeIds[batchStart ..< batchEnd])
            let endpoint = NodesEndpoint(fileId: fileId, nodeIds: batch)
            let nodes = try await client.request(endpoint)
            for (key, value) in nodes {
                allNodes[key] = value
            }
        }

        return allNodes
    }

    /// Context for cross-file variable resolution.
    struct ResolutionContext {
        let variablesMeta: VariablesMeta
        let libMeta: VariablesMeta?
        let libNameIndex: [String: VariableValue]?
        let modes: ModeContext
        let darkModeName: String
    }

    /// Walks a node tree and collects light→dark color mappings from boundVariables on paints.
    func buildColorMap(
        node: Node,
        ctx: ResolutionContext,
        iconName: String
    ) -> [String: ColorReplacement] {
        var colorMap: [String: ColorReplacement] = [:]
        collectBoundColors(from: node.document, ctx: ctx, colorMap: &colorMap, iconName: iconName)
        return colorMap
    }

    func collectBoundColors(
        from document: Document,
        ctx: ResolutionContext,
        colorMap: inout [String: ColorReplacement],
        iconName: String
    ) {
        for paint in document.fills {
            collectFromPaint(paint, ctx: ctx, colorMap: &colorMap, iconName: iconName)
        }
        if let strokes = document.strokes {
            for paint in strokes {
                collectFromPaint(paint, ctx: ctx, colorMap: &colorMap, iconName: iconName)
            }
        }
        if let children = document.children {
            for child in children {
                collectBoundColors(from: child, ctx: ctx, colorMap: &colorMap, iconName: iconName)
            }
        }
    }

    func collectFromPaint(
        _ paint: Paint,
        ctx: ResolutionContext,
        colorMap: inout [String: ColorReplacement],
        iconName: String
    ) {
        guard let boundVars = paint.boundVariables,
              let colorAlias = boundVars["color"],
              let lightColor = paint.color
        else { return }

        let lightHex = SVGColorReplacer.normalizeColor(
            r: lightColor.r,
            g: lightColor.g,
            b: lightColor.b
        )

        // Try local resolution first (same file)
        var darkColor = resolveDarkColor(
            variableId: colorAlias.id,
            modeId: ctx.modes.darkModeId,
            variablesMeta: ctx.variablesMeta,
            primitivesModeId: ctx.modes.primitivesModeId
        )

        // Cross-file fallback: find variable by name in library, resolve there
        if darkColor == nil, let libMeta = ctx.libMeta, let libNameIndex = ctx.libNameIndex {
            if let localVar = ctx.variablesMeta.variables[colorAlias.id] {
                darkColor = resolveViaLibrary(
                    variableName: localVar.name,
                    libMeta: libMeta,
                    libNameIndex: libNameIndex,
                    darkModeName: ctx.darkModeName
                )
            }
        }

        if let darkColor, lightHex != darkColor.hex || darkColor.changesOpacity {
            if let existing = colorMap[lightHex], existing.hex != darkColor.hex {
                let msg = "#\(lightHex) → multiple dark: #\(existing.hex), #\(darkColor.hex)"
                logger.warning("Icon '\(iconName)': \(msg)")
            }
            colorMap[lightHex] = darkColor
        }
    }

    /// Resolves a variable's dark color by finding it by name in the library file.
    func resolveViaLibrary(
        variableName: String,
        libMeta: VariablesMeta,
        libNameIndex: [String: VariableValue],
        darkModeName: String
    ) -> ColorReplacement? {
        guard let libVar = libNameIndex[variableName] else {
            logger.debug("Variable-mode dark: library fallback miss — '\(variableName)' not found in library")
            return nil
        }
        guard let libCollection = libMeta.variableCollections[libVar.variableCollectionId] else {
            let collId = libVar.variableCollectionId
            logger.debug("Variable-mode dark: library collection '\(collId)' not found for '\(variableName)'")
            return nil
        }

        // Match mode by NAME (mode IDs are file-scoped and differ between files)
        guard let libDarkModeId = libCollection.modes.first(where: { $0.name == darkModeName })?.modeId else {
            logger
                .debug(
                    "Variable-mode dark: library mode '\(darkModeName)' not found in collection '\(libCollection.name)'"
                )
            return nil
        }

        let result = resolveDarkColor(
            variableId: libVar.id,
            modeId: libDarkModeId,
            variablesMeta: libMeta,
            primitivesModeId: nil
        )
        if let result {
            logger
                .debug("Variable-mode dark: resolved '\(variableName)' via library → #\(result.hex) a=\(result.alpha)")
        }
        return result
    }

    /// Resolves a variable to its concrete color value in the given mode, following alias chains.
    func resolveDarkColor(
        variableId: String,
        modeId: String,
        variablesMeta: VariablesMeta,
        primitivesModeId: String?,
        depth: Int = 0
    ) -> ColorReplacement? {
        guard depth < Self.maxAliasDepth else {
            logger.warning("Variable alias chain exceeded depth limit (variableId: \(variableId))")
            return nil
        }

        guard let variable = variablesMeta.variables[variableId] else {
            logger.debug("Variable '\(variableId)' not found in variables meta during dark resolution")
            return nil
        }
        guard variable.deletedButReferenced != true else {
            logger.debug("Variable '\(variable.name)' (\(variableId)) is deleted but referenced, skipping")
            return nil
        }

        // Try the requested mode first, fall back to default mode of the collection
        let value = variable.valuesByMode[modeId]
            ?? variablesMeta.variableCollections[variable.variableCollectionId]
            .flatMap { collection in
                variable.valuesByMode[collection.defaultModeId]
            }

        switch value {
        case let .color(color):
            return ColorReplacement(
                hex: SVGColorReplacer.normalizeColor(r: color.r, g: color.g, b: color.b),
                alpha: color.a
            )

        case let .variableAlias(alias):
            // Resolve alias — use primitives mode if available, else use the same mode
            let resolvedVariable = variablesMeta.variables[alias.id]
            let resolveModeId: String = if let primId = primitivesModeId {
                primId
            } else if let resolvedVar = resolvedVariable,
                      let collection = variablesMeta.variableCollections[resolvedVar.variableCollectionId]
            {
                collection.defaultModeId
            } else {
                modeId
            }

            return resolveDarkColor(
                variableId: alias.id,
                modeId: resolveModeId,
                variablesMeta: variablesMeta,
                primitivesModeId: primitivesModeId,
                depth: depth + 1
            )

        case .none:
            logger.debug("Variable '\(variable.name)' has no value for mode '\(modeId)'")
            return nil

        default:
            logger.debug("Variable '\(variable.name)' has non-color type, cannot resolve dark color")
            return nil
        }
    }
}

// swiftlint:enable type_body_length
