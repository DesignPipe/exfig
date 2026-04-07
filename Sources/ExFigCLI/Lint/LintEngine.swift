import Foundation

/// Callback for reporting lint progress with a displayable message string.
typealias LintProgressCallback = @Sendable (String) -> Void

/// Engine that runs lint rules against a PKL configuration.
struct LintEngine {
    /// All registered lint rules.
    let rules: [any LintRule]

    /// Run all applicable rules (or filtered subset) and return diagnostics.
    func run(
        context: LintContext,
        ruleFilter: Set<String>? = nil,
        minSeverity: LintSeverity = .info,
        onProgress: LintProgressCallback? = nil
    ) async throws -> [LintDiagnostic] {
        let applicableRules = rules.filter { rule in
            if let filter = ruleFilter, !filter.contains(rule.id) {
                return false
            }
            return rule.severity >= minSeverity
        }

        var allDiagnostics: [LintDiagnostic] = []
        let total = applicableRules.count

        for (index, rule) in applicableRules.enumerated() {
            onProgress?("Checking \(rule.name)... (\(index + 1)/\(total))")

            do {
                let diagnostics = try await rule.check(context: context)
                allDiagnostics.append(contentsOf: diagnostics)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                allDiagnostics.append(LintDiagnostic(
                    ruleId: rule.id,
                    ruleName: rule.name,
                    severity: .error,
                    message: "Rule check failed: \(error.localizedDescription)",
                    componentName: nil,
                    nodeId: nil,
                    suggestion: "Check FIGMA_PERSONAL_TOKEN and network connectivity"
                ))
            }
        }

        return allDiagnostics
    }
}

extension LintEngine {
    /// Default engine with all built-in rules.
    static let `default` = LintEngine(rules: [
        FramePageMatchRule(),
        NamingConventionRule(),
        ComponentNotFrameRule(),
        DeletedVariablesRule(),
        DuplicateComponentNamesRule(),
        AliasChainIntegrityRule(),
        DarkModeVariablesRule(),
        DarkModeSuffixRule(),
        PathDataLengthRule(),
        InvalidRTLVariantValueRule(),
    ])
}
