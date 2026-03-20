@testable import ExFigCLI
import ExFigCore
import Testing

@Suite("InitWizard")
struct InitWizardTests {
    // MARK: - WizardPlatform.asPlatform

    @Test("WizardPlatform.asPlatform maps all 4 cases correctly")
    func wizardPlatformAsPlatform() {
        #expect(WizardPlatform.ios.asPlatform == .ios)
        #expect(WizardPlatform.android.asPlatform == .android)
        #expect(WizardPlatform.flutter.asPlatform == .flutter)
        #expect(WizardPlatform.web.asPlatform == .web)
    }

    // MARK: - InitAssetType

    @Test("InitAssetType descriptions match raw values")
    func assetTypeDescriptions() {
        #expect(InitAssetType.colors.description == "Colors")
        #expect(InitAssetType.icons.description == "Icons")
        #expect(InitAssetType.images.description == "Images")
        #expect(InitAssetType.typography.description == "Typography")
    }

    @Test("availableTypes excludes typography for Flutter and Web")
    func availableTypesPerPlatform() {
        let iosTypes = InitAssetType.availableTypes(for: .ios)
        #expect(iosTypes.contains(.typography))
        #expect(iosTypes.count == 4)

        let flutterTypes = InitAssetType.availableTypes(for: .flutter)
        #expect(!flutterTypes.contains(.typography))
        #expect(flutterTypes.count == 3)

        let webTypes = InitAssetType.availableTypes(for: .web)
        #expect(!webTypes.contains(.typography))
        #expect(webTypes.count == 3)
    }

    // MARK: - applyResult: File ID substitution

    @Test("applyResult substitutes light file ID")
    func substituteLightFileId() {
        let result = makeResult(lightFileId: "ABC123")
        let output = InitWizard.applyResult(result, to: iosTemplate)
        #expect(output.contains("ABC123"))
        #expect(!output.contains("shPilWnVdJfo10YF12345"))
    }

    @Test("applyResult substitutes dark file ID when provided")
    func substituteDarkFileId() {
        let result = makeResult(darkFileId: "DARK456")
        let output = InitWizard.applyResult(result, to: iosTemplate)
        #expect(output.contains("DARK456"))
        #expect(!output.contains("KfF6DnJTWHGZzC912345"))
    }

    @Test("applyResult removes darkFileId line when nil")
    func removeDarkFileIdWhenNil() {
        let result = makeResult(darkFileId: nil)
        let output = InitWizard.applyResult(result, to: iosTemplate)
        #expect(!output.contains("darkFileId"))
    }

    // MARK: - applyResult: Frame name substitution

    @Test("applyResult substitutes custom icons frame name")
    func substituteIconsFrameName() {
        let result = makeResult(iconsFrameName: "MyIcons")
        let output = InitWizard.applyResult(result, to: iosTemplate)
        #expect(output.contains("figmaFrameName = \"MyIcons\""))
    }

    @Test("applyResult substitutes custom images frame name")
    func substituteImagesFrameName() {
        let result = makeResult(imagesFrameName: "MyImages")
        let output = InitWizard.applyResult(result, to: iosTemplate)
        #expect(output.contains("figmaFrameName = \"MyImages\""))
    }

    // MARK: - applyResult: Page name substitution

    @Test("applyResult uncomments icons page name when provided")
    func uncommentIconsPageName() {
        let result = makeResult(iconsPageName: "Outlined")
        let output = InitWizard.applyResult(result, to: iosTemplate)
        #expect(output.contains("figmaPageName = \"Outlined\""))
        #expect(!output.contains("// figmaPageName = \"Outlined\""))
    }

    @Test("applyResult uncomments images page name when provided")
    func uncommentImagesPageName() {
        let result = makeResult(imagesPageName: "Marketing")
        let output = InitWizard.applyResult(result, to: iosTemplate)
        #expect(output.contains("figmaPageName = \"Marketing\""))
    }

