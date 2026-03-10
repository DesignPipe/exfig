// swiftlint:disable file_length type_body_length

import ExFig_Android
import ExFig_Flutter
import ExFig_iOS
import ExFig_Web
import ExFigConfig
import ExFigCore
import XCTest

final class EnumBridgingTests: XCTestCase {
    // MARK: - NameStyle Bridging

    func testAllPKLNameStyleCasesBridgeToExFigCore() {
        // Every Common.NameStyle case must map to a non-nil ExFigCore.NameStyle.
        // This ensures no cases are silently dropped during bridging.
        for pklCase in Common.NameStyle.allCases {
            XCTAssertNotNil(
                NameStyle(rawValue: pklCase.rawValue),
                "Common.NameStyle.\(pklCase) has no ExFigCore.NameStyle mapping (rawValue: \(pklCase.rawValue))"
            )
        }
    }

    func testAllExFigCoreNameStyleCasesHavePKLEquivalent() {
        // Every ExFigCore.NameStyle case must have a matching Common.NameStyle.
        for coreCase in NameStyle.allCases {
            XCTAssertNotNil(
                Common.NameStyle(rawValue: coreCase.rawValue),
                "ExFigCore.NameStyle.\(coreCase) has no Common.NameStyle mapping (rawValue: \(coreCase.rawValue))"
            )
        }
    }

    func testNameStyleCaseCount() {
        // Both enums must have the same number of cases.
        XCTAssertEqual(
            Common.NameStyle.allCases.count,
            NameStyle.allCases.count,
            "Common.NameStyle and ExFigCore.NameStyle have different case counts"
        )
    }

    // MARK: - iOS coreNameStyle Switch Exhaustiveness

