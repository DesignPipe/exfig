import ExFigConfig
import ExFigCore
import FigmaAPI
import Foundation

/// When suffixDarkMode is configured, checks that each light component has a matching dark pair.
/// Only checks components within frames configured for export, not all components in the file.
struct DarkModeSuffixRule: LintRule {
    let id = "dark-mode-suffix"
    let name = "Dark mode suffix pairs"
    let description = "With suffixDarkMode, each light component needs a matching dark pair"
    let severity: LintSeverity = .warning

    func check(context: LintContext) async throws -> [LintDiagnostic] {
        let config = context.config
        var diagnostics: [LintDiagnostic] = []

        let suffix: String
        if let sdm = config.common?.icons?.suffixDarkMode {
            suffix = sdm.suffix
        } else if let sdm = config.common?.images?.suffixDarkMode {
            suffix = sdm.suffix
        } else {
            return []
        }

        let defaultFileId = config.figma?.lightFileId ?? ""
        guard !defaultFileId.isEmpty else { return [] }

        // Collect configured frame names to filter components
        let configuredFrames = collectConfiguredFrames(from: config)

        let components: [Component]
        do {
            components = try await context.client.request(ComponentsEndpoint(fileId: defaultFileId))
        } catch {
            return []
        }

        // Only check components in configured frames
        let relevant = components.filter { comp in
            guard let frameName = comp.containingFrame.name else { return false }
            return configuredFrames.contains(frameName)
        }

        let relevantNames = Set(relevant.map(\.name))

        for component in relevant {
            if component.name.hasSuffix(suffix) { continue }

            let expectedDark = component.name + suffix
            if !relevantNames.contains(expectedDark) {
                diagnostics.append(LintDiagnostic(
                    ruleId: id,
                    ruleName: name,
                    severity: .warning,
                    message: "'\(component.name)' has no dark pair '\(expectedDark)'",
                    componentName: component.name,
                    nodeId: component.nodeId,
                    suggestion: "Create a component named '\(expectedDark)'"
                ))
            }
        }

        return diagnostics
    }

    private func collectConfiguredFrames(from config: ExFig.ModuleImpl) -> Set<String> {
        var frames: Set<String> = []

        func add(_ entries: [some Common_FrameSource]?) {
            for entry in entries ?? [] {
                if let frame = entry.figmaFrameName { frames.insert(frame) }
            }
        }

        if let ios = config.ios {
            add(ios.icons)
            add(ios.images)
        }
        if let android = config.android {
            add(android.icons)
            add(android.images)
        }
        if let flutter = config.flutter {
            add(flutter.icons)
            add(flutter.images)
        }
        if let web = config.web {
            add(web.icons)
        }

        return frames
    }
}