    @Test("applyResult keeps page name commented when not provided")
    func pageNameStaysCommentedWhenNil() {
        let result = makeResult()
        let output = InitWizard.applyResult(result, to: iosTemplate)
        // Both page name lines should remain commented
        #expect(output.contains("// figmaPageName = "))
    }

    // MARK: - applyResult: Variables colors

    @Test("applyResult replaces colors with variablesColors when variables config provided")
    func variablesColorsReplacesStyles() {
        let vars = InitVariablesConfig(
            tokensFileId: "TOKENS_FILE",
            collectionName: "My Tokens",
            lightModeName: "Day",
            darkModeName: "Night"
        )
        let result = makeResult(variablesConfig: vars)
        let output = InitWizard.applyResult(result, to: iosTemplate)
        // Regular colors section removed
        #expect(!output.contains("colors = new Common.Colors {"))
        // variablesColors uncommented and populated
        #expect(output.contains("variablesColors = new Common.VariablesColors {"))
        #expect(output.contains("tokensFileId = \"TOKENS_FILE\""))
        #expect(output.contains("tokensCollectionName = \"My Tokens\""))
        #expect(output.contains("lightModeName = \"Day\""))
        #expect(output.contains("darkModeName = \"Night\""))
    }

    @Test("applyResult comments out darkModeName when variables config has no dark mode")
    func variablesColorsNoDarkMode() {
        let vars = InitVariablesConfig(
            tokensFileId: "TOKENS_FILE",
            collectionName: "Primitives",
            lightModeName: "Light",
            darkModeName: nil
        )
        let result = makeResult(variablesConfig: vars)
        let output = InitWizard.applyResult(result, to: iosTemplate)
        #expect(output.contains("variablesColors = new Common.VariablesColors {"))
        // darkModeName should be commented out
        let darkModeLines = output.components(separatedBy: "\n")
            .filter { $0.contains("darkModeName") }
        for line in darkModeLines {
            #expect(
                line.trimmingCharacters(in: .whitespaces).hasPrefix("//"),
                "darkModeName should be commented: \(line)"
            )
        }
    }

    @Test("applyResult with styles removes variablesColors comment block")
    func stylesRemovesVariablesBlock() {
        let result = makeResult(variablesConfig: nil)
        let output = InitWizard.applyResult(result, to: iosTemplate)
        #expect(output.contains("colors = new Common.Colors {"))
        #expect(!output.contains("variablesColors = new Common.VariablesColors {"))
    }

    @Test("Brace balance with variablesColors")
    func balancedBracesWithVariables() {
        let vars = InitVariablesConfig(
            tokensFileId: "ID", collectionName: "C", lightModeName: "L", darkModeName: "D"
        )
        let result = makeResult(variablesConfig: vars)
        let output = InitWizard.applyResult(result, to: iosTemplate)
        let openCount = output.filter { $0 == "{" }.count
        let closeCount = output.filter { $0 == "}" }.count
        #expect(openCount == closeCount, "Unbalanced braces: \(openCount) open vs \(closeCount) close")
    }

    // MARK: - applyResult: Section removal

    @Test("applyResult removes colors section when not selected")
    func removeColorsSection() {
        let result = makeResult(selectedAssetTypes: [.icons, .images, .typography])
        let output = InitWizard.applyResult(result, to: iosTemplate)
        #expect(!output.contains("colors = new Common.Colors {"))
        #expect(!output.contains("colors = new iOS.ColorsEntry {"))
        #expect(!output.contains("variablesColors = new Common.VariablesColors {"))
    }

    @Test("applyResult removes icons section when not selected")
    func removeIconsSection() {
        let result = makeResult(selectedAssetTypes: [.colors, .images, .typography])
        let output = InitWizard.applyResult(result, to: iosTemplate)
        #expect(!output.contains("icons = new Common.Icons {"))
        #expect(!output.contains("icons = new iOS.IconsEntry {"))
    }

    @Test("applyResult removes images section when not selected")
    func removeImagesSection() {
        let result = makeResult(selectedAssetTypes: [.colors, .icons, .typography])
        let output = InitWizard.applyResult(result, to: iosTemplate)
        #expect(!output.contains("images = new Common.Images {"))
        #expect(!output.contains("images = new iOS.ImagesEntry {"))
    }

    @Test("applyResult removes typography section for iOS when not selected")
    func removeTypographySection() {
        let result = makeResult(selectedAssetTypes: [.colors, .icons, .images])
        let output = InitWizard.applyResult(result, to: iosTemplate)
        #expect(!output.contains("typography = new Common.Typography {"))
        #expect(!output.contains("typography = new iOS.Typography {"))
    }

    @Test("applyResult removes multiple sections at once")
    func removeMultipleSections() {
        let result = makeResult(selectedAssetTypes: [.colors])
        let output = InitWizard.applyResult(result, to: iosTemplate)
        #expect(output.contains("colors = new Common.Colors {"))
        #expect(output.contains("colors = new iOS.ColorsEntry {"))
        #expect(!output.contains("icons = new Common.Icons {"))
        #expect(!output.contains("images = new Common.Images {"))
        #expect(!output.contains("typography = new Common.Typography {"))
    }

    // MARK: - applyResult: Flutter (no typography)

    @Test("applyResult with Flutter and all available types preserves all sections")
    func flutterAllSelected() {
        let result = InitWizardResult(
            platform: .flutter,
            selectedAssetTypes: [.colors, .icons, .images],
            lightFileId: "FLUTTER_ID",
            darkFileId: "FLUTTER_DARK",
            iconsFrameName: nil,
            iconsPageName: nil,
            imagesFrameName: nil,
            imagesPageName: nil,
            variablesConfig: nil
        )
        let output = InitWizard.applyResult(result, to: flutterTemplate)
        #expect(output.contains("FLUTTER_ID"))
        #expect(output.contains("FLUTTER_DARK"))
        #expect(output.contains("colors = new Common.Colors {"))
        #expect(output.contains("colors = new Flutter.ColorsEntry {"))
        #expect(output.contains("icons = new Flutter.IconsEntry {"))
        #expect(output.contains("images = new Flutter.ImagesEntry {"))
        #expect(!output.contains("typography = new Common.Typography {"))
        #expect(!output.contains("typography = new Flutter."))
    }

    // MARK: - Brace balance

    @Test("Result PKL has balanced braces")
    func balancedBraces() {
        let result = makeResult(selectedAssetTypes: [.colors, .icons])
        let output = InitWizard.applyResult(result, to: iosTemplate)
        let openCount = output.filter { $0 == "{" }.count
        let closeCount = output.filter { $0 == "}" }.count
        #expect(openCount == closeCount, "Unbalanced braces: \(openCount) open vs \(closeCount) close")
    }

    @Test("Brace balance after removing all optional sections")
    func balancedBracesMinimal() {
        let result = makeResult(selectedAssetTypes: [.colors], darkFileId: nil)
        let output = InitWizard.applyResult(result, to: iosTemplate)
        let openCount = output.filter { $0 == "{" }.count
        let closeCount = output.filter { $0 == "}" }.count
        #expect(openCount == closeCount, "Unbalanced braces: \(openCount) open vs \(closeCount) close")
    }

    // MARK: - Helpers

    private var iosTemplate: String {
        iosConfigFileContents
    }

    private var flutterTemplate: String {
        flutterConfigFileContents
    }

    private func makeResult(
        platform: Platform = .ios,
        selectedAssetTypes: [InitAssetType] = [.colors, .icons, .images, .typography],
        lightFileId: String = "LIGHT_FILE_ID",
        darkFileId: String? = "DARK_FILE_ID",
        iconsFrameName: String? = nil,
        iconsPageName: String? = nil,
        imagesFrameName: String? = nil,
        imagesPageName: String? = nil,
        variablesConfig: InitVariablesConfig? = nil
    ) -> InitWizardResult {
        InitWizardResult(
            platform: platform,
            selectedAssetTypes: selectedAssetTypes,
            lightFileId: lightFileId,
            darkFileId: darkFileId,
            iconsFrameName: iconsFrameName,
            iconsPageName: iconsPageName,
            imagesFrameName: imagesFrameName,
            imagesPageName: imagesPageName,
            variablesConfig: variablesConfig
        )
    }
}

