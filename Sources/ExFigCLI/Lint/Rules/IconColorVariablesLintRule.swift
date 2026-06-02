// swiftlint:disable file_length type_body_length
import ExFigConfig
import ExFigCore
import FigmaAPI
import Foundation

/// Checks that configured icon groups use the expected Figma Variables.
///
/// For every opaque, non-image fill and stroke, the rule verifies that — if the paint is
/// bound to a Figma Variable — the bound variable is one of the configured allowed names.
/// Binding itself is opt-in: unbound paints are only flagged when the policy sets
/// `requireBound = true`.
struct IconColorVariablesLintRule: LintRule {
    let id = "icon-color-variables"
    let name = "Icon color variables"
    let description = "Icon fills and strokes use the configured Figma Variables (binding optional via requireBound)"
    let severity: LintSeverity = .error

    /// Maximum number of components to fetch per entry. NodesEndpoint is rate-limited,
    /// so large frames are sampled (mirrors `DarkModeVariablesRule`).
    static let sampleLimit = 50

    func check(context: LintContext) async throws -> [LintDiagnostic] {
        guard let rawPolicies = context.lintConfig?.iconColorVariables, !rawPolicies.isEmpty else {
            return []
        }

        let defaultFileId = context.config.figma?.lightFileId ?? ""
        let iconEntries = collectIconEntries(from: context.config, defaultFileId: defaultFileId)
        var diagnostics: [LintDiagnostic] = []

        for rawPolicy in rawPolicies {
            let matchedEntries = iconEntries.filter { $0.matches(rawPolicy.selector) }
            guard !matchedEntries.isEmpty else {
                // A selector that matches nothing is a lint-config mistake, not a design
                // violation — warn rather than fail the run with an error.
                diagnostics.append(diagnostic(
                    severity: .warning,
                    message: "No icon entries match icon-color-variables selector",
                    suggestion: "Check figmaFileId, figmaPageName, figmaFrameName, or assetsFolder in lint config"
                ))
                continue
            }

            guard let policy = IconColorPolicy(rawPolicy) else {
                // An empty allow-list is a config mistake, not a design violation.
                diagnostics.append(diagnostic(
                    severity: .warning,
                    message: "icon-color-variables policy has no expected variables",
                    suggestion: "Set paints, fills, or strokes in lint config"
                ))
                continue
            }

            try await checkPolicy(
                policy,
                entries: matchedEntries,
                context: context,
                diagnostics: &diagnostics
            )
        }

        return diagnostics
    }

    // MARK: - Policy Check

    private func checkPolicy(
        _ policy: IconColorPolicy,
        entries: [IconEntry],
        context: LintContext,
        diagnostics: inout [LintDiagnostic]
    ) async throws {
        // Surface empty-fileId entries up front with a precise, actionable message so the
        // failure is not masked by variable-source resolution failing later.
        let usableEntries = entries.filter { entry in
            guard entry.fileId.isEmpty else { return true }
            diagnostics.append(diagnostic(
                message: "No Figma file ID configured for icon entry",
                suggestion: "Set figma.lightFileId or entry figmaFileId in the main config"
            ))
            return false
        }
        guard !usableEntries.isEmpty else { return }

        // Build the variable-name index from every reachable candidate file. Binding
        // validation runs against this merged index regardless of whether the expected
        // variables were found, so a degraded fetch never silently skips the check.
        let resolution = await resolveVariableNames(
            for: policy,
            entries: usableEntries,
            context: context,
            diagnostics: &diagnostics
        )

        // Warn (do not block) when the expected variables are absent everywhere reachable —
        // this is config drift (e.g. a renamed variable), distinct from a design violation.
        if !resolution.expectedNamesFound, resolution.reachedAtLeastOneFile {
            let expected = policy.expectedNames.sorted().joined(separator: ", ")
            diagnostics.append(diagnostic(
                severity: .warning,
                message: "Expected icon color variables not found in any reachable file: \(expected)",
                suggestion: """
                Ensure these variables are present in common.variablesColors, platform colors, \
                variablesDarkMode, or set variablesFileId in lint config
                """
            ))
        }

        for entry in usableEntries {
            try await checkEntry(
                entry,
                policy: policy,
                variableNamesById: resolution.namesById,
                context: context,
                diagnostics: &diagnostics
            )
        }
    }

