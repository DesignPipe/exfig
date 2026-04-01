import ExFigCore
import Foundation
import Noora

/// Formats and outputs lint results.
struct LintReporter {
    let format: LintOutputFormat
    let useColors: Bool

    func report(diagnostics: [LintDiagnostic], ui: TerminalUI) throws {
        switch format {
        case .text:
            reportText(diagnostics: diagnostics, ui: ui)
        case .json:
            try reportJSON(diagnostics: diagnostics, ui: ui)
        }
    }

    // MARK: - Text Output

    // swiftlint:disable function_body_length
    private func reportText(diagnostics: [LintDiagnostic], ui: TerminalUI) {
        if diagnostics.isEmpty {
            ui.success("All lint checks passed")
            return
        }

        let errors = diagnostics.filter { $0.severity == .error }
        let warnings = diagnostics.filter { $0.severity == .warning }

        // Summary header
        ui.info("")
        var summaryParts: [String] = []
        if !errors.isEmpty {
            summaryParts.append(NooraUI.format(.danger("\(errors.count) error(s)")))
        }
        if !warnings.isEmpty {
            summaryParts.append(NooraUI.format(.accent("\(warnings.count) warning(s)")))
        }
        ui.info("  \(summaryParts.joined(separator: "  "))")
        ui.info("")

        let grouped = Dictionary(grouping: diagnostics) { $0.ruleId }
        let sortedGroups = grouped.sorted { lhs, rhs in
            let lSev = lhs.value[0].severity
            let rSev = rhs.value[0].severity
            if lSev != rSev { return lSev > rSev }
            return lhs.key < rhs.key
        }

        for (_, items) in sortedGroups {
            let first = items[0]
            let icon = severityIcon(first.severity)
            let countStr = useColors
                ? NooraUI.format(.muted("(\(items.count))"))
                : "(\(items.count))"

            ui.info("  \(icon) \(first.ruleName) \(countStr)")

            let tableItems = items.prefix(8)
            let maxNameLen = min(
                tableItems.compactMap(\.componentName).map(\.count).max() ?? 10,
                30
            )

            for diag in tableItems {
                let name = diag.componentName ?? diag.nodeId ?? "?"
                let truncated = name.count > 30 ? String(name.prefix(27)) + "..." : name
                let padded = truncated.padding(toLength: max(maxNameLen, truncated.count), withPad: " ", startingAt: 0)
                let nameStr = useColors ? NooraUI.format(.primary(padded)) : padded
                let msgStr = useColors ? NooraUI.format(.muted(diag.message)) : diag.message
                ui.info("    \(nameStr)  \(msgStr)")
            }

            if items.count > 8 {
                let moreStr = useColors
                    ? NooraUI.format(.muted("... +\(items.count - 8) more"))
                    : "... +\(items.count - 8) more"
                ui.info("    \(moreStr)")
            }
            ui.info("")
        }
    }

    // swiftlint:enable function_body_length

    private func severityIcon(_ severity: LintSeverity) -> String {
        switch severity {
        case .error: useColors ? NooraUI.format(.danger("✗")) : "✗"
        case .warning: useColors ? NooraUI.format(.accent("⚠")) : "⚠"
        case .info: useColors ? NooraUI.format(.muted("ℹ")) : "ℹ"
        }
    }

    // MARK: - JSON Output

    private func reportJSON(diagnostics: [LintDiagnostic], ui: TerminalUI) throws {
        let report = LintReport(
            diagnosticsCount: diagnostics.count,
            errorsCount: diagnostics.filter { $0.severity == .error }.count,
            warningsCount: diagnostics.filter { $0.severity == .warning }.count,
            diagnostics: diagnostics
        )
        let data = try JSONCodec.encode(report)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ExFigError.custom(errorString: "Failed to encode lint report as UTF-8")
        }
        // Write directly to stdout — ui.info() is suppressed in quiet mode
        // which is force-enabled for JSON format to keep stdout clean
        TerminalOutputManager.shared.print(jsonString)
    }
}

/// Top-level JSON report structure.
private struct LintReport: Codable {
    let diagnosticsCount: Int
    let errorsCount: Int
    let warningsCount: Int
    let diagnostics: [LintDiagnostic]
}