// MARK: - Cross-Platform Template Tests

@Suite("InitWizard Cross-Platform")
struct InitWizardCrossPlatformTests {
    @Test("applyResult works with Android template")
    func androidAllSelected() {
        let result = InitWizardResult(
            platform: .android,
            selectedAssetTypes: [.colors, .icons, .images, .typography],
            lightFileId: "ANDROID_ID",
            darkFileId: "ANDROID_DARK",
            iconsFrameName: nil,
            iconsPageName: nil,
            imagesFrameName: nil,
            imagesPageName: nil,
            variablesConfig: nil
        )
        let output = InitWizard.applyResult(result, to: androidConfigFileContents)
        #expect(output.contains("ANDROID_ID"))
        #expect(output.contains("ANDROID_DARK"))
        #expect(output.contains("colors = new Android.ColorsEntry {"))
        #expect(output.contains("icons = new Android.IconsEntry {"))
        #expect(output.contains("images = new Android.ImagesEntry {"))
        #expect(output.contains("typography = new Android.Typography {"))
        let openCount = output.filter { $0 == "{" }.count
        let closeCount = output.filter { $0 == "}" }.count
        #expect(openCount == closeCount, "Unbalanced braces in Android: \(openCount) vs \(closeCount)")
    }

    @Test("applyResult works with Web template (no typography)")
    func webAllSelected() {
        let result = InitWizardResult(
            platform: .web,
            selectedAssetTypes: [.colors, .icons, .images],
            lightFileId: "WEB_ID",
            darkFileId: nil,
            iconsFrameName: "WebIcons",
            iconsPageName: nil,
            imagesFrameName: nil,
            imagesPageName: nil,
            variablesConfig: nil
        )
        let output = InitWizard.applyResult(result, to: webConfigFileContents)
        #expect(output.contains("WEB_ID"))
        #expect(!output.contains("darkFileId"))
        #expect(output.contains("colors = new Web.ColorsEntry {"))
        #expect(output.contains("icons = new Web.IconsEntry {"))
        #expect(output.contains("images = new Web.ImagesEntry {"))
        #expect(output.contains("figmaFrameName = \"WebIcons\""))
        let openCount = output.filter { $0 == "{" }.count
        let closeCount = output.filter { $0 == "}" }.count
        #expect(openCount == closeCount, "Unbalanced braces in Web: \(openCount) vs \(closeCount)")
    }
}

// MARK: - Transform Utilities Tests

@Suite("InitWizard Transform Utilities")
struct InitWizardTransformUtilityTests {
    @Test("removeSection returns template unchanged when marker not found")
    func removeSectionMissingMarker() {
        let template = "line 1\nline 2\nline 3"
        let result = InitWizard.removeSection(from: template, matching: "nonexistent marker")
        #expect(result == template)
    }

    @Test("collapseBlankLines collapses 3+ blank lines to 2")
    func collapseBlankLines() {
        let input = "a\n\n\n\n\nb"
        let output = InitWizard.collapseBlankLines(input)
        let blankCount = output.components(separatedBy: "\n").filter(\.isEmpty).count
        #expect(blankCount <= 2)
        #expect(output.contains("a"))
        #expect(output.contains("b"))
    }

    @Test("collapseBlankLines preserves 2 blank lines")
    func collapseBlankLinesPreserves() {
        let input = "a\n\n\nb"
        let output = InitWizard.collapseBlankLines(input)
        #expect(output == input)
    }
}