    private func checkEntry(
        _ entry: IconEntry,
        policy: IconColorPolicy,
        variableNamesById: [String: String],
        context: LintContext,
        diagnostics: inout [LintDiagnostic]
    ) async throws {
        let components: [Component]
        do {
            components = try await context.cache.components(for: entry.fileId, client: context.client)
        } catch {
            diagnostics.append(diagnostic(
                message: "Cannot fetch components for file '\(entry.fileId)': \(error.localizedDescription)",
                suggestion: "Check FIGMA_PERSONAL_TOKEN and file permissions"
            ))
            return
        }

        let relevant = components.filter { component in
            if let pageName = entry.pageName, component.containingFrame.pageName != pageName { return false }
            if let frameName = entry.frameName, component.containingFrame.name != frameName { return false }
            if component.containingFrame.containingComponentSet != nil, component.name.contains("RTL=") { return false }
            return true
        }
        // A selector-matched entry whose page/frame filter matches no component means the
        // configured frame/page does not exist (or was renamed). Surface it instead of
        // silently reporting clean — this rule can be run in isolation via --rules.
        guard !relevant.isEmpty else {
            diagnostics.append(diagnostic(
                severity: .warning,
                message: "No components matched page/frame for icon entry in file '\(entry.fileId)'",
                suggestion: "Check figmaPageName/figmaFrameName in the main config — nothing was validated"
            ))
            return
        }

        // Sample to avoid excessive API calls (NodesEndpoint is rate-limited).
        let sampled = Array(relevant.prefix(Self.sampleLimit))
        if relevant.count > Self.sampleLimit {
            diagnostics.append(diagnostic(
                severity: .info,
                message: "Checked \(Self.sampleLimit) of \(relevant.count) components (sampling for API limits)"
            ))
        }

        let nodeIds = sampled.map(\.nodeId)
        let nodes: [NodeId: Node]
        do {
            nodes = try await context.client.request(NodesEndpoint(fileId: entry.fileId, nodeIds: nodeIds))
        } catch {
            diagnostics.append(diagnostic(
                message: "Cannot fetch nodes for file '\(entry.fileId)': \(error.localizedDescription)",
                suggestion: "Check FIGMA_PERSONAL_TOKEN and file permissions"
            ))
            return
        }

        let iconNamesByNodeId = Dictionary(
            sampled.map { ($0.nodeId, $0.iconName) },
            uniquingKeysWith: { first, _ in first }
        )
        for (nodeId, node) in nodes {
            let componentName = iconNamesByNodeId[nodeId] ?? node.document.name
            checkChildren(
                node.document.children ?? [],
                componentName: componentName,
                policy: policy,
                variableNamesById: variableNamesById,
                diagnostics: &diagnostics
            )
        }
    }

    // MARK: - Paint Validation

    private struct PaintCheckContext {
        let componentName: String
        let policy: IconColorPolicy
        let variableNamesById: [String: String]
    }

    private func checkChildren(
        _ children: [Document],
        componentName: String,
        policy: IconColorPolicy,
        variableNamesById: [String: String],
        diagnostics: inout [LintDiagnostic]
    ) {
        for child in children {
            checkNode(
                child,
                componentName: componentName,
                policy: policy,
                variableNamesById: variableNamesById,
                diagnostics: &diagnostics
            )
        }
    }

    private func checkNode(
        _ node: Document,
        componentName: String,
        policy: IconColorPolicy,
        variableNamesById: [String: String],
        diagnostics: inout [LintDiagnostic]
    ) {
        // Skip fully transparent layers and their subtrees — they are not visible output.
        guard node.opacity != 0 else { return }

        for fill in node.fills {
            checkPaint(
                fill,
                role: .fill,
                node: node,
                context: PaintCheckContext(
                    componentName: componentName,
                    policy: policy,
                    variableNamesById: variableNamesById
                ),
                diagnostics: &diagnostics
            )
        }

        if let strokes = node.strokes {
            for stroke in strokes {
                checkPaint(
                    stroke,
                    role: .stroke,
                    node: node,
                    context: PaintCheckContext(
                        componentName: componentName,
                        policy: policy,
                        variableNamesById: variableNamesById
                    ),
                    diagnostics: &diagnostics
                )
            }
        }

        for child in node.children ?? [] {
            checkNode(
                child,
                componentName: componentName,
                policy: policy,
                variableNamesById: variableNamesById,
                diagnostics: &diagnostics
            )
        }
    }

