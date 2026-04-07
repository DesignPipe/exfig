import ExFig_iOS
@testable import ExFigCLI
import ExFigConfig
import ExFigCore
import XCTest

// MARK: - FrameSource resolvedSourceKind Tests

final class FrameSourceResolvedSourceKindTests: XCTestCase {
    func testDefaultsToFigmaWhenNoPenpotSource() {
        let entry = iOS.IconsEntry(
            format: .svg,
            assetsFolder: "Icons",
            preservesVectorRepresentation: nil,
            nameStyle: .camelCase,
            imageSwift: nil,
            swiftUIImageSwift: nil,
            codeConnectSwift: nil,
            xcassetsPath: nil,
            templatesPath: nil,
            renderMode: nil,
            renderModeDefaultSuffix: nil,
            renderModeOriginalSuffix: nil,
            renderModeTemplateSuffix: nil,
            sourceKind: nil,
            penpotSource: nil,
            figmaFrameName: nil,
            figmaPageName: nil,
            figmaFileId: "figma-file-id",
            rtlProperty: nil,
            rtlActiveValues: nil,
            variablesDarkMode: nil,
            nameValidateRegexp: nil,
            nameReplaceRegexp: nil
        )
        XCTAssertEqual(entry.resolvedSourceKind, .figma)
    }

    func testAutoDetectsPenpotFromPenpotSource() {
        let entry = iOS.IconsEntry(
            format: .svg,
            assetsFolder: "Icons",
            preservesVectorRepresentation: nil,
            nameStyle: .camelCase,
            imageSwift: nil,
            swiftUIImageSwift: nil,
            codeConnectSwift: nil,
            xcassetsPath: nil,
            templatesPath: nil,
            renderMode: nil,
            renderModeDefaultSuffix: nil,
            renderModeOriginalSuffix: nil,
            renderModeTemplateSuffix: nil,
            sourceKind: nil,
            penpotSource: Common.PenpotSource(
                fileId: "penpot-uuid", baseUrl: "https://penpot.example.com/", pathFilter: nil
            ),
            figmaFrameName: nil,
            figmaPageName: nil,
            figmaFileId: nil,
            rtlProperty: nil,
            rtlActiveValues: nil,
            variablesDarkMode: nil,
            nameValidateRegexp: nil,
            nameReplaceRegexp: nil
        )
        XCTAssertEqual(entry.resolvedSourceKind, .penpot)
    }

    func testExplicitSourceKindOverridesPenpotAutoDetect() {
        let entry = iOS.IconsEntry(
            format: .svg,
            assetsFolder: "Icons",
            preservesVectorRepresentation: nil,
            nameStyle: .camelCase,
            imageSwift: nil,
            swiftUIImageSwift: nil,
            codeConnectSwift: nil,
            xcassetsPath: nil,
            templatesPath: nil,
            renderMode: nil,
            renderModeDefaultSuffix: nil,
            renderModeOriginalSuffix: nil,
            renderModeTemplateSuffix: nil,
            sourceKind: .figma,
            penpotSource: Common.PenpotSource(
                fileId: "penpot-uuid", baseUrl: "https://penpot.example.com/", pathFilter: nil
            ),
            figmaFrameName: nil,
            figmaPageName: nil,
            figmaFileId: "figma-file-id",
            rtlProperty: nil,
            rtlActiveValues: nil,
            variablesDarkMode: nil,
            nameValidateRegexp: nil,
            nameReplaceRegexp: nil
        )
        XCTAssertEqual(entry.resolvedSourceKind, .figma)
    }

    func testResolvedFileIdPrefersPenpotSource() {
        let entry = iOS.IconsEntry(
            format: .svg,
            assetsFolder: "Icons",
            preservesVectorRepresentation: nil,
            nameStyle: .camelCase,
            imageSwift: nil,
            swiftUIImageSwift: nil,
            codeConnectSwift: nil,
            xcassetsPath: nil,
            templatesPath: nil,
            renderMode: nil,
            renderModeDefaultSuffix: nil,
            renderModeOriginalSuffix: nil,
            renderModeTemplateSuffix: nil,
            sourceKind: nil,
            penpotSource: Common.PenpotSource(
                fileId: "penpot-uuid", baseUrl: "https://penpot.example.com/", pathFilter: nil
            ),
            figmaFrameName: nil,
            figmaPageName: nil,
            figmaFileId: "figma-file-id",
            rtlProperty: nil,
            rtlActiveValues: nil,
            variablesDarkMode: nil,
            nameValidateRegexp: nil,
            nameReplaceRegexp: nil
        )
        XCTAssertEqual(entry.resolvedFileId, "penpot-uuid")
    }

