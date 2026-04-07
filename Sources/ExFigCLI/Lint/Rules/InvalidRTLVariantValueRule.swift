import ExFigConfig
import ExFigCore
import FigmaAPI
import Foundation

/// Checks that RTL variant property values match the configured `rtlActiveValues`
/// and their known counterparts.
///
/// When `rtlActiveValues` is `["On"]` (default), valid values are `Off` and `On`.
/// When set to `["true"]`, valid values are `false` and `true`.
/// This prevents silent incorrect behavior where RTL variants with unrecognized
/// values are exported as regular icons instead of being skipped.
struct InvalidRTLVariantValueRule: LintRule {
    let id = "invalid-rtl-variant-value"
    let name = "RTL variant property values"
    let description = "RTL variant values must match configured rtlActiveValues and their counterparts"
    let severity: LintSeverity = .error

    /// Known boolean-like value pairs (inactive, active).
    static let knownPairs: [(String, String)] = [
        ("Off", "On"),
        ("off", "on"),
        ("false", "true"),
        ("False", "True"),
        ("No", "Yes"),
        ("no", "yes"),
        ("0", "1"),
    ]

    /// Builds the set of valid values from configured active values.
    /// For each active value, includes its known counterpart.
    static func validValues(for activeValues: [String]) -> Set<String> {
        var result = Set(activeValues)
        for active in activeValues {
            for (inactive, knownActive) in knownPairs {
                if knownActive == active {
                    result.insert(inactive)
                } else if inactive == active {
                    result.insert(knownActive)
                }
            }
        }
        return result
    }

    func check(context: LintContext) async throws -> [LintDiagnostic] {
        let config = context.config
        let defaultFileId = config.figma?.lightFileId ?? ""

        let entries = collectEntries(from: config, defaultFileId: defaultFileId)
        guard !entries.isEmpty else { return [] }

        let grouped = Dictionary(grouping: entries) { $0.fileId }

        return try await withThrowingTaskGroup(of: [LintDiagnostic].self) { group in
            for (fileId, fileEntries) in grouped {
                group.addTask {
                    try await checkFileEntries(fileEntries, fileId: fileId, context: context)
                }
            }
            var allDiagnostics: [LintDiagnostic] = []
            for try await diagnostics in group {
                allDiagnostics.append(contentsOf: diagnostics)
            }
            return allDiagnostics
        }
    }

    // MARK: - Per-File Check

    private func checkFileEntries(
        _ entries: [IconEntry],
        fileId: String,
        context: LintContext
    ) async throws -> [LintDiagnostic] {
        guard !fileId.isEmpty else {
            return [diagnostic(
                message: "No figma.lightFileId configured — skipping RTL variant value check",
                suggestion: "Set figma.lightFileId in your PKL config"
            )]
        }

        let components: [Component]
        do {
            components = try await context.cache.components(for: fileId, client: context.client)
        } catch {
            return [diagnostic(
                severity: .error,
                message: "Cannot fetch components for file '\(fileId)': \(error.localizedDescription)",
                suggestion: "Check FIGMA_PERSONAL_TOKEN and file permissions"
            )]
        }

        return validateRTLValues(components: components, entries: entries)
    }

    // MARK: - Validation

    /// Validates RTL variant property values — internal for testability.
    func validateRTLValues(
        components: [Component],
        entries: [IconEntry]
    ) -> [LintDiagnostic] {
        var diagnostics: [LintDiagnostic] = []
        let entryValidValues = entries.map { Self.validValues(for: $0.rtlActiveValues) }

        for comp in components {
            guard comp.containingFrame.containingComponentSet != nil else { continue }

            for (index, entry) in entries.enumerated() {
                guard matchesEntry(comp, entry) else { continue }
                guard let value = comp.rtlVariantValue(propertyName: entry.rtlProperty) else { continue }

                if !entryValidValues[index].contains(value) {
                    let iconName = comp.iconName
                    let expected = entry.rtlActiveValues.sorted().joined(separator: "' or '")
                    diagnostics.append(diagnostic(
                        message: "RTL variant '\(iconName) (\(entry.rtlProperty)=\(value))' "
                            + "uses unrecognized value '\(value)' — "
                            + "expected values matching rtlActiveValues: '\(expected)' or their counterparts",
                        componentName: iconName,
                        nodeId: comp.nodeId,
                        suggestion: "Either rename '\(entry.rtlProperty)=\(value)' in Figma, "
                            + "or add '\(value)' to rtlActiveValues in your PKL config"
                    ))
                }
                break
            }
        }

        return diagnostics
    }

    // MARK: - Helpers

    private func matchesEntry(_ comp: Component, _ entry: IconEntry) -> Bool {
        if let page = entry.pageName, comp.containingFrame.pageName != page { return false }
        if let frame = entry.frameName, comp.containingFrame.name != frame { return false }
        return true
    }

    // MARK: - Types

    struct IconEntry {
        let fileId: String
        let frameName: String?
        let pageName: String?
        let rtlProperty: String
        let rtlActiveValues: [String]
    }

    // MARK: - Entry Collection

    private func collectEntries(
        from config: ExFig.ModuleImpl,
        defaultFileId: String
    ) -> [IconEntry] {
        var entries: [IconEntry] = []

        let commonIconsFrame = config.common?.icons?.figmaFrameName ?? "Icons"
        let commonIconsPage = config.common?.icons?.figmaPageName
        let commonImagesFrame = config.common?.images?.figmaFrameName ?? "Illustrations"
        let commonImagesPage = config.common?.images?.figmaPageName

        func addEntries(
            _ sources: [some Common_FrameSource]?,
            defaultFrame: String,
            defaultPage: String?
        ) {
            for entry in sources ?? [] {
                guard let rtlProperty = entry.rtlProperty, !rtlProperty.isEmpty else { continue }
                entries.append(IconEntry(
                    fileId: entry.figmaFileId ?? defaultFileId,
                    frameName: entry.figmaFrameName ?? defaultFrame,
                    pageName: entry.figmaPageName ?? defaultPage,
                    rtlProperty: rtlProperty,
                    rtlActiveValues: entry.rtlActiveValues ?? ["On"]
                ))
            }
        }

        if let ios = config.ios {
            addEntries(ios.icons, defaultFrame: commonIconsFrame, defaultPage: commonIconsPage)
            addEntries(ios.images, defaultFrame: commonImagesFrame, defaultPage: commonImagesPage)
        }
        if let android = config.android {
            addEntries(android.icons, defaultFrame: commonIconsFrame, defaultPage: commonIconsPage)
            addEntries(android.images, defaultFrame: commonImagesFrame, defaultPage: commonImagesPage)
        }
        if let flutter = config.flutter {
            addEntries(flutter.icons, defaultFrame: commonIconsFrame, defaultPage: commonIconsPage)
            addEntries(flutter.images, defaultFrame: commonImagesFrame, defaultPage: commonImagesPage)
        }
        if let web = config.web {
            addEntries(web.icons, defaultFrame: commonIconsFrame, defaultPage: commonIconsPage)
            addEntries(web.images, defaultFrame: commonImagesFrame, defaultPage: commonImagesPage)
        }

        var seen = Set<String>()
        return entries.filter { entry in
            let activeKey = entry.rtlActiveValues.sorted().joined(separator: ",")
            let key = [
                entry.fileId, entry.frameName ?? "", entry.pageName ?? "",
                entry.rtlProperty, activeKey,
            ].joined(separator: "|")
            return seen.insert(key).inserted
        }
    }
}
