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

    // MARK: - applyResult: Section removal

    @Test("applyResult removes colors section when not selected")
    func removeColorsSection() {
        let result = makeResult(selectedAssetTypes: [.icons, .images, .typography])
        let output = InitWizard.applyResult(result, to: iosTemplate)
        #expect(!output.contains("colors = new Common.Colors {"))
        #expect(!output.contains("colors = new iOS.ColorsEntry {"))
        // variablesColors commented block should also be removed
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
            imagesFrameName: nil
        )
        let output = InitWizard.applyResult(result, to: flutterTemplate)
        #expect(output.contains("FLUTTER_ID"))
        #expect(output.contains("FLUTTER_DARK"))
        #expect(output.contains("colors = new Common.Colors {"))
        #expect(output.contains("colors = new Flutter.ColorsEntry {"))
        #expect(output.contains("icons = new Flutter.IconsEntry {"))
        #expect(output.contains("images = new Flutter.ImagesEntry {"))
        // Flutter has no typography config sections
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
        imagesFrameName: String? = nil
    ) -> InitWizardResult {
        InitWizardResult(
            platform: platform,
            selectedAssetTypes: selectedAssetTypes,
            lightFileId: lightFileId,
            darkFileId: darkFileId,
            iconsFrameName: iconsFrameName,
            imagesFrameName: imagesFrameName
        )
    }
}
