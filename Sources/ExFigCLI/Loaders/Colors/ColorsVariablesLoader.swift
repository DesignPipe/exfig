import ExFigCore
import FigmaAPI

/// Loads color variables from Figma
final class ColorsVariablesLoader: Sendable {
    private let client: Client
    private let variableParams: PKLConfig.Common.VariablesColors?
    private let filter: String?

    init(
        client: Client,
        variableParams: PKLConfig.Common.VariablesColors?,
        filter: String?
    ) {
        self.client = client
        self.variableParams = variableParams
        self.filter = filter
    }

    /// Per-color-per-mode alias paths: colorName → mode key → referenced variable name.
    /// Mode keys: "light", "dark", "lightHC", "darkHC".
    typealias ColorAliases = [String: [String: String]]

    struct LoadResult {
        let output: ColorsLoaderOutput
        let warnings: [ExFigWarning]
        let aliases: ColorAliases
        let descriptions: [String: String]
        let metadata: [String: ColorTokenMetadata]
    }

    func load() async throws -> LoadResult {
        guard
            let tokensFileId = variableParams?.tokensFileId,
            let tokensCollectionName = variableParams?.tokensCollectionName
        else { throw ExFigError.custom(errorString: "tokensFileId is nil") }

        let meta = try await loadVariables(fileId: tokensFileId)

        var warnings: [ExFigWarning] = []
        let collection = try selectCollection(named: tokensCollectionName, from: meta, warnings: &warnings)
        let modeIds = extractModeIds(from: collection)

        var descriptions: [String: String] = [:]
        var tokenMetadata: [String: ColorTokenMetadata] = [:]

        let variables: [Variable] = collection.variableIds.compactMap { tokenId in
            guard let variableMeta = meta.variables[tokenId] else { return nil }
            guard variableMeta.deletedButReferenced != true else { return nil }

            // Collect description and metadata
            let desc = variableMeta.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if !desc.isEmpty {
                descriptions[variableMeta.name] = desc
            }
            tokenMetadata[variableMeta.name] = ColorTokenMetadata(
                variableId: variableMeta.id,
                fileId: tokensFileId
            )

            return mapVariableMetaToVariable(variableMeta: variableMeta, modeIds: modeIds)
        }

        var aliases: ColorAliases = [:]
        let output = mapVariablesToColorOutput(
            variables: variables,
            meta: meta,
            warnings: &warnings,
            aliases: &aliases
        )

        return LoadResult(
            output: output,
            warnings: warnings,
            aliases: aliases,
            descriptions: descriptions,
            metadata: tokenMetadata
        )
    }

    private func loadVariables(fileId: String) async throws -> VariablesEndpoint.Content {
        let endpoint = VariablesEndpoint(fileId: fileId)
        return try await client.request(endpoint)
    }

    /// Picks the variable collection matching `name`.
    ///
    /// A Figma file can expose several collections with the same name (stale or remote
    /// duplicates the editor UI hides). `Dictionary.first(where:)` would pick one at random —
    /// non-deterministic across runs, which silently dropped colors. We deterministically pick
    /// the collection with the most *usable* variables (matching what the designer sees in the
    /// UI) and warn about the duplicates.
    ///
    /// "Usable" means the same subset that `load()` actually exports — present in `meta.variables`
    /// and not `deletedButReferenced`. Ranking by raw `variableIds.count` would let a stale
    /// collection padded with deleted/dangling ids win over the real one; it also keeps the
    /// warning's counts consistent with the number of colors the user actually gets.
    private func selectCollection(
        named name: String,
        from meta: VariablesEndpoint.Content,
        warnings: inout [ExFigWarning]
    ) throws -> Dictionary<String, VariableCollectionValue>.Values.Element {
        let candidates = meta.variableCollections.values
            .filter { $0.name == name }
            // Stable order: most usable variables first; ties broken by id so it never depends
            // on dictionary iteration order.
            .sorted { lhs, rhs in
                let lhsCount = usableVariableCount(of: lhs, in: meta)
                let rhsCount = usableVariableCount(of: rhs, in: meta)
                if lhsCount != rhsCount {
                    return lhsCount > rhsCount
                }
                return lhs.id < rhs.id
            }

        guard let selected = candidates.first else {
            throw ExFigError.custom(errorString: "tokensCollectionName not found")
        }

        if candidates.count > 1 {
            warnings.append(.duplicateColorCollection(
                name: name,
                selectedCount: usableVariableCount(of: selected, in: meta),
                otherCounts: candidates.dropFirst().map { usableVariableCount(of: $0, in: meta) }
            ))
        }

        return selected
    }

    /// Counts the variables in `collection` that `load()` would actually export:
    /// present in `meta.variables` and not deleted-but-referenced.
    private func usableVariableCount(
        of collection: VariableCollectionValue,
        in meta: VariablesEndpoint.Content
    ) -> Int {
        collection.variableIds.count(where: { id in
            guard let variable = meta.variables[id] else { return false }
            return variable.deletedButReferenced != true
        })
    }

