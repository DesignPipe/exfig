import ExFig_iOS
@testable import ExFigCLI
import ExFigConfig
import ExFigCore
import XCTest

// MARK: - SourceKindBridging Tests

final class SourceKindBridgingTests: XCTestCase {
    func testAllPKLSourceKindCasesBridgeToExFigCore() {
        // Every Common.SourceKind case must map to a DesignSourceKind.
        for pklCase in Common.SourceKind.allCases {
            let core = pklCase.coreSourceKind
            XCTAssertNotNil(
                core,
                "Common.SourceKind.\(pklCase) should bridge to a non-nil DesignSourceKind"
            )
        }
    }

    func testSourceKindBridgingValues() {
        // Explicit mapping verification (PKL kebab → Swift camelCase).
        let expectations: [(Common.SourceKind, DesignSourceKind)] = [
            (.figma, .figma),
            (.penpot, .penpot),
            (.tokensFile, .tokensFile),
            (.tokensStudio, .tokensStudio),
            (.sketchFile, .sketchFile),
        ]
        for (pkl, expected) in expectations {
            XCTAssertEqual(
                pkl.coreSourceKind, expected,
                "Common.SourceKind.\(pkl) should bridge to .\(expected)"
            )
        }
    }

    func testSourceKindCaseCount() {
        XCTAssertEqual(
            Common.SourceKind.allCases.count,
            DesignSourceKind.allCases.count,
            "Common.SourceKind and DesignSourceKind should have the same number of cases"
        )
    }
}

// MARK: - Explicit sourceKind Override Tests

final class ExplicitSourceKindTests: XCTestCase {
    func testExplicitFigmaSourceKindOverridesAutoDetection() throws {
        // When sourceKind is explicitly .figma, it should use Figma even if tokensFile is set.
        let entry = iOS.ColorsEntry(
            useColorAssets: false,
            assetsFolder: nil,
            nameStyle: .camelCase,
            groupUsingNamespace: nil,
            assetsFolderProvidesNamespace: nil,
            colorSwift: nil,
            swiftuiColorSwift: nil,
            xcassetsPath: nil,
            templatesPath: nil,
            syncCodeSyntax: nil,
            codeSyntaxTemplate: nil,
            sourceKind: .figma,
            tokensFile: Common.TokensFile(path: "tokens.json", groupFilter: nil),
            tokensFileId: "file123",
            tokensCollectionName: "Collection",
            lightModeName: "Light",
            darkModeName: nil,
            lightHCModeName: nil,
            darkHCModeName: nil,
            primitivesModeName: nil,
            nameValidateRegexp: nil,
            nameReplaceRegexp: nil
        )
        let sourceInput = try entry.validatedColorsSourceInput()
        XCTAssertEqual(sourceInput.sourceKind, .figma)
        XCTAssert(sourceInput.sourceConfig is FigmaColorsConfig)
    }

