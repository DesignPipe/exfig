import ExFigConfig
import ExFigCore
import FigmaAPI
import Foundation

/// Checks that all variable alias chains resolve successfully (no broken refs, depth <= 10).
struct AliasChainIntegrityRule: LintRule {
    let id = "alias-chain-integrity"
    let name = "Alias chain integrity"
    let description = "All variable alias chains must resolve without broken references"
    let severity: LintSeverity = .error

    private let maxDepth = 10

    func check(context: LintContext) async throws -> [LintDiagnostic] {
        let config = context.config
        let fileId = config.figma?.lightFileId ?? ""
        guard !fileId.isEmpty else { return [] }

        let variables: VariablesMeta
        do {
            variables = try await context.client.request(VariablesEndpoint(fileId: fileId))
        } catch {
            return []
        }

        var diagnostics: [LintDiagnostic] = []

        for (variableId, variable) in variables.variables {
            if variable.deletedButReferenced == true { continue }

            for (modeId, value) in variable.valuesByMode {
                let result = resolveChain(
                    value: value,
                    variables: variables.variables,
                    visited: [variableId],
                    depth: 0
                )

                switch result {
                case .resolved:
                    break
                case let .broken(targetId):
                    diagnostics.append(LintDiagnostic(
                        ruleId: id,
                        ruleName: name,
                        severity: .error,
                        message: "'\(variable.name)' mode '\(modeId)' refs non-existent '\(targetId)'",
                        componentName: variable.name,
                        nodeId: variableId,
                        suggestion: "Fix or remove the alias reference"
                    ))
                case .circular:
                    diagnostics.append(LintDiagnostic(
                        ruleId: id,
                        ruleName: name,
                        severity: .error,
                        message: "'\(variable.name)' has a circular alias chain",
                        componentName: variable.name,
                        nodeId: variableId,
                        suggestion: "Break the circular reference"
                    ))
                case .tooDeep:
                    diagnostics.append(LintDiagnostic(
                        ruleId: id,
                        ruleName: name,
                        severity: .warning,
                        message: "'\(variable.name)' alias chain exceeds depth \(maxDepth)",
                        componentName: variable.name,
                        nodeId: variableId,
                        suggestion: "Simplify the alias chain"
                    ))
                }
            }
        }

        return diagnostics
    }

    // MARK: - Chain Resolution

    private enum ChainResult {
        case resolved
        case broken(targetId: String)
        case circular
        case tooDeep
    }

    /// Cross-file variable IDs have a long hash before the "/" separator,
    /// e.g., "VariableID:806fcc6a84cf048f0a06837634440ecad91622fe/3556:423".
    /// Local variable IDs are short like "VariableID:3556:423" or just "3556:423".
    private func isCrossFileReference(_ id: String) -> Bool {
        // Strip "VariableID:" prefix if present
        let raw = id.hasPrefix("VariableID:") ? String(id.dropFirst("VariableID:".count)) : id
        // Cross-file IDs have a 40-char hex hash before "/"
        guard let slashIndex = raw.firstIndex(of: "/") else { return false }
        let prefix = raw[raw.startIndex ..< slashIndex]
        return prefix.count >= 32 && prefix.allSatisfy(\.isHexDigit)
    }

    private func resolveChain(
        value: ValuesByMode,
        variables: [String: VariableValue],
        visited: Set<String>,
        depth: Int
    ) -> ChainResult {
        guard depth < maxDepth else { return .tooDeep }

        // Check if value is an alias
        guard case let .variableAlias(alias) = value else {
            return .resolved // Primitive value (color, string, number, boolean)
        }

        let aliasId = alias.id

        if visited.contains(aliasId) {
            return .circular
        }

        guard let target = variables[aliasId] else {
            // Cross-file alias: variable IDs containing "/" with a long hash prefix
            // (e.g., "VariableID:806fcc6a.../3556:423") are external library references.
            // These can't be validated within the local file — treat as resolved.
            if isCrossFileReference(aliasId) {
                return .resolved
            }
            return .broken(targetId: aliasId)
        }

        // Follow the chain — use first available mode value
        guard let nextValue = target.valuesByMode.values.first else {
            return .resolved
        }

        var newVisited = visited
        newVisited.insert(aliasId)
        return resolveChain(
            value: nextValue,
            variables: variables,
            visited: newVisited,
            depth: depth + 1
        )
    }
}
