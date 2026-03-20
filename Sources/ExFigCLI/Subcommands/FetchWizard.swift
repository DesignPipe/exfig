import ExFigCore
import Noora

// MARK: - Wizard Display Types

/// Platform choice for the wizard (display-friendly wrapper for Noora prompts).
enum WizardPlatform: String, CaseIterable, CustomStringConvertible, Equatable {
    case ios = "iOS"
    case android = "Android"
    case flutter = "Flutter"
    case web = "Web"

    var description: String {
        rawValue
    }

    /// Convert to ExFigCore `Platform`.
    var asPlatform: Platform {
        switch self {
        case .ios: .ios
        case .android: .android
        case .flutter: .flutter
        case .web: .web
        }
    }
}

/// Asset type choice for the wizard.
enum WizardAssetType: String, CaseIterable, CustomStringConvertible, Equatable {
    case icons = "Icons"
    case illustrations = "Illustrations / Images"

    var description: String {
        rawValue
    }

    /// Default Figma frame name for this asset type.
    var defaultFrameName: String {
        switch self {
        case .icons: "Icons"
        case .illustrations: "Illustrations"
        }
    }

    /// Default output directory for this asset type.
    var defaultOutputPath: String {
        switch self {
        case .icons: "./icons"
        case .illustrations: "./images"
        }
    }
}

// MARK: - Platform Defaults

/// Smart defaults per platform and asset type.
struct PlatformDefaults {
    let format: ImageFormat
    let scale: Double?
    let nameStyle: NameStyle

    static func forPlatform(_ platform: WizardPlatform, assetType: WizardAssetType) -> PlatformDefaults {
        switch (platform, assetType) {
        case (.ios, .icons):
            PlatformDefaults(format: .svg, scale: nil, nameStyle: .camelCase)
        case (.ios, .illustrations):
            PlatformDefaults(format: .png, scale: 3.0, nameStyle: .camelCase)
        case (.android, .icons):
            PlatformDefaults(format: .svg, scale: nil, nameStyle: .snakeCase)
        case (.android, .illustrations):
            PlatformDefaults(format: .webp, scale: 4.0, nameStyle: .snakeCase)
        case (.flutter, .icons):
            PlatformDefaults(format: .svg, scale: nil, nameStyle: .snakeCase)
        case (.flutter, .illustrations):
            PlatformDefaults(format: .png, scale: 3.0, nameStyle: .snakeCase)
        case (.web, .icons):
            PlatformDefaults(format: .svg, scale: nil, nameStyle: .kebabCase)
        case (.web, .illustrations):
            PlatformDefaults(format: .svg, scale: nil, nameStyle: .kebabCase)
        }
    }
}

// MARK: - Wizard Result

/// Result of the interactive wizard flow.
struct FetchWizardResult {
    let fileId: String
    let frameName: String
    let pageName: String?
    let outputPath: String
    let format: ImageFormat
    let scale: Double?
    let nameStyle: NameStyle?
    let filter: String?
}

// MARK: - Wizard Flow

/// Interactive wizard for `exfig fetch` when required options are missing.
enum FetchWizard {
    /// Sorted format options with recommended format first.
    static func sortedFormats(recommended: ImageFormat) -> [ImageFormat] {
        var formats = ImageFormat.allCases
        formats.removeAll { $0 == recommended }
        formats.insert(recommended, at: 0)
        return formats
    }

    /// Run the interactive wizard and return populated options.
    static func run() -> FetchWizardResult {
        // 1–3: Core choices (file, asset type, platform)
        let fileId = NooraUI.textPrompt(
            title: "Figma Export Wizard",
            prompt: "Figma file ID (from URL: figma.com/file/<ID>/...):",
            description: "You can find it in the Figma file URL",
            validationRules: [NonEmptyValidationRule(error: "File ID cannot be empty.")]
        )

        let assetType: WizardAssetType = NooraUI.singleChoicePrompt(
            question: "What are you exporting?",
            options: WizardAssetType.allCases,
            description: "Icons are typically vector, illustrations can be raster or vector"
        )

        let platform: WizardPlatform = NooraUI.singleChoicePrompt(
            question: "Target platform:",
            options: WizardPlatform.allCases,
            description: "Affects default format, scale, and naming style"
        )

        let defaults = PlatformDefaults.forPlatform(platform, assetType: assetType)

        // 4–8: Details (page, frame, format, output, filter)
        return promptDetails(assetType: assetType, platform: platform, defaults: defaults, fileId: fileId)
    }

    // swiftlint:disable function_parameter_count
    private static func promptDetails(
        assetType: WizardAssetType,
        platform: WizardPlatform,
        defaults: PlatformDefaults,
        fileId: String
    ) -> FetchWizardResult {
        // swiftlint:enable function_parameter_count

        let pageName = promptOptionalText(
            question: "Filter by Figma page name?",
            description: "Useful when multiple pages have frames with the same name",
            inputPrompt: "Page name:"
        )

        let defaultFrame = assetType.defaultFrameName
        let frameInput = NooraUI.textPrompt(
            prompt: "Figma frame name (default: \(defaultFrame)):",
            description: "Name of the frame containing your assets. Press Enter for default."
        )
        let frameName = frameInput.isEmpty ? defaultFrame : frameInput

        let sortedFormats = sortedFormats(recommended: defaults.format)
        let format: ImageFormat = NooraUI.singleChoicePrompt(
            question: "Output format:",
            options: sortedFormats,
            description: "\(defaults.format.description) is recommended for \(platform) \(assetType)"
        )

        let defaultOutput = assetType.defaultOutputPath
        let outputInput = NooraUI.textPrompt(
            prompt: "Output directory (default: \(defaultOutput)):",
            description: "Where to save exported assets. Press Enter for default."
        )
        let outputPath = outputInput.isEmpty ? defaultOutput : outputInput

        let filter = promptOptionalText(
            question: "Add a name filter?",
            description: "Filter assets by glob pattern (e.g., 'icon/*' or 'logo, banner')",
            inputPrompt: "Filter pattern:"
        )

        return FetchWizardResult(
            fileId: fileId,
            frameName: frameName,
            pageName: pageName,
            outputPath: outputPath,
            format: format,
            scale: defaults.scale,
            nameStyle: defaults.nameStyle,
            filter: filter
        )
    }

    /// Ask a yes/no question; if yes, prompt for text. Returns nil if user says no.
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
}
