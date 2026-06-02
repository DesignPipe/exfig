import ArgumentParser
import ExFigConfig
import ExFigCore
import FigmaAPI
import Foundation

/// Severity level for lint diagnostics.
enum LintSeverity: String, CaseIterable, Codable, Comparable, ExpressibleByArgument {
    case error
    case warning
    case info

    static func < (lhs: LintSeverity, rhs: LintSeverity) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .error: 2
        case .warning: 1
        case .info: 0
        }
    }
}

/// Output format for lint results.
enum LintOutputFormat: String, ExpressibleByArgument {
    case text
    case json
}

/// A single finding from a lint rule.
struct LintDiagnostic: Codable {
    let ruleId: String
    let ruleName: String
    let severity: LintSeverity
    let message: String
    let componentName: String?
    let nodeId: String?
    let suggestion: String?
}

/// Caches Figma API responses across lint rules to avoid duplicate requests.
actor LintDataCache {
    private var componentsCache: [String: [Component]] = [:]
    private var variablesCache: [String: VariablesMeta] = [:]

    func components(for fileId: String, client: any FigmaAPI.Client) async throws -> [Component] {
        if let cached = componentsCache[fileId] { return cached }
        let result = try await client.request(ComponentsEndpoint(fileId: fileId))
        componentsCache[fileId] = result
        return result
    }

    func variables(for fileId: String, client: any FigmaAPI.Client) async throws -> VariablesMeta {
        if let cached = variablesCache[fileId] { return cached }
        let result = try await client.request(VariablesEndpoint(fileId: fileId))
        variablesCache[fileId] = result
        return result
    }
}

/// Context provided to each lint rule for checking.
struct LintContext {
    /// The resolved PKL configuration.
    let config: ExFig.ModuleImpl
    /// Optional lint-only overlay configuration.
    let lintConfig: ExFigConfig.Lint.ModuleImpl?
    /// Figma API client.
    let client: any FigmaAPI.Client
    /// Shared cache for Figma API responses across rules.
    let cache: LintDataCache
    /// Terminal UI for progress reporting.
    let ui: TerminalUI
}

/// Protocol for lint rules.
protocol LintRule: Sendable {
    /// Unique rule identifier (kebab-case).
    var id: String { get }
    /// Human-readable rule name.
    var name: String { get }
    /// Description of what this rule checks.
    var description: String { get }
    /// Default severity.
    var severity: LintSeverity { get }

    /// Run the check and return diagnostics (empty = all good).
    func check(context: LintContext) async throws -> [LintDiagnostic]
}

extension LintRule {
    /// Create a diagnostic pre-filled with this rule's metadata.
    func diagnostic(
        severity: LintSeverity? = nil,
        message: String,
        componentName: String? = nil,
        nodeId: String? = nil,
        suggestion: String? = nil
    ) -> LintDiagnostic {
        LintDiagnostic(
            ruleId: id,
            ruleName: name,
            severity: severity ?? self.severity,
            message: message,
            componentName: componentName,
            nodeId: nodeId,
            suggestion: suggestion
        )
    }
}
