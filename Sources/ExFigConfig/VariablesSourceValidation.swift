import ExFigCore

public extension Common_VariablesSource {
    /// Resolves the design source kind with priority: explicit > auto-detect > default (.figma).
    var resolvedSourceKind: DesignSourceKind {
        if let explicit = sourceKind {
            return explicit.coreSourceKind
        }
        if penpotSource != nil {
            return .penpot
        }
        if tokensFile != nil {
            return .tokensFile
        }
        return .figma
    }

    /// Returns a validated `ColorsSourceInput` for use with `ColorsExportContext`.
    ///
    /// Dispatches by `resolvedSourceKind`: Penpot, tokens-file, or Figma Variables.
    func validatedColorsSourceInput() throws -> ColorsSourceInput {
        let kind = resolvedSourceKind

        switch kind {
        case .penpot:
            return try penpotColorsSourceInput()
        case .tokensFile:
            return try tokensFileColorsSourceInput()
        case .figma:
            return try figmaColorsSourceInput(kind: kind)
        case .tokensStudio, .sketchFile:
            throw ColorsConfigError.unsupportedSourceKind(kind)
        }
    }
}

// MARK: - Private Helpers

private extension Common_VariablesSource {
    func penpotColorsSourceInput() throws -> ColorsSourceInput {
        guard let penpotSource else {
            throw ColorsConfigError.missingPenpotSource
        }
        let config = PenpotColorsConfig(
            fileId: penpotSource.fileId,
            baseURL: penpotSource.baseUrl,
            pathFilter: penpotSource.pathFilter
        )
        return ColorsSourceInput(
            sourceKind: .penpot,
            sourceConfig: config,
            nameValidateRegexp: nameValidateRegexp,
            nameReplaceRegexp: nameReplaceRegexp
        )
    }

    func tokensFileColorsSourceInput() throws -> ColorsSourceInput {
        guard let tokensFile else {
            throw ColorsConfigError.missingTokensFileId
        }
        var ignoredModes: [String] = []
        if darkModeName != nil { ignoredModes.append("darkModeName") }
        if lightHCModeName != nil { ignoredModes.append("lightHCModeName") }
        if darkHCModeName != nil { ignoredModes.append("darkHCModeName") }

        let config = TokensFileColorsConfig(
            filePath: tokensFile.path,
            groupFilter: tokensFile.groupFilter,
            ignoredModeNames: ignoredModes
        )
        return ColorsSourceInput(
            sourceKind: .tokensFile,
            sourceConfig: config,
            nameValidateRegexp: nameValidateRegexp,
            nameReplaceRegexp: nameReplaceRegexp
        )
    }

    func figmaColorsSourceInput(kind: DesignSourceKind) throws -> ColorsSourceInput {
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