    func testExplicitTokensFileSourceKindWorks() throws {
        let entry = iOS.ColorsEntry(
            useColorAssets: false,
            assetsFolder: nil,
            nameStyle: .camelCase,
            groupUsingNamespace: nil,
            assetsFolderProvidesNamespace: nil,
            colorSwift: nil,
            swiftuiColorSwift: nil,
            xcassetsPath: nil,
            templatesPath: nil,
            syncCodeSyntax: nil,
            codeSyntaxTemplate: nil,
            sourceKind: .tokensFile,
            tokensFile: Common.TokensFile(path: "design.json", groupFilter: "Brand"),
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
        let sourceInput = try entry.validatedColorsSourceInput()
        XCTAssertEqual(sourceInput.sourceKind, .tokensFile)
        let config = try XCTUnwrap(sourceInput.sourceConfig as? TokensFileColorsConfig)
        XCTAssertEqual(config.filePath, "design.json")
        XCTAssertEqual(config.groupFilter, "Brand")
    }

    func testExplicitTokensFileWithoutTokensFileThrows() {
        // sourceKind: .tokensFile but no tokensFile block → should throw
        let entry = iOS.ColorsEntry(
            useColorAssets: false,
            assetsFolder: nil,
            nameStyle: .camelCase,
            groupUsingNamespace: nil,
            assetsFolderProvidesNamespace: nil,
            colorSwift: nil,
            swiftuiColorSwift: nil,
            xcassetsPath: nil,
            templatesPath: nil,
            syncCodeSyntax: nil,
            codeSyntaxTemplate: nil,
            sourceKind: .tokensFile,
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
        XCTAssertThrowsError(try entry.validatedColorsSourceInput()) { error in
            XCTAssert(error is ColorsConfigError)
        }
    }
}

// MARK: - IgnoredModeNames Tests

final class IgnoredModeNamesTests: XCTestCase {
    func testTokensFileCollectsIgnoredModeNames() throws {
        let entry = iOS.ColorsEntry(
            useColorAssets: false,
            assetsFolder: nil,
            nameStyle: .camelCase,
            groupUsingNamespace: nil,
            assetsFolderProvidesNamespace: nil,
            colorSwift: nil,
            swiftuiColorSwift: nil,
            xcassetsPath: nil,
            templatesPath: nil,
            syncCodeSyntax: nil,
            codeSyntaxTemplate: nil,
            sourceKind: nil,
            tokensFile: Common.TokensFile(path: "tokens.json", groupFilter: nil),
            tokensFileId: nil,
            tokensCollectionName: nil,
            lightModeName: nil,
            darkModeName: "Dark",
            lightHCModeName: "LightHC",
            darkHCModeName: nil,
            primitivesModeName: nil,
            nameValidateRegexp: nil,
            nameReplaceRegexp: nil
        )
        let sourceInput = try entry.validatedColorsSourceInput()
        let config = try XCTUnwrap(sourceInput.sourceConfig as? TokensFileColorsConfig)
        XCTAssertEqual(config.ignoredModeNames, ["darkModeName", "lightHCModeName"])
    }

    func testTokensFileWithoutDarkModeHasNoIgnoredModes() throws {
        let entry = iOS.ColorsEntry(
            useColorAssets: false,
            assetsFolder: nil,
            nameStyle: .camelCase,
            groupUsingNamespace: nil,
            assetsFolderProvidesNamespace: nil,
            colorSwift: nil,
            swiftuiColorSwift: nil,
            xcassetsPath: nil,
            templatesPath: nil,
            syncCodeSyntax: nil,
            codeSyntaxTemplate: nil,
            sourceKind: nil,
            tokensFile: Common.TokensFile(path: "tokens.json", groupFilter: nil),
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
        let sourceInput = try entry.validatedColorsSourceInput()
        let config = try XCTUnwrap(sourceInput.sourceConfig as? TokensFileColorsConfig)
        XCTAssertTrue(config.ignoredModeNames.isEmpty)
    }

    func testTokensFileCollectsAllThreeIgnoredModeNames() throws {
        let entry = iOS.ColorsEntry(
            useColorAssets: false,
            assetsFolder: nil,
            nameStyle: .camelCase,
            groupUsingNamespace: nil,
            assetsFolderProvidesNamespace: nil,
            colorSwift: nil,
            swiftuiColorSwift: nil,
            xcassetsPath: nil,
            templatesPath: nil,
            syncCodeSyntax: nil,
            codeSyntaxTemplate: nil,
            sourceKind: nil,
            tokensFile: Common.TokensFile(path: "tokens.json", groupFilter: nil),
            tokensFileId: nil,
            tokensCollectionName: nil,
            lightModeName: nil,
            darkModeName: "Dark",
            lightHCModeName: "LightHC",
            darkHCModeName: "DarkHC",
            primitivesModeName: nil,
            nameValidateRegexp: nil,
            nameReplaceRegexp: nil
        )
        let sourceInput = try entry.validatedColorsSourceInput()
        let config = try XCTUnwrap(sourceInput.sourceConfig as? TokensFileColorsConfig)
        XCTAssertEqual(config.ignoredModeNames, ["darkModeName", "lightHCModeName", "darkHCModeName"])
    }
}

// MARK: - SpinnerLabel Tests

final class SpinnerLabelTests: XCTestCase {
    func testFigmaSpinnerLabelIncludesCollectionName() {
        let input = ColorsSourceInput(
            sourceKind: .figma,
            sourceConfig: FigmaColorsConfig(
                tokensFileId: "file123",
                tokensCollectionName: "Brand Colors",
                lightModeName: "Light"
            )
        )
        XCTAssertEqual(input.spinnerLabel, "Figma Variables (Brand Colors)")
    }

    func testTokensFileSpinnerLabelShowsFileName() {
        let input = ColorsSourceInput(
            sourceKind: .tokensFile,
            sourceConfig: TokensFileColorsConfig(filePath: "/path/to/design-tokens.json")
        )
        XCTAssertEqual(input.spinnerLabel, "design-tokens.json")
    }

    func testUnsupportedSourceKindSpinnerLabelShowsRawValue() {
        let input = ColorsSourceInput(
            sourceKind: .penpot,
            sourceConfig: FigmaColorsConfig(
                tokensFileId: "", tokensCollectionName: "", lightModeName: ""
            )
        )
        XCTAssertEqual(input.spinnerLabel, "penpot")
    }
}

// MARK: - ExFigError.unsupportedSourceKind Tests

final class UnsupportedSourceKindErrorTests: XCTestCase {
    func testErrorDescriptionIncludesAssetType() {
        let error = ExFigError.unsupportedSourceKind(.penpot, assetType: "colors")
        XCTAssertTrue(error.errorDescription?.contains("colors") == true)
        XCTAssertTrue(error.errorDescription?.contains("penpot") == true)
    }

    func testRecoverySuggestionForColorsListsTokensFile() {
        let error = ExFigError.unsupportedSourceKind(.penpot, assetType: "colors")
        XCTAssertTrue(error.recoverySuggestion?.contains("tokensFile") == true)
    }

    func testRecoverySuggestionForIconsDoesNotListTokensFile() {
        let error = ExFigError.unsupportedSourceKind(.penpot, assetType: "icons/images")
        XCTAssertFalse(error.recoverySuggestion?.contains("tokensFile") == true)
    }

    func testRecoverySuggestionForTypographyDoesNotListTokensFile() {
        let error = ExFigError.unsupportedSourceKind(.penpot, assetType: "typography")
        XCTAssertFalse(error.recoverySuggestion?.contains("tokensFile") == true)
    }
}