    func testiOSColorsEntryCoreNameStyleMapsAllCases() {
        // Verify the switch-based bridging in iOSColorsEntry covers all cases correctly.
        let expectations: [(Common.NameStyle, NameStyle)] = [
            (.camelCase, .camelCase),
            (.snake_case, .snakeCase),
            (.pascalCase, .pascalCase),
            (.flatCase, .flatCase),
            (.kebabCase, .kebabCase),
            (.sCREAMING_SNAKE_CASE, .screamingSnakeCase),
        ]

        for (pklStyle, expectedCore) in expectations {
            let entry = iOS.ColorsEntry(
                useColorAssets: false,
                assetsFolder: nil,
                nameStyle: pklStyle,
                groupUsingNamespace: nil,
                assetsFolderProvidesNamespace: nil,
                colorSwift: nil,
                swiftuiColorSwift: nil,
                xcassetsPath: nil,
                templatesPath: nil,
                syncCodeSyntax: nil,
                codeSyntaxTemplate: nil,
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
            XCTAssertEqual(
                entry.coreNameStyle, expectedCore,
                "iOS.ColorsEntry with nameStyle=\(pklStyle) should bridge to \(expectedCore)"
            )
        }
    }

    // MARK: - iOS IconsEntry coreNameStyle

    func testiOSIconsEntryCoreNameStyleMapsAllCases() {
        let expectations: [(Common.NameStyle, NameStyle)] = [
            (.camelCase, .camelCase),
            (.snake_case, .snakeCase),
            (.pascalCase, .pascalCase),
            (.flatCase, .flatCase),
            (.kebabCase, .kebabCase),
            (.sCREAMING_SNAKE_CASE, .screamingSnakeCase),
        ]

        for (pklStyle, expectedCore) in expectations {
            let entry = iOS.IconsEntry(
                format: .svg,
                assetsFolder: "Icons",
                preservesVectorRepresentation: nil,
                nameStyle: pklStyle,
                imageSwift: nil,
                swiftUIImageSwift: nil,
                codeConnectSwift: nil,
                xcassetsPath: nil,
                templatesPath: nil,
                renderMode: nil,
                renderModeDefaultSuffix: nil,
                renderModeOriginalSuffix: nil,
                renderModeTemplateSuffix: nil,
                figmaFrameName: nil,
                figmaPageName: nil,
                figmaFileId: nil,
                rtlProperty: nil,
                nameValidateRegexp: nil,
                nameReplaceRegexp: nil
            )
            XCTAssertEqual(
                entry.coreNameStyle, expectedCore,
                "iOS.IconsEntry with nameStyle=\(pklStyle) should bridge to \(expectedCore)"
            )
        }
    }

    // MARK: - iOS ImagesEntry coreNameStyle

    func testiOSImagesEntryCoreNameStyleMapsAllCases() {
        let expectations: [(Common.NameStyle, NameStyle)] = [
            (.camelCase, .camelCase),
            (.snake_case, .snakeCase),
            (.pascalCase, .pascalCase),
            (.flatCase, .flatCase),
            (.kebabCase, .kebabCase),
            (.sCREAMING_SNAKE_CASE, .screamingSnakeCase),
        ]

        for (pklStyle, expectedCore) in expectations {
            let entry = iOS.ImagesEntry(
                assetsFolder: "Images",
                nameStyle: pklStyle,
                scales: nil,
                imageSwift: nil,
                swiftUIImageSwift: nil,
                codeConnectSwift: nil,
                sourceFormat: nil,
                outputFormat: nil,
                heicOptions: nil,
                xcassetsPath: nil,
                templatesPath: nil,
                renderMode: nil,
                renderModeDefaultSuffix: nil,
                renderModeOriginalSuffix: nil,
                renderModeTemplateSuffix: nil,
                figmaFrameName: nil,
                figmaPageName: nil,
                figmaFileId: nil,
                rtlProperty: nil,
                nameValidateRegexp: nil,
                nameReplaceRegexp: nil
            )
            XCTAssertEqual(
                entry.coreNameStyle, expectedCore,
                "iOS.ImagesEntry with nameStyle=\(pklStyle) should bridge to \(expectedCore)"
            )
        }
    }

    // MARK: - Android IconsEntry effectiveNameStyle

    func testAndroidIconsEntryEffectiveNameStyleMapsAllCases() {
        let expectations: [(Common.NameStyle, NameStyle)] = [
            (.camelCase, .camelCase),
            (.snake_case, .snakeCase),
            (.pascalCase, .pascalCase),
            (.flatCase, .flatCase),
            (.kebabCase, .kebabCase),
            (.sCREAMING_SNAKE_CASE, .screamingSnakeCase),
        ]

        for (pklStyle, expectedCore) in expectations {
            let entry = Android.IconsEntry(
                mainRes: nil,
                templatesPath: nil,
                output: "icons",
                composePackageName: nil,
                composeFormat: nil,
                composeExtensionTarget: nil,
                nameStyle: pklStyle,
                pathPrecision: nil,
                strictPathValidation: nil,
                codeConnectPackageName: nil,
                codeConnectKotlin: nil,
                figmaFrameName: nil,
                figmaPageName: nil,
                figmaFileId: nil,
                rtlProperty: nil,
                nameValidateRegexp: nil,
                nameReplaceRegexp: nil
            )
            XCTAssertEqual(
                entry.effectiveNameStyle, expectedCore,
                "Android.IconsEntry with nameStyle=\(pklStyle) should bridge to \(expectedCore)"
            )
        }
    }

    func testAndroidIconsEntryEffectiveNameStyleDefaultsToSnakeCase() {
        let entry = Android.IconsEntry(
            mainRes: nil,
            templatesPath: nil,
            output: "icons",
            composePackageName: nil,
            composeFormat: nil,
            composeExtensionTarget: nil,
            nameStyle: nil,
            pathPrecision: nil,
            strictPathValidation: nil,
            codeConnectPackageName: nil,
            codeConnectKotlin: nil,
            figmaFrameName: nil,
            figmaPageName: nil,
            figmaFileId: nil,
            rtlProperty: nil,
            nameValidateRegexp: nil,
            nameReplaceRegexp: nil
        )
        XCTAssertEqual(entry.effectiveNameStyle, .snakeCase)
    }

    // MARK: - Android ImagesEntry effectiveNameStyle

    func testAndroidImagesEntryEffectiveNameStyleMapsAllCases() {
        let expectations: [(Common.NameStyle, NameStyle)] = [
            (.camelCase, .camelCase),
            (.snake_case, .snakeCase),
            (.pascalCase, .pascalCase),
            (.flatCase, .flatCase),
            (.kebabCase, .kebabCase),
            (.sCREAMING_SNAKE_CASE, .screamingSnakeCase),
        ]

        for (pklStyle, expectedCore) in expectations {
            let entry = Android.ImagesEntry(
                mainRes: nil,
                templatesPath: nil,
                scales: nil,
                output: "images",
                format: .png,
                webpOptions: nil,
                sourceFormat: nil,
                nameStyle: pklStyle,
                codeConnectKotlin: nil,
                figmaFrameName: nil,
                figmaPageName: nil,
                figmaFileId: nil,
                rtlProperty: nil,
                nameValidateRegexp: nil,
                nameReplaceRegexp: nil
            )
            XCTAssertEqual(
                entry.effectiveNameStyle, expectedCore,
                "Android.ImagesEntry with nameStyle=\(pklStyle) should bridge to \(expectedCore)"
            )
        }
    }

    func testAndroidImagesEntryEffectiveNameStyleDefaultsToSnakeCase() {
        let entry = Android.ImagesEntry(
            mainRes: nil,
            templatesPath: nil,
            scales: nil,
            output: "images",
            format: .png,
            webpOptions: nil,
            sourceFormat: nil,
            nameStyle: nil,
            codeConnectKotlin: nil,
            figmaFrameName: nil,
            figmaPageName: nil,
            figmaFileId: nil,
            rtlProperty: nil,
            nameValidateRegexp: nil,
            nameReplaceRegexp: nil
        )
        XCTAssertEqual(entry.effectiveNameStyle, .snakeCase)
    }

    // MARK: - Android NameTransform resolvedStyle

    func testAndroidNameTransformResolvedStyleMapsAllCases() {
        let expectations: [(Common.NameStyle, NameStyle)] = [
            (.camelCase, .camelCase),
            (.snake_case, .snakeCase),
            (.pascalCase, .pascalCase),
            (.flatCase, .flatCase),
            (.kebabCase, .kebabCase),
            (.sCREAMING_SNAKE_CASE, .screamingSnakeCase),
        ]

        for (pklStyle, expectedCore) in expectations {
            let transform = Android.NameTransform(
                style: pklStyle,
                prefix: nil,
                stripPrefixes: nil
            )
            XCTAssertEqual(
                transform.resolvedStyle, expectedCore,
                "Android.NameTransform with style=\(pklStyle) should resolve to \(expectedCore)"
            )
        }
    }

    func testAndroidNameTransformResolvedStyleDefaultsToPascalCase() {
        let transform = Android.NameTransform(
            style: nil,
            prefix: nil,
            stripPrefixes: nil
        )
        XCTAssertEqual(transform.resolvedStyle, .pascalCase)
    }

    // MARK: - iOS XcodeRenderMode Bridging

    func testiOSIconsEntryCoreRenderModeBridgesAllCases() {
        for pklCase in iOS.XcodeRenderMode.allCases {
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
                renderMode: pklCase,
                renderModeDefaultSuffix: nil,
                renderModeOriginalSuffix: nil,
                renderModeTemplateSuffix: nil,
                figmaFrameName: nil,
                figmaPageName: nil,
                figmaFileId: nil,
                rtlProperty: nil,
                nameValidateRegexp: nil,
                nameReplaceRegexp: nil
            )
            XCTAssertNotNil(
                entry.coreRenderMode,
                "iOS.IconsEntry with renderMode=\(pklCase) should bridge to non-nil XcodeRenderMode"
            )
        }
    }

