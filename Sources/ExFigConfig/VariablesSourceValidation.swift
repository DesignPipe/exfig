import ExFigCore

public extension Common_VariablesSource {
    /// Returns a validated `ColorsSourceInput` for use with `ColorsExportContext`.
    ///
    /// When `tokensFile` is set, bypasses Figma API validation and returns a local-file source.
    /// Otherwise, throws if required Figma fields (`tokensFileId`, `tokensCollectionName`,
    /// `lightModeName`) are nil or empty.
    /// Resolves the design source kind with priority: explicit > auto-detect > default (.figma).
    var resolvedSourceKind: DesignSourceKind {
        if let explicit = sourceKind {
            return explicit.coreSourceKind
        }
        if tokensFile != nil {
            return .tokensFile
        }
        return .figma
    }

    func validatedColorsSourceInput() throws -> ColorsSourceInput {
        let kind = resolvedSourceKind

        if kind == .tokensFile {
            guard let tokensFile else {
                throw ColorsConfigError.missingTokensFileId
            }
            let config = TokensFileColorsConfig(
                filePath: tokensFile.path,
                groupFilter: tokensFile.groupFilter
            )
            return ColorsSourceInput(
                sourceKind: .tokensFile,
                sourceConfig: config,
                nameValidateRegexp: nameValidateRegexp,
                nameReplaceRegexp: nameReplaceRegexp
            )
        }

        // Figma Variables source — require all fields
        guard let tokensFileId, !tokensFileId.isEmpty else {
            throw ColorsConfigError.missingTokensFileId
        }
        guard let tokensCollectionName, !tokensCollectionName.isEmpty else {
            throw ColorsConfigError.missingTokensCollectionName
        }
        guard let lightModeName, !lightModeName.isEmpty else {
            throw ColorsConfigError.missingLightModeName
        }
        let config = FigmaColorsConfig(
            tokensFileId: tokensFileId,
            tokensCollectionName: tokensCollectionName,
            lightModeName: lightModeName,
            darkModeName: darkModeName,
            lightHCModeName: lightHCModeName,
            darkHCModeName: darkHCModeName,
            primitivesModeName: primitivesModeName
        )
        return ColorsSourceInput(
            sourceKind: kind,
            sourceConfig: config,
            nameValidateRegexp: nameValidateRegexp,
            nameReplaceRegexp: nameReplaceRegexp
        )
    }
}