    private func extractModeIds(
        from collections: Dictionary<String, VariableCollectionValue>.Values.Element
    ) -> ModeIds {
        var modeIds = ModeIds()
        for mode in collections.modes {
            switch mode.name {
            case variableParams?.lightModeName:
                modeIds.lightModeId = mode.modeId
            case variableParams?.darkModeName:
                modeIds.darkModeId = mode.modeId
            case variableParams?.lightHCModeName:
                modeIds.lightHCModeId = mode.modeId
            case variableParams?.darkHCModeName:
                modeIds.darkHCModeId = mode.modeId
            default:
                modeIds.lightModeId = mode.modeId
            }
        }
        return modeIds
    }

    private func mapVariableMetaToVariable(variableMeta: VariableValue, modeIds: ModeIds) -> Variable {
        let values = Values(
            light: variableMeta.valuesByMode[modeIds.lightModeId],
            dark: variableMeta.valuesByMode[modeIds.darkModeId],
            lightHC: variableMeta.valuesByMode[modeIds.lightHCModeId],
            darkHC: variableMeta.valuesByMode[modeIds.darkHCModeId]
        )

        return Variable(name: variableMeta.name, description: variableMeta.description, valuesByMode: values)
    }

    // swiftlint:disable function_parameter_count

    private func mapVariablesToColorOutput(
        variables: [Variable],
        meta: VariablesEndpoint.Content,
        warnings: inout [ExFigWarning],
        aliases: inout ColorAliases
    ) -> ColorsLoaderOutput {
        var colorOutput = Colors()
        for variable in variables {
            handleColorMode(
                variable: variable,
                mode: variable.valuesByMode.light,
                colorsArray: &colorOutput.lightColors,
                modeKey: "light",
                filter: filter,
                meta: meta,
                warnings: &warnings,
                aliases: &aliases
            )
            handleColorMode(
                variable: variable,
                mode: variable.valuesByMode.dark,
                colorsArray: &colorOutput.darkColors,
                modeKey: "dark",
                filter: filter,
                meta: meta,
                warnings: &warnings,
                aliases: &aliases
            )
            handleColorMode(
                variable: variable,
                mode: variable.valuesByMode.lightHC,
                colorsArray: &colorOutput.lightHCColors,
                modeKey: "lightHC",
                filter: filter,
                meta: meta,
                warnings: &warnings,
                aliases: &aliases
            )
            handleColorMode(
                variable: variable,
                mode: variable.valuesByMode.darkHC,
                colorsArray: &colorOutput.darkHCColors,
                modeKey: "darkHC",
                filter: filter,
                meta: meta,
                warnings: &warnings,
                aliases: &aliases
            )
        }
        return (colorOutput.lightColors, colorOutput.darkColors, colorOutput.lightHCColors, colorOutput.darkHCColors)
    }

    private func handleColorMode(
        variable: Variable,
        mode: ValuesByMode?,
        colorsArray: inout [Color],
        modeKey: String,
        filter: String?,
        meta: VariablesEndpoint.Content,
        warnings: inout [ExFigWarning],
        aliases: inout ColorAliases,
        depth: Int = 0
    ) {
        guard depth < 10 else {
            warnings.append(.circularColorAlias(tokenName: variable.name))
            return
        }

        if case let .color(color) = mode, doesColorMatchFilter(from: variable) {
            colorsArray.append(createColor(from: variable, color: color))
        } else if case let .variableAlias(variableAlias) = mode,
                  let variableMeta = meta.variables[variableAlias.id],
                  let variableCollectionId = meta.variableCollections[variableMeta.variableCollectionId]
        {
            if variableMeta.deletedButReferenced == true {
                warnings.append(.deletedVariableAlias(
                    tokenName: variable.name,
                    referencedName: variableMeta.name
                ))
                return
            }

            // Record the alias path (referenced variable name)
            aliases[variable.name, default: [:]][modeKey] = variableMeta.name

            let modeId = variableCollectionId.modes.first(where: {
                $0.name == variableParams?.primitivesModeName
            })?.modeId ?? variableCollectionId.defaultModeId
            handleColorMode(
                variable: variable,
                mode: variableMeta.valuesByMode[modeId],
                colorsArray: &colorsArray,
                modeKey: modeKey,
                filter: filter,
                meta: meta,
                warnings: &warnings,
                aliases: &aliases,
                depth: depth + 1
            )
        }
    }

    // swiftlint:enable function_parameter_count

    private func doesColorMatchFilter(from variable: Variable) -> Bool {
        guard let filter else { return true }
        let assetsFilter = AssetsFilter(filter: filter)
        return assetsFilter.match(name: variable.name)
    }

    private func createColor(from variable: Variable, color: PaintColor) -> Color {
        Color(
            name: variable.name,
            platform: Platform(rawValue: variable.description),
            red: color.r,
            green: color.g,
            blue: color.b,
            alpha: color.a
        )
    }
}

private extension ColorsVariablesLoader {
    struct ModeIds {
        var lightModeId = String()
        var darkModeId = String()
        var lightHCModeId = String()
        var darkHCModeId = String()
    }

    struct Colors {
        var lightColors: [Color] = []
        var darkColors: [Color] = []
        var lightHCColors: [Color] = []
        var darkHCColors: [Color] = []
    }

    struct Values {
        let light: ValuesByMode?
        let dark: ValuesByMode?
        let lightHC: ValuesByMode?
        let darkHC: ValuesByMode?
    }

    struct Variable {
        let name: String
        let description: String
        let valuesByMode: Values
    }
}
