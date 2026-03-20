import ExFigCore
import Noora

// MARK: - Init Asset Type

/// Asset type choice for the init wizard multi-select.
enum InitAssetType: String, CaseIterable, CustomStringConvertible, Equatable {
    case colors = "Colors"
    case icons = "Icons"
    case images = "Images"
    case typography = "Typography"

    var description: String {
        rawValue
    }

    /// Asset types available for the given platform.
    /// Typography is only available for iOS and Android.
    static func availableTypes(for platform: WizardPlatform) -> [InitAssetType] {
        switch platform {
        case .ios, .android:
            allCases
        case .flutter, .web:
            allCases.filter { $0 != .typography }
        }
    }

    /// CLI command name for this asset type.
    var commandName: String {
        switch self {
        case .colors: "colors"
        case .icons: "icons"
        case .images: "images"
        case .typography: "typography"
        }
    }
}

// MARK: - Colors Source

/// How colors are sourced from Figma.
enum InitColorsSource: String, CaseIterable, CustomStringConvertible, Equatable {
    case styles = "Color Styles (from file)"
    case variables = "Figma Variables"

    var description: String {
        rawValue
    }
}

/// Configuration for colors sourced from Figma Variables.
struct InitVariablesConfig {
    let tokensFileId: String
    let collectionName: String
    let lightModeName: String
    let darkModeName: String?
}

// MARK: - Init Wizard Result

/// Result of the interactive init wizard flow.
struct InitWizardResult {
    let platform: Platform
    let selectedAssetTypes: [InitAssetType]
    let lightFileId: String
    let darkFileId: String?
    let iconsFrameName: String?
    let iconsPageName: String?
    let imagesFrameName: String?
    let imagesPageName: String?
    let variablesConfig: InitVariablesConfig?
}

// MARK: - Init Wizard Flow

/// Interactive wizard for `exfig init` when `--platform` is not provided.
///
/// Template transformation logic lives in `InitWizardTransform.swift`.
enum InitWizard {
    /// Run the interactive wizard and return collected answers.
    static func run() -> InitWizardResult {
        // 1. Platform selection
        let wizardPlatform: WizardPlatform = NooraUI.singleChoicePrompt(
            title: "ExFig Config Wizard",
            question: "Target platform:",
            options: WizardPlatform.allCases,
            description: "Select the platform you want to export assets for"
        )
        let platform = wizardPlatform.asPlatform

        // 2. Asset type multi-select
        let availableTypes = InitAssetType.availableTypes(for: wizardPlatform)
        let selectedTypes: [InitAssetType] = NooraUI.multipleChoicePrompt(
            question: "What do you want to export?",
            options: availableTypes,
            description: "Use space to toggle, enter to confirm. At least one required.",
            minLimit: .limited(count: 1, errorMessage: "Select at least one asset type.")
        )

        // 3. Figma file ID (light)
        let lightFileIdInput = NooraUI.textPrompt(
            prompt: "Figma file ID or URL (figma.com/design/<ID>/...):",
            description: "Paste the file URL or just the ID from it",
            validationRules: [NonEmptyValidationRule(error: "File ID cannot be empty.")]
        )
        let lightFileId = extractFigmaFileId(from: lightFileIdInput)

        // 4. Dark mode file ID (optional)
        let darkFileIdRaw = promptOptionalText(
            question: "Do you have a separate dark mode file?",
            description: "If your dark colors/images are in a different Figma file",
            inputPrompt: "Dark mode file ID or URL:"
        )
        let darkFileId = darkFileIdRaw.map { extractFigmaFileId(from: $0) }

        // 5. Colors source (if colors selected)
        let variablesConfig: InitVariablesConfig? = if selectedTypes.contains(.colors) {
            promptColorsSource(lightFileId: lightFileId)
        } else {
            nil
        }

        // 6. Icons details (if icons selected)
        let iconsFrameName: String?
        let iconsPageName: String?
        if selectedTypes.contains(.icons) {
            iconsFrameName = promptFrameName(assetType: "icons", defaultName: "Icons")
            iconsPageName = promptPageName(assetType: "icons")
        } else {
            iconsFrameName = nil
            iconsPageName = nil
        }

        // 7. Images details (if images selected)
        let imagesFrameName: String?
        let imagesPageName: String?
        if selectedTypes.contains(.images) {
            imagesFrameName = promptFrameName(assetType: "images", defaultName: "Illustrations")
            imagesPageName = promptPageName(assetType: "images")
        } else {
            imagesFrameName = nil
            imagesPageName = nil
        }

        return InitWizardResult(
            platform: platform,
            selectedAssetTypes: selectedTypes,
            lightFileId: lightFileId,
            darkFileId: darkFileId,
            iconsFrameName: iconsFrameName,
            iconsPageName: iconsPageName,
            imagesFrameName: imagesFrameName,
            imagesPageName: imagesPageName,
            variablesConfig: variablesConfig
        )
    }

    // MARK: - Prompt Helpers

    private static func promptFrameName(assetType: String, defaultName: String) -> String {
        let input = NooraUI.textPrompt(
            prompt: "Figma frame name for \(assetType) (default: \(defaultName)):",
            description: "Name of the frame containing your \(assetType). Press Enter for default."
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return input.isEmpty ? defaultName : input
    }

    private static func promptOptionalText(
        question: TerminalText,
        description: TerminalText,
        inputPrompt: TerminalText
    ) -> String? {
        guard NooraUI.yesOrNoPrompt(
            question: question,
            defaultAnswer: false,
            description: description
        ) else { return nil }

        return NooraUI.textPrompt(
            prompt: inputPrompt,
            validationRules: [NonEmptyValidationRule(error: "Value cannot be empty.")]
        )
    }

    private static func promptPageName(assetType: String) -> String? {
        promptOptionalText(
            question: "Filter \(assetType) by Figma page name?",
            description: "Useful when multiple pages have frames with the same name",
            inputPrompt: "Page name:"
        )
    }

    private static func promptColorsSource(lightFileId: String) -> InitVariablesConfig? {
        let source: InitColorsSource = NooraUI.singleChoicePrompt(
            question: "How are your colors defined in Figma?",
            options: InitColorsSource.allCases,
            description: "Variables is the modern approach; Styles is the classic one"
        )

        guard source == .variables else { return nil }

        let tokensFileIdInput = NooraUI.textPrompt(
            prompt: "Variables file ID or URL (default: same as light file):",
            description: "The Figma file containing your color variables. Press Enter to use the light file ID."
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        let collectionName = NooraUI.textPrompt(
            prompt: "Variables collection name:",
            description: "The name of the variable collection in Figma (e.g., 'Primitives', 'Base collection')",
            validationRules: [NonEmptyValidationRule(error: "Collection name cannot be empty.")]
        )

        let lightModeName = NooraUI.textPrompt(
            prompt: "Light mode column name (default: Light):",
            description: "Column name for light color values. Press Enter for default."
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        let darkModeName = promptOptionalText(
            question: "Do you have a dark mode column?",
            description: "Column name for dark color values in the variables table",
            inputPrompt: "Dark mode column name:"
        )

        return InitVariablesConfig(
            tokensFileId: tokensFileIdInput.isEmpty ? lightFileId : extractFigmaFileId(from: tokensFileIdInput),
            collectionName: collectionName,
            lightModeName: lightModeName.isEmpty ? "Light" : lightModeName,
            darkModeName: darkModeName
        )
    }
}
