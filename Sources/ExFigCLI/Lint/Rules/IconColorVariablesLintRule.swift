// swiftlint:disable file_length type_body_length
import ExFigConfig
import ExFigCore
import FigmaAPI
import Foundation

/// Checks that configured icon groups use the expected Figma Variables for visible paints.
struct IconColorVariablesLintRule: LintRule {
    let id = "icon-color-variables"
    let name = "Icon color variables"
    let description = "Icon fills and strokes must be bound to configured Figma Variables"
    let severity: LintSeverity = .error

    func check(context: LintContext) async throws -> [LintDiagnostic] {
        guard let policies = context.lintConfig?.iconColorVariables, !policies.isEmpty else {
            return []
        }

        let defaultFileId = context.config.figma?.lightFileId ?? ""
        let iconEntries = collectIconEntries(from: context.config, defaultFileId: defaultFileId)
        var diagnostics: [LintDiagnostic] = []

        for policy in policies {
            let matchedEntries = iconEntries.filter { $0.matches(policy.selector) }
            guard !matchedEntries.isEmpty else {
                diagnostics.append(diagnostic(
                    message: "No icon entries match icon-color-variables selector",
                    suggestion: "Check figmaFileId, figmaPageName, figmaFrameName, or assetsFolder in lint config"
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
        _ policy: ExFigConfig.Lint.IconColorVariablesRule,
        entries: [IconEntry],
        context: LintContext,
        diagnostics: inout [LintDiagnostic]
    ) async throws {
        let expectedNames = expectedVariableNames(for: policy)
        guard !expectedNames.isEmpty else {
            diagnostics.append(diagnostic(
                message: "icon-color-variables policy has no expected variables",
                suggestion: "Set paints, fills, or strokes in lint config"
            ))
            return
        }

        guard let variableSource = await resolveVariableSource(
            for: policy,
            entries: entries,
            expectedNames: expectedNames,
            context: context,
            diagnostics: &diagnostics
        ) else {
            return
        }

        var variableNamesById = variableNameIndex(from: variableSource.meta)
        await mergeIconFileVariableNames(
            into: &variableNamesById,
            entries: entries,
            context: context,
            diagnostics: &diagnostics
        )
        for entry in entries {
            try await checkEntry(
                entry,
                policy: policy,
                variableNamesById: variableNamesById,
                context: context,
                diagnostics: &diagnostics
            )
        }
    }

    private func checkEntry(
        _ entry: IconEntry,
        policy: ExFigConfig.Lint.IconColorVariablesRule,
        variableNamesById: [String: String],
        context: LintContext,
        diagnostics: inout [LintDiagnostic]
    ) async throws {
        guard !entry.fileId.isEmpty else {
            diagnostics.append(diagnostic(
                message: "No Figma file ID configured for icon entry",
                suggestion: "Set figma.lightFileId or entry figmaFileId in the main config"
            ))
            return
        }

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
        guard !relevant.isEmpty else { return }

        let nodeIds = relevant.map(\.nodeId)
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

        for (nodeId, node) in nodes {
            let componentName = relevant.first { $0.nodeId == nodeId }?.iconName ?? node.document.name
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

    private enum PaintRole: String {
        case fill
        case stroke
    }

    private struct PaintCheckContext {
        let componentName: String
        let policy: ExFigConfig.Lint.IconColorVariablesRule
        let variableNamesById: [String: String]
    }

    private func checkChildren(
        _ children: [Document],
        componentName: String,
        policy: ExFigConfig.Lint.IconColorVariablesRule,
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
        policy: ExFigConfig.Lint.IconColorVariablesRule,
        variableNamesById: [String: String],
        diagnostics: inout [LintDiagnostic]
    ) {
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

        let allowed = allowedVariables(for: role, policy: context.policy)
        guard !allowed.isEmpty else { return }

        guard let variableId = paint.boundVariables?["color"]?.id else {
            guard context.policy.requireBound else { return }
            diagnostics.append(diagnostic(
                message: "\(role.rawValue.capitalized) in '\(context.componentName)' not bound to Variable",
                componentName: context.componentName,
                nodeId: node.id,
                suggestion: "Bind this \(role.rawValue) to one of: \(allowed.sorted().joined(separator: ", "))"
            ))
            return
        }

        let variableName = variableName(for: variableId, in: context.variableNamesById) ?? variableId
        guard allowed.contains(variableName) else {
            let expected = allowed.sorted().joined(separator: ", ")
            let message = """
            \(role.rawValue.capitalized) in '\(context.componentName)' uses '\(variableName)', \
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

    private func allowedVariables(
        for role: PaintRole,
        policy: ExFigConfig.Lint.IconColorVariablesRule
    ) -> Set<String> {
        var names = Set(policy.paints ?? [])
        switch role {
        case .fill:
            names.formUnion(policy.fills ?? [])
        case .stroke:
            names.formUnion(policy.strokes ?? [])
        }
        return names
    }

    // MARK: - Variable Source Resolution

    private struct VariableSource {
        let fileId: String
        let meta: VariablesMeta
    }

    private func resolveVariableSource(
        for policy: ExFigConfig.Lint.IconColorVariablesRule,
        entries: [IconEntry],
        expectedNames: Set<String>,
        context: LintContext,
        diagnostics: inout [LintDiagnostic]
    ) async -> VariableSource? {
        let candidateFileIds = variableCandidateFileIds(for: policy, entries: entries, config: context.config)
        var matches: [VariableSource] = []

        for fileId in candidateFileIds {
            do {
                let meta = try await context.cache.variables(for: fileId, client: context.client)
                let names = Set(meta.variables.values.map(\.name))
                if expectedNames.isSubset(of: names) {
                    matches.append(VariableSource(fileId: fileId, meta: meta))
                }
            } catch {
                diagnostics.append(diagnostic(
                    message: "Cannot fetch variables for file '\(fileId)': \(error.localizedDescription)",
                    suggestion: "Check FIGMA_PERSONAL_TOKEN and file permissions"
                ))
            }
        }

        if matches.count == 1 {
            return matches[0]
        }

        if let firstMatch = matches.first {
            return firstMatch
        }

        if matches.isEmpty {
            let expected = expectedNames.sorted().joined(separator: ", ")
            diagnostics.append(diagnostic(
                message: "Cannot resolve variable source for: \(expected)",
                suggestion: """
                Ensure these variables are present in common.variablesColors, platform colors, \
                variablesDarkMode, or set variablesFileId in lint config
                """
            ))
        }

        return nil
    }

    private func expectedVariableNames(for policy: ExFigConfig.Lint.IconColorVariablesRule) -> Set<String> {
        var names = Set(policy.paints ?? [])
        names.formUnion(policy.fills ?? [])
        names.formUnion(policy.strokes ?? [])
        return names
    }

    private func variableNameIndex(from meta: VariablesMeta) -> [String: String] {
        Dictionary(uniqueKeysWithValues: meta.variables.map { id, variable in
            (id, variable.name)
        })
    }

    private func mergeIconFileVariableNames(
        into index: inout [String: String],
        entries: [IconEntry],
        context: LintContext,
        diagnostics: inout [LintDiagnostic]
    ) async {
        let fileIds = Set(entries.map(\.fileId).filter { !$0.isEmpty })

        for fileId in fileIds {
            do {
                let meta = try await context.cache.variables(for: fileId, client: context.client)
                index.merge(variableNameIndex(from: meta), uniquingKeysWith: { current, _ in current })
            } catch {
                diagnostics.append(diagnostic(
                    message: "Cannot fetch icon variables for file '\(fileId)': \(error.localizedDescription)",
                    suggestion: "Check FIGMA_PERSONAL_TOKEN and icon file permissions"
                ))
            }
        }
    }

    private func variableName(for variableId: String, in index: [String: String]) -> String? {
        for key in variableLookupKeys(for: variableId) {
            if let name = index[key] {
                return name
            }
        }
        return nil
    }

    private func variableLookupKeys(for variableId: String) -> [String] {
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
        for policy: ExFigConfig.Lint.IconColorVariablesRule,
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