    func testiOSImagesEntryCoreRenderModeBridgesAllCases() {
        for pklCase in iOS.XcodeRenderMode.allCases {
            let entry = iOS.ImagesEntry(
                assetsFolder: "Images",
                nameStyle: .camelCase,
                scales: nil,
                imageSwift: nil,
                swiftUIImageSwift: nil,
                codeConnectSwift: nil,
                sourceFormat: nil,
                outputFormat: nil,
                heicOptions: nil,
                xcassetsPath: nil,
                templatesPath: nil,
                renderMode: pklCase,
                renderModeDefaultSuffix: nil,
                renderModeOriginalSuffix: nil,
                renderModeTemplateSuffix: nil,
                figmaFrameName: nil,
                figmaPageName: nil,
                figmaFileId: nil,
                rtlProperty: nil,
                nameValidateRegexp: nil,
                nameReplaceRegexp: nil
            )
            XCTAssertNotNil(
                entry.coreRenderMode,
                "iOS.ImagesEntry with renderMode=\(pklCase) should bridge to non-nil XcodeRenderMode"
            )
        }
    }

    // MARK: - VectorFormat Bridging

    func testVectorFormatBridgesAllCases() {
        for pklCase in Common.VectorFormat.allCases {
            XCTAssertNotNil(
                VectorFormat(rawValue: pklCase.rawValue),
                "Common.VectorFormat.\(pklCase) has no ExFigCore.VectorFormat mapping"
            )
        }
    }

