import ExFigConfig
import ExFigCore
import Testing

@Suite("VariablesSource resolvedSourceKind")
struct VariablesSourceResolvedSourceKindTests {
    @Test("Defaults to figma when no overrides")
    func defaultsFigma() {
        let source = Common.VariablesSourceImpl(
            sourceKind: nil,
            penpotSource: nil,
            tokensFile: nil,
            tokensFileId: "file-id",
            tokensCollectionName: "Collection",
            lightModeName: "Light",
            darkModeName: nil,
            lightHCModeName: nil,
            darkHCModeName: nil,
            primitivesModeName: nil,
            nameValidateRegexp: nil,
            nameReplaceRegexp: nil
        )
        #expect(source.resolvedSourceKind == .figma)
    }

    @Test("Auto-detects penpot from penpotSource")
    func autoDetectsPenpot() {
        let source = Common.VariablesSourceImpl(
            sourceKind: nil,
            penpotSource: Common.PenpotSource(fileId: "uuid", baseUrl: "https://design.penpot.app/", pathFilter: nil),
            tokensFile: nil,
            tokensFileId: nil,
            tokensCollectionName: nil,
            lightModeName: nil,
            darkModeName: nil,
            lightHCModeName: nil,
            darkHCModeName: nil,
            primitivesModeName: nil,
            nameValidateRegexp: nil,
            nameReplaceRegexp: nil
        )
        #expect(source.resolvedSourceKind == .penpot)
    }

    @Test("Auto-detects tokensFile when set")
    func autoDetectsTokensFile() {
        let source = Common.VariablesSourceImpl(
            sourceKind: nil,
            penpotSource: nil,
            tokensFile: Common.TokensFile(path: "./tokens.json", groupFilter: nil),
            tokensFileId: nil,
            tokensCollectionName: nil,
            lightModeName: nil,
            darkModeName: nil,
            lightHCModeName: nil,
            darkHCModeName: nil,
            primitivesModeName: nil,
            nameValidateRegexp: nil,
            nameReplaceRegexp: nil
        )
        #expect(source.resolvedSourceKind == .tokensFile)
    }

    @Test("Penpot takes priority over tokensFile in auto-detection")
    func penpotPriorityOverTokensFile() {
        let source = Common.VariablesSourceImpl(
            sourceKind: nil,
            penpotSource: Common.PenpotSource(fileId: "uuid", baseUrl: "https://design.penpot.app/", pathFilter: nil),
            tokensFile: Common.TokensFile(path: "./tokens.json", groupFilter: nil),
            tokensFileId: nil,
            tokensCollectionName: nil,
            lightModeName: nil,
            darkModeName: nil,
            lightHCModeName: nil,
            darkHCModeName: nil,
            primitivesModeName: nil,
            nameValidateRegexp: nil,
            nameReplaceRegexp: nil
        )
        #expect(source.resolvedSourceKind == .penpot)
    }

    @Test("Explicit sourceKind overrides auto-detection")
    func explicitOverridesAutoDetect() {
        let source = Common.VariablesSourceImpl(
            sourceKind: Common.SourceKind.figma,
            penpotSource: Common.PenpotSource(fileId: "uuid", baseUrl: "https://design.penpot.app/", pathFilter: nil),
            tokensFile: nil,
            tokensFileId: nil,
            tokensCollectionName: nil,
            lightModeName: nil,
            darkModeName: nil,
            lightHCModeName: nil,
            darkHCModeName: nil,
            primitivesModeName: nil,
            nameValidateRegexp: nil,
            nameReplaceRegexp: nil
        )
        #expect(source.resolvedSourceKind == .figma)
    }
}
