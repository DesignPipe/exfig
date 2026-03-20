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

// MARK: - Init Wizard Result

/// Result of the interactive init wizard flow.
struct InitWizardResult {
    let platform: Platform
    let selectedAssetTypes: [InitAssetType]
    let lightFileId: String
    let darkFileId: String?
    let iconsFrameName: String?
    let imagesFrameName: String?
}

// MARK: - Init Wizard Flow

/// Interactive wizard for `exfig init` when `--platform` is not provided.
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
        let lightFileId = NooraUI.textPrompt(
            prompt: "Figma file ID (from URL: figma.com/design/<ID>/...):",
            description: "The file containing your design system assets",
            validationRules: [NonEmptyValidationRule(error: "File ID cannot be empty.")]
        )

        // 4. Dark mode file ID (optional)
        let darkFileId = promptOptionalText(
            question: "Do you have a separate dark mode file?",
            description: "If your dark colors/images are in a different Figma file",
            inputPrompt: "Dark mode file ID:"
        )

        // 5. Icons frame name (if icons selected)
        let iconsFrameName: String? = if selectedTypes.contains(.icons) {
            promptFrameName(assetType: "icons", defaultName: "Icons")
        } else {
            nil
        }

        // 6. Images frame name (if images selected)
        let imagesFrameName: String? = if selectedTypes.contains(.images) {
            promptFrameName(assetType: "images", defaultName: "Illustrations")
        } else {
            nil
        }

        return InitWizardResult(
            platform: platform,
            selectedAssetTypes: selectedTypes,
            lightFileId: lightFileId,
            darkFileId: darkFileId,
            iconsFrameName: iconsFrameName,
            imagesFrameName: imagesFrameName
        )
    }

    // MARK: - Template Transformation (Pure, Testable)

    /// Apply wizard result to a platform template, removing unselected sections and substituting values.
    static func applyResult(_ result: InitWizardResult, to template: String) -> String {
        var output = template

        // Substitute file IDs
        output = output.replacingOccurrences(of: "shPilWnVdJfo10YF12345", with: result.lightFileId)

        if let darkId = result.darkFileId {
            output = output.replacingOccurrences(of: "KfF6DnJTWHGZzC912345", with: darkId)
        } else {
            output = removeDarkFileIdLine(from: output)
        }

        // Substitute frame names
        if let iconsFrame = result.iconsFrameName {
            output = substituteFrameName(in: output, section: "icons", name: iconsFrame)
        }
        if let imagesFrame = result.imagesFrameName {
            output = substituteFrameName(in: output, section: "images", name: imagesFrame)
        }

        // Remove unselected asset sections
        let allTypes: [InitAssetType] = [.colors, .icons, .images, .typography]
        for assetType in allTypes where !result.selectedAssetTypes.contains(assetType) {
            output = removeAssetSections(from: output, assetType: assetType)
        }

        // When colors removed, also remove commented variablesColors block
        if !result.selectedAssetTypes.contains(.colors) {
            output = removeCommentedVariablesColors(from: output)
        }

        // Collapse 3+ consecutive blank lines to 2
        output = collapseBlankLines(output)

        return output
    }

    // MARK: - Private Helpers

    private static func promptFrameName(assetType: String, defaultName: String) -> String {
        let input = NooraUI.textPrompt(
            prompt: "Figma frame name for \(assetType) (default: \(defaultName)):",
            description: "Name of the frame containing your \(assetType). Press Enter for default."
        )
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

    /// Remove the `darkFileId = "..."` line (and its comment) from the template.
    private static func removeDarkFileIdLine(from template: String) -> String {
        var lines = template.components(separatedBy: "\n")
        lines.removeAll { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("darkFileId = ")
                || trimmed == "// [optional] Identifier of the file containing dark color palette and dark images."
                || trimmed == "// [optional] Identifier of the file containing dark color palette."
        }
        return lines.joined(separator: "\n")
    }

    /// Substitute the default frame name in the `figmaFrameName = "..."` line within a section.
    private static func substituteFrameName(in template: String, section: String, name: String) -> String {
        let defaultName = section == "icons" ? "Icons" : "Illustrations"
        let lines = template.components(separatedBy: "\n")
        var result: [String] = []
        var inSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("\(section) = new Common.") {
                inSection = true
            }

            if inSection, trimmed.hasPrefix("figmaFrameName = \"\(defaultName)\"") {
                result.append(line.replacingOccurrences(of: "\"\(defaultName)\"", with: "\"\(name)\""))
                inSection = false
            } else {
                result.append(line)
            }

            if inSection, trimmed == "}" {
                inSection = false
            }
        }

        return result.joined(separator: "\n")
    }

    /// Remove all sections (common + platform) for the given asset type.
    static func removeAssetSections(from template: String, assetType: InitAssetType) -> String {
        var output = template

        // Remove common section
        let commonMarkers = commonSectionMarkers(for: assetType)
        for marker in commonMarkers {
            output = removeSection(from: output, matching: marker)
        }

        // Remove platform-specific section
        let platformMarkers = platformSectionMarkers(for: assetType)
        for marker in platformMarkers {
            output = removeSection(from: output, matching: marker)
        }

        return output
    }

    /// Remove a PKL section starting with a line matching the marker, counting braces to find the end.
    static func removeSection(from template: String, matching marker: String) -> String {
        let lines = template.components(separatedBy: "\n")
        var result: [String] = []
        var braceDepth = 0
        var removing = false

        for line in lines {
            if removing {
                braceDepth += braceBalance(in: line)
                if braceDepth <= 0 { removing = false }
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.contains(marker) else {
                result.append(line)
                continue
            }

            // Start removing: strip preceding comments/blanks
            removing = true
            braceDepth = braceBalance(in: line)
            stripTrailingCommentsAndBlanks(&result)
            if braceDepth <= 0 { removing = false }
        }

        return result.joined(separator: "\n")
    }

    /// Count net brace balance ({  = +1, } = -1) in a line.
    private static func braceBalance(in line: String) -> Int {
        var balance = 0
        for char in line {
            if char == "{" { balance += 1 }
            if char == "}" { balance -= 1 }
        }
        return balance
    }

    /// Remove trailing comment lines and blank lines from the result array.
    private static func stripTrailingCommentsAndBlanks(_ lines: inout [String]) {
        while let last = lines.last {
            let trimmed = last.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") || trimmed.isEmpty {
                lines.removeLast()
            } else {
                break
            }
        }
    }

    /// Markers for common section blocks (in `common = new Common.CommonConfig`).
    private static func commonSectionMarkers(for assetType: InitAssetType) -> [String] {
        switch assetType {
        case .colors:
            ["colors = new Common.Colors {"]
        case .icons:
            ["icons = new Common.Icons {"]
        case .images:
            ["images = new Common.Images {"]
        case .typography:
            ["typography = new Common.Typography {"]
        }
    }

    /// Markers for platform-specific section blocks.
    private static func platformSectionMarkers(for assetType: InitAssetType) -> [String] {
        switch assetType {
        case .colors:
            [
                "colors = new iOS.ColorsEntry {",
                "colors = new Android.ColorsEntry {",
                "colors = new Flutter.ColorsEntry {",
                "colors = new Web.ColorsEntry {",
            ]
        case .icons:
            [
                "icons = new iOS.IconsEntry {",
                "icons = new Android.IconsEntry {",
                "icons = new Flutter.IconsEntry {",
                "icons = new Web.IconsEntry {",
            ]
        case .images:
            [
                "images = new iOS.ImagesEntry {",
                "images = new Android.ImagesEntry {",
                "images = new Flutter.ImagesEntry {",
                "images = new Web.ImagesEntry {",
            ]
        case .typography:
            [
                "typography = new iOS.Typography {",
                "typography = new Android.Typography {",
            ]
        }
    }

    /// Remove commented-out `variablesColors` block when colors are not selected.
    private static func removeCommentedVariablesColors(from template: String) -> String {
        let lines = template.components(separatedBy: "\n")
        var result: [String] = []
        var removing = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if !removing {
                if trimmed.hasPrefix("// variablesColors = new Common.VariablesColors {")
                    || trimmed
                    .hasPrefix(
                        "// [optional] Use variablesColors instead of colors to export colors from Figma Variables."
                    )
                    || trimmed
                    .hasPrefix(
                        "// [optional] Use variablesColors to export colors from Figma Variables."
                    )
                {
                    removing = true
                    continue
                }
                result.append(line)
            } else {
                // Keep removing commented lines until we find a non-comment line
                if trimmed.hasPrefix("//") {
                    continue
                } else {
                    removing = false
                    result.append(line)
                }
            }
        }

        return result.joined(separator: "\n")
    }

    /// Collapse 3+ consecutive blank lines into 2.
    private static func collapseBlankLines(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var consecutiveBlanks = 0

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                consecutiveBlanks += 1
                if consecutiveBlanks <= 2 {
                    result.append(line)
                }
            } else {
                consecutiveBlanks = 0
                result.append(line)
            }
        }

        return result.joined(separator: "\n")
    }
}
