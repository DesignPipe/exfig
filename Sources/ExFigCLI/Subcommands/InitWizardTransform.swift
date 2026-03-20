// swiftlint:disable file_length

// MARK: - Template Transformation (Pure, Testable)

extension InitWizard {
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

        // Substitute page names
        if let iconsPage = result.iconsPageName {
            output = uncommentPageName(in: output, section: "icons", name: iconsPage)
        }
        if let imagesPage = result.imagesPageName {
            output = uncommentPageName(in: output, section: "images", name: imagesPage)
        }

        // Handle colors source: variables vs styles
        if let vars = result.variablesConfig {
            // Remove regular colors section, uncomment and populate variablesColors
            output = removeSection(from: output, matching: "colors = new Common.Colors {")
            output = uncommentVariablesColors(in: output, config: vars)
        } else if result.selectedAssetTypes.contains(.colors) {
            // Regular styles: just remove the commented variablesColors block
            output = removeCommentedVariablesColors(from: output)
        }

        // Remove unselected asset sections
        let allTypes: [InitAssetType] = [.colors, .icons, .images, .typography]
        for assetType in allTypes where !result.selectedAssetTypes.contains(assetType) {
            output = removeAssetSections(from: output, assetType: assetType)
        }

        // When colors removed entirely, also remove commented variablesColors block
        if !result.selectedAssetTypes.contains(.colors) {
            output = removeCommentedVariablesColors(from: output)
        }

        // Collapse 3+ consecutive blank lines to 2
        output = collapseBlankLines(output)

        return output
    }

    // MARK: - Line-Level Operations

    /// Remove the `darkFileId = "..."` line (and its comment) from the template.
    static func removeDarkFileIdLine(from template: String) -> String {
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
    static func substituteFrameName(in template: String, section: String, name: String) -> String {
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

    /// Uncomment `figmaPageName` within a common section and set the value.
    static func uncommentPageName(in template: String, section: String, name: String) -> String {
        let lines = template.components(separatedBy: "\n")
        var result: [String] = []
        var inSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("\(section) = new Common.") {
                inSection = true
            }

            if inSection, trimmed.hasPrefix("// figmaPageName = ") {
                let indent = String(line.prefix(while: { $0 == " " }))
                result.append("\(indent)figmaPageName = \"\(name)\"")
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

    // MARK: - Section Removal

    /// Remove all sections (common + platform) for the given asset type.
    static func removeAssetSections(from template: String, assetType: InitAssetType) -> String {
        var output = template

        for marker in commonSectionMarkers(for: assetType) {
            output = removeSection(from: output, matching: marker)
        }
        for marker in platformSectionMarkers(for: assetType) {
            output = removeSection(from: output, matching: marker)
        }

        return output
    }

    /// Remove a PKL section starting with a line matching the marker, counting braces to find the end.
    /// Also strips preceding comment lines and blank lines.
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

        // Safety: if still removing at EOF, the section was never closed — return template unchanged
        if removing {
            assertionFailure("removeSection: unclosed section for marker '\(marker)' — template may be malformed")
            return template
        }

        return result.joined(separator: "\n")
    }

    // MARK: - Variables Colors

    /// Uncomment `variablesColors` block and substitute values from wizard config.
    static func uncommentVariablesColors(
        in template: String,
        config: InitVariablesConfig
    ) -> String {
        let lines = template.components(separatedBy: "\n")
        var result: [String] = []
        var inBlock = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if !inBlock {
                if trimmed.hasPrefix("// [optional] Use variablesColors")
                    || trimmed.hasPrefix("// variablesColors = new Common.VariablesColors {")
                {
                    if trimmed.hasPrefix("// variablesColors") {
                        inBlock = true
                        result.append("  variablesColors = new Common.VariablesColors {")
                    }
                    continue
                }
                result.append(line)
            } else {
                if trimmed == "// }" {
                    result.append("  }")
                    inBlock = false
                } else if trimmed.hasPrefix("//") {
                    var uncommented = String(trimmed.dropFirst(2))
                    if uncommented.hasPrefix(" ") {
                        uncommented = String(uncommented.dropFirst())
                    }
                    uncommented = substituteVariableValue(uncommented, config: config)
                    result.append("    \(uncommented)")
                } else {
                    inBlock = false
                    result.append(line)
                }
            }
        }

        return result.joined(separator: "\n")
    }

    /// Remove commented-out `variablesColors` block.
    static func removeCommentedVariablesColors(from template: String) -> String {
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

    // MARK: - Section Markers

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

    // MARK: - Utilities

    private static func braceBalance(in line: String) -> Int {
        var balance = 0
        for char in line {
            if char == "{" { balance += 1 }
            if char == "}" { balance -= 1 }
        }
        return balance
    }

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

    private static func substituteVariableValue(_ line: String, config: InitVariablesConfig) -> String {
        var result = line
        if result.contains("tokensFileId = ") {
            result = "tokensFileId = \"\(config.tokensFileId)\""
        } else if result.contains("tokensCollectionName = ") {
            result = "tokensCollectionName = \"\(config.collectionName)\""
        } else if result.contains("lightModeName = ") {
            result = "lightModeName = \"\(config.lightModeName)\""
        } else if result.contains("darkModeName = "), let darkMode = config.darkModeName {
            result = "darkModeName = \"\(darkMode)\""
        } else if result.contains("darkModeName = "), config.darkModeName == nil {
            result = "// \(result)"
        }
        return result
    }

    static func collapseBlankLines(_ text: String) -> String {
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

// swiftlint:enable file_length