    func testResolvedFileIdFallsBackToFigmaFileId() {
        let entry = iOS.IconsEntry(
            format: .svg,
            assetsFolder: "Icons",
            preservesVectorRepresentation: nil,
            nameStyle: .camelCase,
            imageSwift: nil,
            swiftUIImageSwift: nil,
            codeConnectSwift: nil,
            xcassetsPath: nil,
            templatesPath: nil,
            renderMode: nil,
            renderModeDefaultSuffix: nil,
            renderModeOriginalSuffix: nil,
            renderModeTemplateSuffix: nil,
            sourceKind: nil,
            penpotSource: nil,
            figmaFrameName: nil,
            figmaPageName: nil,
            figmaFileId: "figma-file-id",
            rtlProperty: nil,
            rtlActiveValues: nil,
            variablesDarkMode: nil,
            nameValidateRegexp: nil,
            nameReplaceRegexp: nil
        )
        XCTAssertEqual(entry.resolvedFileId, "figma-file-id")
    }

    func testResolvedPenpotBaseURLFromPenpotSource() {
        let entry = iOS.IconsEntry(
            format: .svg,
            assetsFolder: "Icons",
            preservesVectorRepresentation: nil,
            nameStyle: .camelCase,
            imageSwift: nil,
            swiftUIImageSwift: nil,
            codeConnectSwift: nil,
            xcassetsPath: nil,
            templatesPath: nil,
            renderMode: nil,
            renderModeDefaultSuffix: nil,
            renderModeOriginalSuffix: nil,
            renderModeTemplateSuffix: nil,
            sourceKind: nil,
            penpotSource: Common.PenpotSource(
                fileId: "uuid", baseUrl: "https://my-penpot.example.com/", pathFilter: nil
            ),
            figmaFrameName: nil,
            figmaPageName: nil,
            figmaFileId: nil,
            rtlProperty: nil,
            rtlActiveValues: nil,
            variablesDarkMode: nil,
            nameValidateRegexp: nil,
            nameReplaceRegexp: nil
        )
        XCTAssertEqual(entry.resolvedPenpotBaseURL, "https://my-penpot.example.com/")
    }

    func testResolvedPenpotBaseURLNilWithoutPenpotSource() {
        let entry = iOS.IconsEntry(
            format: .svg,
            assetsFolder: "Icons",
            preservesVectorRepresentation: nil,
            nameStyle: .camelCase,
            imageSwift: nil,
            swiftUIImageSwift: nil,
            codeConnectSwift: nil,
            xcassetsPath: nil,
            templatesPath: nil,
            renderMode: nil,
            renderModeDefaultSuffix: nil,
            renderModeOriginalSuffix: nil,
            renderModeTemplateSuffix: nil,
            sourceKind: nil,
            penpotSource: nil,
            figmaFrameName: nil,
            figmaPageName: nil,
            figmaFileId: nil,
            rtlProperty: nil,
            rtlActiveValues: nil,
            variablesDarkMode: nil,
            nameValidateRegexp: nil,
            nameReplaceRegexp: nil
        )
        XCTAssertNil(entry.resolvedPenpotBaseURL)
    }
}

// MARK: - Penpot ColorsSourceInput Validation Tests

final class PenpotColorsSourceInputTests: XCTestCase {
    func testAutoDetectedPenpotProducesPenpotConfig() throws {
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
            penpotSource: Common.PenpotSource(
                fileId: "penpot-uuid-123", baseUrl: "https://my-penpot.com/", pathFilter: "Brand"
            ),
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
        let sourceInput = try entry.validatedColorsSourceInput()
        XCTAssertEqual(sourceInput.sourceKind, .penpot)
        let config = try XCTUnwrap(sourceInput.sourceConfig as? PenpotColorsConfig)
        XCTAssertEqual(config.fileId, "penpot-uuid-123")
        XCTAssertEqual(config.baseURL, "https://my-penpot.com/")
        XCTAssertEqual(config.pathFilter, "Brand")
    }

    func testExplicitPenpotWithoutPenpotSourceThrowsMissingPenpotSource() {
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
            sourceKind: .penpot,
            penpotSource: nil,
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
            guard let configError = error as? ColorsConfigError else {
                XCTFail("Expected ColorsConfigError, got \(error)")
                return
            }
            XCTAssertEqual(configError, .missingPenpotSource)
        }
    }
}