    // MARK: - ImageSourceFormat Bridging

    func testImageSourceFormatBridgesAllCases() {
        for pklCase in Common.SourceFormat.allCases {
            XCTAssertNotNil(
                ImageSourceFormat(rawValue: pklCase.rawValue),
                "Common.SourceFormat.\(pklCase) has no ExFigCore.ImageSourceFormat mapping"
            )
        }
    }

    // MARK: - HEIC Encoding Bridging

    func testHeicEncodingBridgesAllCases() {
        for pklCase in iOS.HeicEncoding.allCases {
            XCTAssertNotNil(
                HeicConverterOptions.Encoding(rawValue: pklCase.rawValue),
                "iOS.HeicEncoding.\(pklCase) has no HeicConverterOptions.Encoding mapping"
            )
        }
    }

    // MARK: - iOS ColorsSourceInput Validation

    func testValidatedColorsSourceInputThrowsOnMissingTokensFileId() {
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
            tokensFile: nil, tokensFileId: nil,
            tokensCollectionName: "Collection",
            lightModeName: "Light",
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

    func testValidatedColorsSourceInputThrowsOnEmptyTokensFileId() {
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
            tokensFile: nil, tokensFileId: "",
            tokensCollectionName: "Collection",
            lightModeName: "Light",
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

    func testValidatedColorsSourceInputSucceedsWithAllRequiredFields() throws {
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
            tokensFile: nil, tokensFileId: "file123",
            tokensCollectionName: "Collection",
            lightModeName: "Light",
            darkModeName: "Dark",
            lightHCModeName: nil,
            darkHCModeName: nil,
            primitivesModeName: nil,
            nameValidateRegexp: nil,
            nameReplaceRegexp: nil
        )
        let sourceInput = try entry.validatedColorsSourceInput()
        XCTAssertEqual(sourceInput.tokensFileId, "file123")
        XCTAssertEqual(sourceInput.tokensCollectionName, "Collection")
        XCTAssertEqual(sourceInput.lightModeName, "Light")
        XCTAssertEqual(sourceInput.darkModeName, "Dark")
    }

    // MARK: - TokensFile Source Validation

    func testTokensFileSourceBypassesFigmaValidation() throws {
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
        XCTAssertTrue(sourceInput.isLocalTokensFile)
        XCTAssertEqual(sourceInput.tokensFilePath, "tokens.json")
        XCTAssertNil(sourceInput.tokensFileGroupFilter)
    }

    func testTokensFileSourceWithGroupFilter() throws {
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
            tokensFile: Common.TokensFile(path: "design-tokens.json", groupFilter: "Brand.Colors"),
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
        XCTAssertTrue(sourceInput.isLocalTokensFile)
        XCTAssertEqual(sourceInput.tokensFilePath, "design-tokens.json")
        XCTAssertEqual(sourceInput.tokensFileGroupFilter, "Brand.Colors")
    }

    func testWithoutTokensFileFallsBackToFigmaValidation() {
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

    // MARK: - Android ColorsSourceInput Validation

    func testAndroidColorsEntryThrowsOnMissingTokensFileId() {
        let entry = Android.ColorsEntry(
            mainRes: nil,
            mainSrc: nil,
            templatesPath: nil,
            xmlOutputFileName: nil,
            xmlDisabled: nil,
            composePackageName: nil,
            colorKotlin: nil,
            themeAttributes: nil,
            tokensFile: nil, tokensFileId: nil,
            tokensCollectionName: "Collection",
            lightModeName: "Light",
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

    func testAndroidColorsEntryThrowsOnEmptyTokensFileId() {
        let entry = Android.ColorsEntry(
            mainRes: nil,
            mainSrc: nil,
            templatesPath: nil,
            xmlOutputFileName: nil,
            xmlDisabled: nil,
            composePackageName: nil,
            colorKotlin: nil,
            themeAttributes: nil,
            tokensFile: nil, tokensFileId: "",
            tokensCollectionName: "Collection",
            lightModeName: "Light",
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

    func testAndroidColorsEntryValidatesSuccessfully() throws {
        let entry = Android.ColorsEntry(
            mainRes: nil,
            mainSrc: nil,
            templatesPath: nil,
            xmlOutputFileName: nil,
            xmlDisabled: nil,
            composePackageName: nil,
            colorKotlin: nil,
            themeAttributes: nil,
            tokensFile: nil, tokensFileId: "file456",
            tokensCollectionName: "Colors",
            lightModeName: "Light",
            darkModeName: "Dark",
            lightHCModeName: nil,
            darkHCModeName: nil,
            primitivesModeName: nil,
            nameValidateRegexp: nil,
            nameReplaceRegexp: nil
        )
        let sourceInput = try entry.validatedColorsSourceInput()
        XCTAssertEqual(sourceInput.tokensFileId, "file456")
        XCTAssertEqual(sourceInput.tokensCollectionName, "Colors")
        XCTAssertEqual(sourceInput.lightModeName, "Light")
        XCTAssertEqual(sourceInput.darkModeName, "Dark")
    }

    // MARK: - iOS Missing tokensCollectionName / lightModeName

    func testiOSColorsEntryThrowsOnMissingTokensCollectionName() {
        let entry = iOS.ColorsEntry(
            useColorAssets: false, assetsFolder: nil, nameStyle: .camelCase,
            groupUsingNamespace: nil, assetsFolderProvidesNamespace: nil, colorSwift: nil, swiftuiColorSwift: nil,
            xcassetsPath: nil, templatesPath: nil,
            syncCodeSyntax: nil, codeSyntaxTemplate: nil,
            tokensFile: nil, tokensFileId: "file123", tokensCollectionName: nil, lightModeName: "Light",
            darkModeName: nil, lightHCModeName: nil, darkHCModeName: nil,
            primitivesModeName: nil, nameValidateRegexp: nil, nameReplaceRegexp: nil
        )
        XCTAssertThrowsError(try entry.validatedColorsSourceInput()) { error in
            XCTAssert(error is ColorsConfigError)
        }
    }

    func testiOSColorsEntryThrowsOnEmptyTokensCollectionName() {
        let entry = iOS.ColorsEntry(
            useColorAssets: false, assetsFolder: nil, nameStyle: .camelCase,
            groupUsingNamespace: nil, assetsFolderProvidesNamespace: nil, colorSwift: nil, swiftuiColorSwift: nil,
            xcassetsPath: nil, templatesPath: nil,
            syncCodeSyntax: nil, codeSyntaxTemplate: nil,
            tokensFile: nil, tokensFileId: "file123", tokensCollectionName: "", lightModeName: "Light",
            darkModeName: nil, lightHCModeName: nil, darkHCModeName: nil,
            primitivesModeName: nil, nameValidateRegexp: nil, nameReplaceRegexp: nil
        )
        XCTAssertThrowsError(try entry.validatedColorsSourceInput()) { error in
            XCTAssert(error is ColorsConfigError)
        }
    }

    func testiOSColorsEntryThrowsOnMissingLightModeName() {
        let entry = iOS.ColorsEntry(
            useColorAssets: false, assetsFolder: nil, nameStyle: .camelCase,
            groupUsingNamespace: nil, assetsFolderProvidesNamespace: nil, colorSwift: nil, swiftuiColorSwift: nil,
            xcassetsPath: nil, templatesPath: nil,
            syncCodeSyntax: nil, codeSyntaxTemplate: nil,
            tokensFile: nil, tokensFileId: "file123", tokensCollectionName: "Collection", lightModeName: nil,
            darkModeName: nil, lightHCModeName: nil, darkHCModeName: nil,
            primitivesModeName: nil, nameValidateRegexp: nil, nameReplaceRegexp: nil
        )
        XCTAssertThrowsError(try entry.validatedColorsSourceInput()) { error in
            XCTAssert(error is ColorsConfigError)
        }
    }

    func testiOSColorsEntryThrowsOnEmptyLightModeName() {
        let entry = iOS.ColorsEntry(
            useColorAssets: false, assetsFolder: nil, nameStyle: .camelCase,
            groupUsingNamespace: nil, assetsFolderProvidesNamespace: nil, colorSwift: nil, swiftuiColorSwift: nil,
            xcassetsPath: nil, templatesPath: nil,
            syncCodeSyntax: nil, codeSyntaxTemplate: nil,
            tokensFile: nil, tokensFileId: "file123", tokensCollectionName: "Collection", lightModeName: "",
            darkModeName: nil, lightHCModeName: nil, darkHCModeName: nil,
            primitivesModeName: nil, nameValidateRegexp: nil, nameReplaceRegexp: nil
        )
        XCTAssertThrowsError(try entry.validatedColorsSourceInput()) { error in
            XCTAssert(error is ColorsConfigError)
        }
    }

    // MARK: - Android Missing tokensCollectionName / lightModeName

    func testAndroidColorsEntryThrowsOnMissingTokensCollectionName() {
        let entry = Android.ColorsEntry(
            mainRes: nil, mainSrc: nil, templatesPath: nil,
            xmlOutputFileName: nil, xmlDisabled: nil, composePackageName: nil,
            colorKotlin: nil, themeAttributes: nil,
            tokensFile: nil, tokensFileId: "file456", tokensCollectionName: nil, lightModeName: "Light",
            darkModeName: nil, lightHCModeName: nil, darkHCModeName: nil,
            primitivesModeName: nil, nameValidateRegexp: nil, nameReplaceRegexp: nil
        )
        XCTAssertThrowsError(try entry.validatedColorsSourceInput()) { error in
            XCTAssert(error is ColorsConfigError)
        }
    }

    func testAndroidColorsEntryThrowsOnEmptyTokensCollectionName() {
        let entry = Android.ColorsEntry(
            mainRes: nil, mainSrc: nil, templatesPath: nil,
            xmlOutputFileName: nil, xmlDisabled: nil, composePackageName: nil,
            colorKotlin: nil, themeAttributes: nil,
            tokensFile: nil, tokensFileId: "file456", tokensCollectionName: "", lightModeName: "Light",
            darkModeName: nil, lightHCModeName: nil, darkHCModeName: nil,
            primitivesModeName: nil, nameValidateRegexp: nil, nameReplaceRegexp: nil
        )
        XCTAssertThrowsError(try entry.validatedColorsSourceInput()) { error in
            XCTAssert(error is ColorsConfigError)
        }
    }

    func testAndroidColorsEntryThrowsOnMissingLightModeName() {
        let entry = Android.ColorsEntry(
            mainRes: nil, mainSrc: nil, templatesPath: nil,
            xmlOutputFileName: nil, xmlDisabled: nil, composePackageName: nil,
            colorKotlin: nil, themeAttributes: nil,
            tokensFile: nil, tokensFileId: "file456", tokensCollectionName: "Colors", lightModeName: nil,
            darkModeName: nil, lightHCModeName: nil, darkHCModeName: nil,
            primitivesModeName: nil, nameValidateRegexp: nil, nameReplaceRegexp: nil
        )
        XCTAssertThrowsError(try entry.validatedColorsSourceInput()) { error in
            XCTAssert(error is ColorsConfigError)
        }
    }

    func testAndroidColorsEntryThrowsOnEmptyLightModeName() {
        let entry = Android.ColorsEntry(
            mainRes: nil, mainSrc: nil, templatesPath: nil,
            xmlOutputFileName: nil, xmlDisabled: nil, composePackageName: nil,
            colorKotlin: nil, themeAttributes: nil,
            tokensFile: nil, tokensFileId: "file456", tokensCollectionName: "Colors", lightModeName: "",
            darkModeName: nil, lightHCModeName: nil, darkHCModeName: nil,
            primitivesModeName: nil, nameValidateRegexp: nil, nameReplaceRegexp: nil
        )
        XCTAssertThrowsError(try entry.validatedColorsSourceInput()) { error in
            XCTAssert(error is ColorsConfigError)
        }
    }

    // MARK: - Flutter ColorsSourceInput Validation

    func testFlutterColorsEntryThrowsOnMissingTokensFileId() {
        let entry = Flutter.ColorsEntry(
            templatesPath: nil, output: nil, className: nil,
            tokensFile: nil, tokensFileId: nil, tokensCollectionName: "Collection", lightModeName: "Light",
            darkModeName: nil, lightHCModeName: nil, darkHCModeName: nil,
            primitivesModeName: nil, nameValidateRegexp: nil, nameReplaceRegexp: nil
        )
        XCTAssertThrowsError(try entry.validatedColorsSourceInput()) { error in
            XCTAssert(error is ColorsConfigError)
        }
    }

    func testFlutterColorsEntryThrowsOnEmptyTokensFileId() {
        let entry = Flutter.ColorsEntry(
            templatesPath: nil, output: nil, className: nil,
            tokensFile: nil, tokensFileId: "", tokensCollectionName: "Collection", lightModeName: "Light",
            darkModeName: nil, lightHCModeName: nil, darkHCModeName: nil,
            primitivesModeName: nil, nameValidateRegexp: nil, nameReplaceRegexp: nil
        )
        XCTAssertThrowsError(try entry.validatedColorsSourceInput()) { error in
            XCTAssert(error is ColorsConfigError)
        }
    }

    func testFlutterColorsEntryThrowsOnMissingTokensCollectionName() {
        let entry = Flutter.ColorsEntry(
            templatesPath: nil, output: nil, className: nil,
            tokensFile: nil, tokensFileId: "file789", tokensCollectionName: nil, lightModeName: "Light",
            darkModeName: nil, lightHCModeName: nil, darkHCModeName: nil,
            primitivesModeName: nil, nameValidateRegexp: nil, nameReplaceRegexp: nil
        )
        XCTAssertThrowsError(try entry.validatedColorsSourceInput()) { error in
            XCTAssert(error is ColorsConfigError)
        }
    }

    func testFlutterColorsEntryThrowsOnEmptyTokensCollectionName() {
        let entry = Flutter.ColorsEntry(
            templatesPath: nil, output: nil, className: nil,
            tokensFile: nil, tokensFileId: "file789", tokensCollectionName: "", lightModeName: "Light",
            darkModeName: nil, lightHCModeName: nil, darkHCModeName: nil,
            primitivesModeName: nil, nameValidateRegexp: nil, nameReplaceRegexp: nil
        )
        XCTAssertThrowsError(try entry.validatedColorsSourceInput()) { error in
            XCTAssert(error is ColorsConfigError)
        }
    }

    func testFlutterColorsEntryThrowsOnMissingLightModeName() {
        let entry = Flutter.ColorsEntry(
            templatesPath: nil, output: nil, className: nil,
            tokensFile: nil, tokensFileId: "file789", tokensCollectionName: "Collection", lightModeName: nil,
            darkModeName: nil, lightHCModeName: nil, darkHCModeName: nil,
            primitivesModeName: nil, nameValidateRegexp: nil, nameReplaceRegexp: nil
        )
        XCTAssertThrowsError(try entry.validatedColorsSourceInput()) { error in
            XCTAssert(error is ColorsConfigError)
        }
    }

    func testFlutterColorsEntryThrowsOnEmptyLightModeName() {
        let entry = Flutter.ColorsEntry(
            templatesPath: nil, output: nil, className: nil,
            tokensFile: nil, tokensFileId: "file789", tokensCollectionName: "Collection", lightModeName: "",
            darkModeName: nil, lightHCModeName: nil, darkHCModeName: nil,
            primitivesModeName: nil, nameValidateRegexp: nil, nameReplaceRegexp: nil
        )
        XCTAssertThrowsError(try entry.validatedColorsSourceInput()) { error in
            XCTAssert(error is ColorsConfigError)
        }
    }

    func testFlutterColorsEntryValidatesSuccessfully() throws {
        let entry = Flutter.ColorsEntry(
            templatesPath: nil, output: nil, className: nil,
            tokensFile: nil, tokensFileId: "file789", tokensCollectionName: "Colors", lightModeName: "Light",
            darkModeName: "Dark", lightHCModeName: nil, darkHCModeName: nil,
            primitivesModeName: nil, nameValidateRegexp: nil, nameReplaceRegexp: nil
        )
        let sourceInput = try entry.validatedColorsSourceInput()
        XCTAssertEqual(sourceInput.tokensFileId, "file789")
        XCTAssertEqual(sourceInput.tokensCollectionName, "Colors")
        XCTAssertEqual(sourceInput.lightModeName, "Light")
        XCTAssertEqual(sourceInput.darkModeName, "Dark")
    }

    // MARK: - Web ColorsSourceInput Validation

    func testWebColorsEntryThrowsOnMissingTokensFileId() {
        let entry = Web.ColorsEntry(
            output: nil, templatesPath: nil,
            outputDirectory: nil, cssFileName: nil, tsFileName: nil, jsonFileName: nil,
            tokensFile: nil, tokensFileId: nil, tokensCollectionName: "Collection", lightModeName: "Light",
            darkModeName: nil, lightHCModeName: nil, darkHCModeName: nil,
            primitivesModeName: nil, nameValidateRegexp: nil, nameReplaceRegexp: nil
        )
        XCTAssertThrowsError(try entry.validatedColorsSourceInput()) { error in
            XCTAssert(error is ColorsConfigError)
        }
    }

    func testWebColorsEntryThrowsOnEmptyTokensFileId() {
        let entry = Web.ColorsEntry(
            output: nil, templatesPath: nil,
            outputDirectory: nil, cssFileName: nil, tsFileName: nil, jsonFileName: nil,
            tokensFile: nil, tokensFileId: "", tokensCollectionName: "Collection", lightModeName: "Light",
            darkModeName: nil, lightHCModeName: nil, darkHCModeName: nil,
            primitivesModeName: nil, nameValidateRegexp: nil, nameReplaceRegexp: nil
        )
        XCTAssertThrowsError(try entry.validatedColorsSourceInput()) { error in
            XCTAssert(error is ColorsConfigError)
        }
    }

    func testWebColorsEntryThrowsOnMissingTokensCollectionName() {
        let entry = Web.ColorsEntry(
            output: nil, templatesPath: nil,
            outputDirectory: nil, cssFileName: nil, tsFileName: nil, jsonFileName: nil,
            tokensFile: nil, tokensFileId: "fileABC", tokensCollectionName: nil, lightModeName: "Light",
            darkModeName: nil, lightHCModeName: nil, darkHCModeName: nil,
            primitivesModeName: nil, nameValidateRegexp: nil, nameReplaceRegexp: nil
        )
        XCTAssertThrowsError(try entry.validatedColorsSourceInput()) { error in
            XCTAssert(error is ColorsConfigError)
        }
    }

    func testWebColorsEntryThrowsOnEmptyTokensCollectionName() {
        let entry = Web.ColorsEntry(
            output: nil, templatesPath: nil,
            outputDirectory: nil, cssFileName: nil, tsFileName: nil, jsonFileName: nil,
            tokensFile: nil, tokensFileId: "fileABC", tokensCollectionName: "", lightModeName: "Light",
            darkModeName: nil, lightHCModeName: nil, darkHCModeName: nil,
            primitivesModeName: nil, nameValidateRegexp: nil, nameReplaceRegexp: nil
        )
        XCTAssertThrowsError(try entry.validatedColorsSourceInput()) { error in
            XCTAssert(error is ColorsConfigError)
        }
    }

    func testWebColorsEntryThrowsOnMissingLightModeName() {
        let entry = Web.ColorsEntry(
            output: nil, templatesPath: nil,
            outputDirectory: nil, cssFileName: nil, tsFileName: nil, jsonFileName: nil,
            tokensFile: nil, tokensFileId: "fileABC", tokensCollectionName: "Collection", lightModeName: nil,
            darkModeName: nil, lightHCModeName: nil, darkHCModeName: nil,
            primitivesModeName: nil, nameValidateRegexp: nil, nameReplaceRegexp: nil
        )
        XCTAssertThrowsError(try entry.validatedColorsSourceInput()) { error in
            XCTAssert(error is ColorsConfigError)
        }
    }

    func testWebColorsEntryThrowsOnEmptyLightModeName() {
        let entry = Web.ColorsEntry(
            output: nil, templatesPath: nil,
            outputDirectory: nil, cssFileName: nil, tsFileName: nil, jsonFileName: nil,
            tokensFile: nil, tokensFileId: "fileABC", tokensCollectionName: "Collection", lightModeName: "",
            darkModeName: nil, lightHCModeName: nil, darkHCModeName: nil,
            primitivesModeName: nil, nameValidateRegexp: nil, nameReplaceRegexp: nil
        )
        XCTAssertThrowsError(try entry.validatedColorsSourceInput()) { error in
            XCTAssert(error is ColorsConfigError)
        }
    }

    func testWebColorsEntryValidatesSuccessfully() throws {
        let entry = Web.ColorsEntry(
            output: nil, templatesPath: nil,
            outputDirectory: nil, cssFileName: nil, tsFileName: nil, jsonFileName: nil,
            tokensFile: nil, tokensFileId: "fileABC", tokensCollectionName: "Colors", lightModeName: "Light",
            darkModeName: "Dark", lightHCModeName: nil, darkHCModeName: nil,
            primitivesModeName: nil, nameValidateRegexp: nil, nameReplaceRegexp: nil
        )
        let sourceInput = try entry.validatedColorsSourceInput()
        XCTAssertEqual(sourceInput.tokensFileId, "fileABC")
        XCTAssertEqual(sourceInput.tokensCollectionName, "Colors")
        XCTAssertEqual(sourceInput.lightModeName, "Light")
        XCTAssertEqual(sourceInput.darkModeName, "Dark")
    }
}