    private func checkPaint(
        _ paint: Paint,
        role: PaintRole,
        node: Document,
        context: PaintCheckContext,
        diagnostics: inout [LintDiagnostic]
    ) {
        guard shouldCheck(paint) else { return }

        let allowed = context.policy.allowed(for: role)
        guard !allowed.isEmpty else { return }

        guard let variableId = paint.boundVariables?["color"]?.id else {
            guard context.policy.requireBound else { return }
            diagnostics.append(diagnostic(
                message: "\(role.displayName) in '\(context.componentName)' not bound to Variable",
                componentName: context.componentName,
                nodeId: node.id,
                suggestion: "Bind this \(role.rawValue) to one of: \(allowed.sorted().joined(separator: ", "))"
            ))
            return
        }

        // When the bound variable's name cannot be resolved (metadata unavailable for its
        // source file), report it as inconclusive rather than comparing a raw ID against
        // human-readable names and producing a confusing false mismatch.
        guard let variableName = variableName(for: variableId, in: context.variableNamesById) else {
            diagnostics.append(diagnostic(
                severity: .warning,
                message: "\(role.displayName) in '\(context.componentName)' bound to a variable with unresolved name",
                componentName: context.componentName,
                nodeId: node.id,
                suggestion: "Ensure the variable's source file is reachable (set variablesFileId in lint config)"
            ))
            return
        }

        guard allowed.contains(variableName) else {
            let expected = allowed.sorted().joined(separator: ", ")
            let message = """
            \(role.displayName) in '\(context.componentName)' uses '\(variableName)', \
            expected one of: \(expected)
            """
            diagnostics.append(diagnostic(
                message: message,
                componentName: context.componentName,
                nodeId: node.id,
                suggestion: "Bind this \(role.rawValue) to the configured icon color Variable"
            ))
            return
        }
    }

    private func shouldCheck(_ paint: Paint) -> Bool {
        if paint.type == .image { return false }
        if paint.opacity == 0 { return false }
        return true
    }

    // MARK: - Variable Source Resolution

    /// Result of merging variable names across every reachable candidate file.
    private struct VariableResolution {
        /// Combined `variableId → name` index from all successfully fetched files.
        let namesById: [String: String]
        /// Whether the full set of expected names was found in at least one file.
        let expectedNamesFound: Bool
        /// Whether at least one candidate file was fetched successfully.
        let reachedAtLeastOneFile: Bool
    }

    private func resolveVariableNames(
        for policy: IconColorPolicy,
        entries: [IconEntry],
        context: LintContext,
        diagnostics: inout [LintDiagnostic]
    ) async -> VariableResolution {
        // Candidates: explicit config sources, plus every icon file (cross-file library refs).
        var candidateFileIds = variableCandidateFileIds(for: policy, entries: entries, config: context.config)
        for fileId in entries.map(\.fileId) where !fileId.isEmpty && !candidateFileIds.contains(fileId) {
            candidateFileIds.append(fileId)
        }

        var namesById: [String: String] = [:]
        var expectedNamesFound = false
        var reachedAtLeastOneFile = false
        let expectedNames = policy.expectedNames

        for fileId in candidateFileIds {
            do {
                let meta = try await context.cache.variables(for: fileId, client: context.client)
                reachedAtLeastOneFile = true
                let index = variableNameIndex(from: meta)
                // Prefer names already discovered (first reachable source wins on conflict).
                namesById.merge(index, uniquingKeysWith: { current, _ in current })
                if expectedNames.isSubset(of: Set(index.values)) {
                    expectedNamesFound = true
                }
            } catch {
                diagnostics.append(diagnostic(
                    message: "Cannot fetch variables for file '\(fileId)': \(error.localizedDescription)",
                    suggestion: "Check FIGMA_PERSONAL_TOKEN and file permissions"
                ))
            }
        }

        return VariableResolution(
            namesById: namesById,
            expectedNamesFound: expectedNamesFound,
            reachedAtLeastOneFile: reachedAtLeastOneFile
        )
    }

    private func variableNameIndex(from meta: VariablesMeta) -> [String: String] {
        Dictionary(meta.variables.map { id, variable in (id, variable.name) }, uniquingKeysWith: { first, _ in first })
    }

    private func variableName(for variableId: String, in index: [String: String]) -> String? {
        for key in variableLookupKeys(for: variableId) {
            if let name = index[key] {
                return name
            }
        }
        return nil
    }

    /// Derives the set of keys a bound variable ID may appear under in the name index.
    ///
    /// Figma variable IDs come in several shapes: a bare `123:45`, a prefixed
    /// `VariableID:123:45`, or a cross-file library ref `VariableID:library-key/123:45`.
    /// `internal` (not `private`) so the parsing branches can be unit-tested directly.
    func variableLookupKeys(for variableId: String) -> [String] {
        var keys = [variableId]
        let rawId = variableId.hasPrefix("VariableID:")
            ? String(variableId.dropFirst("VariableID:".count))
            : variableId

        if let slashIndex = rawId.lastIndex(of: "/") {
            let localId = String(rawId[rawId.index(after: slashIndex)...])
            keys.append("VariableID:\(localId)")
            keys.append(localId)
        } else if variableId.hasPrefix("VariableID:") {
            keys.append(rawId)
        } else {
            keys.append("VariableID:\(variableId)")
        }

        return keys
    }

    private func variableCandidateFileIds(
        for policy: IconColorPolicy,
        entries: [IconEntry],
        config: ExFig.ModuleImpl
    ) -> [String] {
        var ids: [String] = []

        func append(_ id: String?) {
            guard let id, !id.isEmpty, !ids.contains(id) else { return }
            ids.append(id)
        }
        func append(_ values: [String?]?) {
            for value in values ?? [] {
                append(value)
            }
        }

        append(policy.variablesFileId)
        append(config.common?.variablesColors?.tokensFileId)
        append(config.ios?.colors?.map(\.tokensFileId))
        append(config.android?.colors?.map(\.tokensFileId))
        append(config.flutter?.colors?.map(\.tokensFileId))
        append(config.web?.colors?.map(\.tokensFileId))

        for entry in entries {
            append(entry.variablesDarkMode?.variablesFileId)
        }

        return ids
    }

    // MARK: - Entry Collection

    private struct IconEntry {
        let fileId: String
        let pageName: String?
        let frameName: String?
        let assetsFolder: String?
        let variablesDarkMode: Common.VariablesDarkMode?

        func matches(_ selector: ExFigConfig.Lint.IconSelector) -> Bool {
            if let figmaFileId = selector.figmaFileId, fileId != figmaFileId { return false }
            if let figmaPageName = selector.figmaPageName, pageName != figmaPageName { return false }
            if let figmaFrameName = selector.figmaFrameName, frameName != figmaFrameName { return false }
            if let assetsFolder = selector.assetsFolder, self.assetsFolder != assetsFolder { return false }
            return true
        }
    }

    private func collectIconEntries(from config: ExFig.ModuleImpl, defaultFileId: String) -> [IconEntry] {
        var entries: [IconEntry] = []

        entries.append(contentsOf: config.ios?.icons?.map {
            IconEntry(
                fileId: $0.figmaFileId ?? defaultFileId,
                pageName: $0.figmaPageName,
                frameName: $0.figmaFrameName,
                assetsFolder: $0.assetsFolder,
                variablesDarkMode: $0.variablesDarkMode
            )
        } ?? [])

        entries.append(contentsOf: config.android?.icons?.map {
            IconEntry(
                fileId: $0.figmaFileId ?? defaultFileId,
                pageName: $0.figmaPageName,
                frameName: $0.figmaFrameName,
                assetsFolder: $0.output,
                variablesDarkMode: $0.variablesDarkMode
            )
        } ?? [])

        entries.append(contentsOf: config.flutter?.icons?.map {
            IconEntry(
                fileId: $0.figmaFileId ?? defaultFileId,
                pageName: $0.figmaPageName,
                frameName: $0.figmaFrameName,
                assetsFolder: $0.output,
                variablesDarkMode: $0.variablesDarkMode
            )
        } ?? [])

        entries.append(contentsOf: config.web?.icons?.map {
            IconEntry(
                fileId: $0.figmaFileId ?? defaultFileId,
                pageName: $0.figmaPageName,
                frameName: $0.figmaFrameName,
                assetsFolder: $0.outputDirectory,
                variablesDarkMode: $0.variablesDarkMode
            )
        } ?? [])

        return entries
    }
}

// MARK: - Paint Role

/// Whether a paint is applied as a fill or a stroke.
/// `internal` (not `private`) so policy logic can be unit-tested without network calls.
enum PaintRole: String {
    case fill
    case stroke

    /// Capitalized label for user-facing diagnostics ("Fill" / "Stroke").
    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Icon Color Policy

/// A validated icon-color policy.
///
/// Wraps the generated `Lint.IconColorVariablesRule` so the "at least one allow-list is set"
/// invariant is enforced once at construction (failable init) rather than re-checked at every
/// call site, and so the `paints` / `fills` / `strokes` overlap rule lives in one place.
///
/// `internal` (not `private`) so the failable init and `allowed(for:)` overlap logic can be
/// unit-tested directly without network calls.
struct IconColorPolicy {
    let selector: ExFigConfig.Lint.IconSelector
    let variablesFileId: String?
    let requireBound: Bool

    private let paints: Set<String>
    private let fills: Set<String>
    private let strokes: Set<String>

    /// Fails when the policy declares no allowed variable names at all.
    init?(_ rule: ExFigConfig.Lint.IconColorVariablesRule) {
        let paints = Set(rule.paints ?? [])
        let fills = Set(rule.fills ?? [])
        let strokes = Set(rule.strokes ?? [])
        guard !(paints.isEmpty && fills.isEmpty && strokes.isEmpty) else { return nil }

        selector = rule.selector
        variablesFileId = rule.variablesFileId
        requireBound = rule.requireBound
        self.paints = paints
        self.fills = fills
        self.strokes = strokes
    }

    /// Allowed variable names for a paint role. `paints` applies to both roles and is merged
    /// with the role-specific list.
    func allowed(for role: PaintRole) -> Set<String> {
        switch role {
        case .fill: paints.union(fills)
        case .stroke: paints.union(strokes)
        }
    }

    /// Every variable name the policy expects to exist (union of all three lists).
    var expectedNames: Set<String> {
        paints.union(fills).union(strokes)
    }
}
