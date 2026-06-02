// swiftlint:disable file_length
@testable import ExFigCLI
import ExFigConfig
import ExFigCore
import FigmaAPI
import Foundation
import SVGKit
import Testing

// MARK: - Test Helpers

private func makeLintContext(
    config: PKLConfig,
    client: MockClient,
    lintConfig: ExFigConfig.Lint.ModuleImpl? = nil
) -> LintContext {
    let ui = TerminalUI(outputMode: .quiet)
    return LintContext(config: config, lintConfig: lintConfig, client: client, cache: LintDataCache(), ui: ui)
}

/// Creates a PKLConfig with iOS icons entries for lint testing.
private func makeIOSIconsConfig(
    lightFileId: String = "abc123",
    commonVariablesFileId: String? = nil,
    frameName: String? = nil,
    pageName: String? = nil,
    nameValidateRegexp: String? = nil,
    rtlProperty: String? = nil,
    rtlActiveValues: [String]? = nil,
    suffixDarkMode: String? = nil
) -> PKLConfig {
    var entryParts: [String] = [
        "\"assetsFolder\": \"Icons\"",
        "\"format\": \"svg\"",
        "\"nameStyle\": \"camelCase\"",
    ]
    if let frameName { entryParts.append("\"figmaFrameName\": \"\(frameName)\"") }
    if let pageName { entryParts.append("\"figmaPageName\": \"\(pageName)\"") }
    if let regex = nameValidateRegexp { entryParts.append("\"nameValidateRegexp\": \"\(regex)\"") }
    if let rtlProperty { entryParts.append("\"rtlProperty\": \"\(rtlProperty)\"") }
    if let rtlActiveValues {
        let valuesJson = rtlActiveValues.map { "\"\($0)\"" }.joined(separator: ", ")
        entryParts.append("\"rtlActiveValues\": [\(valuesJson)]")
    }

    var commonParts: [String] = []
    if let commonVariablesFileId {
        commonParts.append("""
        "variablesColors": {
            "tokensFileId": "\(commonVariablesFileId)",
            "tokensCollectionName": "Oymyakon",
            "lightModeName": "Light",
            "darkModeName": "Dark"
        }
        """)
    }
    if let suffix = suffixDarkMode {
        commonParts.append("\"icons\": { \"suffixDarkMode\": { \"suffix\": \"\(suffix)\" } }")
    }
    let commonJson = commonParts.isEmpty ? "" : ", \"common\": { \(commonParts.joined(separator: ", ")) }"

    let json = """
    {
        "figma": { "lightFileId": "\(lightFileId)" },
        "ios": {
            "xcodeprojPath": "App.xcodeproj",
            "target": "App",
            "xcassetsPath": "Assets.xcassets",
            "xcassetsInMainBundle": true,
            "icons": [{ \(entryParts.joined(separator: ", ")) }]
        }\(commonJson)
    }
    """
    // swiftlint:disable:next force_try
    return try! JSONCodec.decode(PKLConfig.self, from: Data(json.utf8))
}

// MARK: - FramePageMatchRule Tests

struct FramePageMatchRuleTests {
    let rule = FramePageMatchRule()

    @Test("passes when frame and page exist")
    func passesWhenFrameAndPageExist() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "icon_home", frameName: "Icons", pageName: "Components"),
        ], for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "Icons", pageName: "Components")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }

    @Test("error when page not found")
    func errorWhenPageNotFound() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "icon_home", frameName: "Icons", pageName: "Page A"),
        ], for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "Icons", pageName: "NonExistent")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.count >= 1)
        #expect(diagnostics.first?.ruleId == "frame-page-match")
        #expect(diagnostics.first?.severity == .error)
        #expect(diagnostics.first?.message.contains("NonExistent") == true)
    }

    @Test("error when frame not found on page")
    func errorWhenFrameNotFound() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "icon_home", frameName: "OtherFrame", pageName: "Components"),
        ], for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "MissingFrame", pageName: "Components")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.contains { $0.message.contains("MissingFrame") && $0.message.contains("not found") })
    }

    @Test("skips when no entries configured")
    func skipsWhenNoEntries() async throws {
        let client = MockClient()
        let config = PKLConfig.make(lightFileId: "abc123")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }
}

// MARK: - NamingConventionRule Tests

struct NamingConventionRuleTests {
    let rule = NamingConventionRule()

    @Test("passes when names match regex")
    func passesWhenNamesMatch() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_home", frameName: "Icons"),
            Component.make(nodeId: "1:2", name: "ic_settings", frameName: "Icons"),
        ], for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "Icons", nameValidateRegexp: "^ic_[a-z_]+$")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }

    @Test("error when name violates regex")
    func errorWhenNameViolatesRegex() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_home", frameName: "Icons"),
            Component.make(nodeId: "1:2", name: "BadName", frameName: "Icons"),
        ], for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "Icons", nameValidateRegexp: "^ic_[a-z_]+$")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.componentName == "BadName")
        #expect(diagnostics.first?.severity == .error)
    }

    @Test("skips entries without nameValidateRegexp")
    func skipsWithoutRegex() async throws {
        let client = MockClient()
        let config = makeIOSIconsConfig(frameName: "Icons")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }
}

// MARK: - DeletedVariablesRule Tests

struct DeletedVariablesRuleTests {
    let rule = DeletedVariablesRule()

    @Test("passes when no deleted variables")
    func passesWhenNoDeletedVars() async throws {
        let client = MockClient()
        let variables = VariablesMeta.make(
            variables: [
                (id: "1:1", name: "Primary", valuesByMode: ["1:0": (r: 1, g: 0, b: 0, a: 1)]),
            ]
        )
        client.setResponse(variables, for: VariablesEndpoint.self)

        let config = makeConfigWithVariablesColors()
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }

    @Test("error when deleted variable found")
    func errorWhenDeletedVar() async throws {
        let client = MockClient()
        let variables = VariablesMeta.makeWithAliases(
            variables: [
                (
                    id: "1:1",
                    name: "Old/Deprecated",
                    collectionId: nil,
                    valuesByMode: ["1:0": .color(r: 1, g: 0, b: 0, a: 1)]
                ),
            ],
            deletedVariableIds: ["1:1"]
        )
        client.setResponse(variables, for: VariablesEndpoint.self)

        let config = makeConfigWithVariablesColors()
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.ruleId == "deleted-variables")
        #expect(diagnostics.first?.componentName == "Old/Deprecated")
    }
}

private func makeConfigWithVariablesColors() -> PKLConfig {
    let json = """
    {
        "figma": { "lightFileId": "abc123" },
        "common": {
            "variablesColors": {
                "tokensFileId": "abc123",
                "tokensCollectionName": "Colors",
                "lightModeName": "Light",
                "darkModeName": "Dark"
            }
        }
    }
    """
    // swiftlint:disable:next force_try
    return try! JSONCodec.decode(PKLConfig.self, from: Data(json.utf8))
}

// MARK: - AliasChainIntegrityRule Tests

struct AliasChainIntegrityRuleTests {
    let rule = AliasChainIntegrityRule()

    @Test("passes with valid alias chain")
    func passesWithValidChain() async throws {
        let client = MockClient()
        let variables = VariablesMeta.makeWithAliases(
            variables: [
                (
                    id: "1:1",
                    name: "Semantic/Primary",
                    collectionId: nil,
                    valuesByMode: ["1:0": .alias("1:2")]
                ),
                (
                    id: "1:2",
                    name: "Primitive/Blue",
                    collectionId: nil,
                    valuesByMode: ["1:0": .color(r: 0, g: 0, b: 1, a: 1)]
                ),
            ]
        )
        client.setResponse(variables, for: VariablesEndpoint.self)

        let config = PKLConfig.make(lightFileId: "abc123")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }

    @Test("error with broken alias chain")
    func errorWithBrokenChain() async throws {
        let client = MockClient()
        let variables = VariablesMeta.makeWithAliases(
            variables: [
                (
                    id: "1:1",
                    name: "Semantic/Primary",
                    collectionId: nil,
                    valuesByMode: ["1:0": .alias("9:9")]
                ),
            ]
        )
        client.setResponse(variables, for: VariablesEndpoint.self)

        let config = PKLConfig.make(lightFileId: "abc123")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.ruleId == "alias-chain-integrity")
        #expect(diagnostics.first?.severity == .error)
    }

    @Test("error with circular alias chain")
    func errorWithCircularChain() async throws {
        let client = MockClient()
        let variables = VariablesMeta.makeWithAliases(
            variables: [
                (id: "1:1", name: "A", collectionId: nil, valuesByMode: ["1:0": .alias("1:2")]),
                (id: "1:2", name: "B", collectionId: nil, valuesByMode: ["1:0": .alias("1:1")]),
            ]
        )
        client.setResponse(variables, for: VariablesEndpoint.self)

        let config = PKLConfig.make(lightFileId: "abc123")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.contains { $0.message.contains("circular") })
    }

    @Test("skips cross-file alias references")
    func skipsCrossFileAliases() async throws {
        let client = MockClient()
        let crossFileId = "806fcc6a84cf048f0a06837634440ecad91622fe/3556:423"
        let variables = VariablesMeta.makeWithAliases(
            variables: [
                (
                    id: "1:1",
                    name: "Semantic/Primary",
                    collectionId: nil,
                    valuesByMode: ["1:0": .alias(crossFileId)]
                ),
            ]
        )
        client.setResponse(variables, for: VariablesEndpoint.self)

        let config = PKLConfig.make(lightFileId: "abc123")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }
}

// MARK: - ComponentNotFrameRule Tests

struct ComponentNotFrameRuleTests {
    let rule = ComponentNotFrameRule()

    @Test("passes when frame has components")
    func passesWhenComponentsExist() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "icon_home", frameName: "Icons"),
        ], for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "Icons")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }

    @Test("error when frame has no components")
    func errorWhenNoComponents() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "icon_home", frameName: "OtherFrame"),
        ], for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "EmptyFrame")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.ruleId == "component-not-frame")
        #expect(diagnostics.first?.message.contains("EmptyFrame") == true)
    }
}

// MARK: - DarkModeSuffixRule Tests

struct DarkModeSuffixRuleTests {
    let rule = DarkModeSuffixRule()

    @Test("passes when all light components have dark pairs")
    func passesWithDarkPairs() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "icon_home", frameName: "Icons"),
            Component.make(nodeId: "1:2", name: "icon_home-dark", frameName: "Icons"),
        ], for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "Icons", suffixDarkMode: "-dark")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }

    @Test("warning when dark pair missing")
    func warningWhenDarkPairMissing() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "icon_home", frameName: "Icons"),
            Component.make(nodeId: "1:2", name: "icon_settings", frameName: "Icons"),
        ], for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "Icons", suffixDarkMode: "-dark")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.count == 2)
        #expect(diagnostics.allSatisfy { $0.severity == .warning })
    }

    @Test("only checks components in configured frames")
    func onlyChecksConfiguredFrames() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "icon_home", frameName: "Icons"),
            Component.make(nodeId: "1:2", name: "flag_us", frameName: "Flags"),
        ], for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "Icons", suffixDarkMode: "-dark")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        // Only icon_home should be checked, not flag_us
        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.componentName == "icon_home")
    }

    @Test("skips when no suffixDarkMode configured")
    func skipsWithoutSuffix() async throws {
        let client = MockClient()
        let config = makeIOSIconsConfig(frameName: "Icons")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }
}

// MARK: - DuplicateComponentNamesRule Tests

struct DuplicateComponentNamesRuleTests {
    let rule = DuplicateComponentNamesRule()

    @Test("passes when no duplicates")
    func passesNoDuplicates() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "icon_home", frameName: "Icons"),
            Component.make(nodeId: "1:2", name: "icon_settings", frameName: "Icons"),
        ], for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "Icons")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }

    @Test("error when duplicate names on same page")
    func errorOnDuplicates() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "icon_home", frameName: "Icons"),
            Component.make(nodeId: "1:2", name: "icon_home", frameName: "Icons"),
        ], for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "Icons")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.message.contains("2x") == true)
    }

    @Test("skips RTL variants")
    func skipsRTLVariants() async throws {
        let client = MockClient()
        client.setResponse([
            makeVariantComponent(nodeId: "1:1", name: "RTL=On", frameName: "Icons", componentSetName: "icon_home"),
            makeVariantComponent(nodeId: "1:2", name: "RTL=On", frameName: "Icons", componentSetName: "icon_settings"),
        ], for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "Icons")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }

    @Test("error when duplicate component sets with same iconName")
    func errorOnDuplicateComponentSets() async throws {
        let client = MockClient()
        // Two different component sets both named "address-a-color" in different frames
        client.setResponse([
            makeVariantComponent(
                nodeId: "1:1", name: "Style=Default", frameName: "Icons/24",
                componentSetName: "address-a-color", componentSetNodeId: "set:1"
            ),
            makeVariantComponent(
                nodeId: "2:1", name: "Style=Default", frameName: "Icons/32",
                componentSetName: "address-a-color", componentSetNodeId: "set:2"
            ),
        ], for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: nil, pageName: "Components")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.message.contains("address-a-color") == true)
        #expect(diagnostics.first?.message.contains("2x") == true)
    }

    @Test("passes when variants belong to same component set")
    func passesVariantsOfSameComponentSet() async throws {
        let client = MockClient()
        // Multiple variants of the SAME component set — not a duplicate
        client.setResponse([
            makeVariantComponent(
                nodeId: "1:1", name: "Size=24", frameName: "Icons",
                componentSetName: "icon_home", componentSetNodeId: "set:1"
            ),
            makeVariantComponent(
                nodeId: "1:2", name: "Size=32", frameName: "Icons",
                componentSetName: "icon_home", componentSetNodeId: "set:1"
            ),
        ], for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "Icons")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }

    @Test("error when standalone and variant share same iconName")
    func errorMixedStandaloneAndVariant() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "icon_home", frameName: "Icons"),
            makeVariantComponent(
                nodeId: "2:1", name: "Style=Default", frameName: "Icons",
                componentSetName: "icon_home", componentSetNodeId: "set:2"
            ),
        ], for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "Icons")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.message.contains("icon_home") == true)
    }

    @Test("only checks configured frames")
    func onlyConfiguredFrames() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "duplicate", frameName: "Icons"),
            Component.make(nodeId: "1:2", name: "duplicate", frameName: "Icons"),
            Component.make(nodeId: "1:3", name: "duplicate", frameName: "OtherFrame"),
            Component.make(nodeId: "1:4", name: "duplicate", frameName: "OtherFrame"),
        ], for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "Icons")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        // Only the Icons frame pair should be flagged
        #expect(diagnostics.count == 1)
    }
}

// MARK: - Variant Component Helper

/// Creates a Component that is a variant inside a component set (has containingComponentSet).
private func makeVariantComponent(
    nodeId: String,
    name: String,
    frameName: String = "Icons",
    pageName: String = "Components",
    componentSetName: String,
    componentSetNodeId: String? = nil
) -> Component {
    let setNodeId = componentSetNodeId ?? "set:\(nodeId)"
    let json = """
    {
        "key": "test-key",
        "node_id": "\(nodeId)",
        "name": "\(name)",
        "containing_frame": {
            "nodeId": "\(nodeId)",
            "name": "\(frameName)",
            "pageName": "\(pageName)",
            "containingComponentSet": {
                "nodeId": "\(setNodeId)",
                "name": "\(componentSetName)"
            }
        }
    }
    """
    // swiftlint:disable:next force_try
    return try! JSONCodec.decode(Component.self, from: Data(json.utf8))
}

private func makeLintConfig(
    pageName: String? = nil,
    frameName: String? = nil,
    variablesFileId: String? = nil,
    requireBound: Bool = false,
    paints: [String]? = nil,
    fills: [String]? = nil,
    strokes: [String]? = nil
) -> ExFigConfig.Lint.ModuleImpl {
    var selectorParts: [String] = []
    if let pageName { selectorParts.append("\"figmaPageName\": \"\(pageName)\"") }
    if let frameName { selectorParts.append("\"figmaFrameName\": \"\(frameName)\"") }

    var ruleParts = [
        "\"selector\": { \(selectorParts.joined(separator: ", ")) }",
        "\"requireBound\": \(requireBound)",
    ]
    if let variablesFileId {
        ruleParts.append("\"variablesFileId\": \"\(variablesFileId)\"")
    }
    if let paints {
        ruleParts.append("\"paints\": [\(paints.map { "\"\($0)\"" }.joined(separator: ", "))]")
    }
    if let fills {
        ruleParts.append("\"fills\": [\(fills.map { "\"\($0)\"" }.joined(separator: ", "))]")
    }
    if let strokes {
        ruleParts.append("\"strokes\": [\(strokes.map { "\"\($0)\"" }.joined(separator: ", "))]")
    }

    let json = """
    {
        "iconColorVariables": [
            { \(ruleParts.joined(separator: ", ")) }
        ]
    }
    """
    // swiftlint:disable:next force_try
    return try! JSONCodec.decode(ExFigConfig.Lint.ModuleImpl.self, from: Data(json.utf8))
}

private func makeIconNode(
    rootFills: [String] = [],
    childFills: [String] = [],
    childStrokes: [String] = []
) -> Node {
    let rootFillsJson = rootFills.joined(separator: ", ")
    let childFillsJson = childFills.joined(separator: ", ")
    let childStrokesJson = childStrokes.joined(separator: ", ")
    let json = """
    {
        "document": {
            "id": "root",
            "name": "icon",
            "fills": [\(rootFillsJson)],
            "children": [
                {
                    "id": "shape",
                    "name": "shape",
                    "fills": [\(childFillsJson)],
                    "strokes": [\(childStrokesJson)]
                }
            ]
        }
    }
    """
    // swiftlint:disable:next force_try
    return try! JSONCodec.decode(Node.self, from: Data(json.utf8))
}

private func boundPaint(variableId: String) -> String {
    """
    {
        "type": "SOLID",
        "color": { "r": 0.0, "g": 0.0, "b": 0.0, "a": 1.0 },
        "boundVariables": {
            "color": { "id": "\(variableId)", "type": "VARIABLE_ALIAS" }
        }
    }
    """
}

private func unboundPaint() -> String {
    """
    {
        "type": "SOLID",
        "color": { "r": 0.0, "g": 0.0, "b": 0.0, "a": 1.0 }
    }
    """
}

private func invisiblePaint() -> String {
    """
    {
        "type": "SOLID",
        "opacity": 0,
        "color": { "r": 0.0, "g": 0.0, "b": 0.0, "a": 1.0 }
    }
    """
}

private func imagePaint() -> String {
    """
    {
        "type": "IMAGE",
        "scaleMode": "FILL",
        "imageRef": "image-ref"
    }
    """
}

/// Icon node whose paint-bearing shape is nested two levels below the root, for testing
/// that `checkChildren` recurses through the full subtree.
private func makeDeeplyNestedIconNode(childFills: [String]) -> Node {
    let json = """
    {
        "document": {
            "id": "root",
            "name": "icon",
            "fills": [],
            "children": [
                {
                    "id": "group",
                    "name": "group",
                    "fills": [],
                    "children": [
                        {
                            "id": "shape",
                            "name": "shape",
                            "fills": [\(childFills.joined(separator: ", "))]
                        }
                    ]
                }
            ]
        }
    }
    """
    // swiftlint:disable:next force_try
    return try! JSONCodec.decode(Node.self, from: Data(json.utf8))
}

/// Icon node whose only paint-bearing child is fully transparent (`opacity: 0`),
/// for testing that hidden subtrees are skipped.
private func makeTransparentChildIconNode(childFills: [String]) -> Node {
    let json = """
    {
        "document": {
            "id": "root",
            "name": "icon",
            "fills": [],
            "children": [
                {
                    "id": "shape",
                    "name": "shape",
                    "opacity": 0,
                    "fills": [\(childFills.joined(separator: ", "))]
                }
            ]
        }
    }
    """
    // swiftlint:disable:next force_try
    return try! JSONCodec.decode(Node.self, from: Data(json.utf8))
}

// MARK: - LintEngine Tests

struct LintEngineTests {
    @Test("runs all rules and collects diagnostics")
    func runsAllRules() async throws {
        let client = MockClient()
        client.setResponse([Component](), for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "Icons")
        let context = makeLintContext(config: config, client: client)

        let engine = LintEngine.default
        let diagnostics = try await engine.run(context: context)

        // With empty components, component-not-frame should fire
        #expect(diagnostics.contains { $0.ruleId == "component-not-frame" })
    }

    @Test("filters by rule ID")
    func filtersByRuleId() async throws {
        let client = MockClient()
        client.setResponse([Component](), for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "Icons")
        let context = makeLintContext(config: config, client: client)

        let engine = LintEngine.default
        let diagnostics = try await engine.run(context: context, ruleFilter: ["deleted-variables"])

        // Only deleted-variables rule should run
        #expect(!diagnostics.contains { $0.ruleId == "component-not-frame" })
    }

    @Test("default engine registers all 11 rules")
    func defaultEngineHasAllRules() {
        let ruleIds = Set(LintEngine.default.rules.map(\.id))
        let expected: Set = [
            "frame-page-match",
            "naming-convention",
            "component-not-frame",
            "deleted-variables",
            "duplicate-component-names",
            "alias-chain-integrity",
            "dark-mode-variables",
            "dark-mode-suffix",
            "path-data-length",
            "invalid-rtl-variant-value",
            "icon-color-variables",
        ]
        #expect(ruleIds == expected)
    }

    @Test("catches rule errors as error-severity diagnostics")
    func catchesRuleErrors() async throws {
        let failingRule = FailingLintRule()
        let engine = LintEngine(rules: [failingRule])

        let client = MockClient()
        let config = makeIOSIconsConfig(frameName: "Icons")
        let context = makeLintContext(config: config, client: client)

        let diagnostics = try await engine.run(context: context)

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.ruleId == "failing-rule")
        #expect(diagnostics.first?.severity == .error)
        #expect(diagnostics.first?.message.contains("Rule check failed") == true)
    }

    @Test("filters rules by minimum severity")
    func filtersByMinSeverity() async throws {
        let client = MockClient()
        client.setResponse([Component](), for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "Icons")
        let context = makeLintContext(config: config, client: client)

        let engine = LintEngine.default
        let diagnostics = try await engine.run(context: context, minSeverity: .error)

        // Warning-severity rules (deleted-variables, alias-chain-integrity, dark-mode-suffix) should be excluded
        #expect(!diagnostics.contains { $0.ruleId == "dark-mode-suffix" })
        #expect(!diagnostics.contains { $0.ruleId == "deleted-variables" })
        #expect(!diagnostics.contains { $0.ruleId == "alias-chain-integrity" })
    }
}

// MARK: - IconColorVariablesLintRule Tests

struct IconColorVariablesLintRuleTests {
    let rule = IconColorVariablesLintRule()

    @Test("skips when lint config is absent")
    func skipsWhenLintConfigAbsent() async throws {
        let client = MockClient()
        let config = makeIOSIconsConfig(frameName: "Icons")
        let context = makeLintContext(config: config, client: client)

        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }

    @Test("paints allowlist applies to fills and strokes")
    func paintsAllowlistAppliesToFillsAndStrokes() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_car", frameName: "Actions", pageName: "Outlined"),
        ], for: ComponentsEndpoint.self)
        client.setResponse([
            "1:1": makeIconNode(
                childFills: [boundPaint(variableId: "VariableID:text")],
                childStrokes: [boundPaint(variableId: "VariableID:text")]
            ),
        ], for: NodesEndpoint.self)
        client.setResponse(VariablesMeta.make(
            variables: [
                (id: "text", name: "textandicon/Primary", valuesByMode: [:]),
            ]
        ), for: VariablesEndpoint.self)

        let config = makeIOSIconsConfig(
            lightFileId: "icons-file",
            commonVariablesFileId: "variables-file",
            pageName: "Outlined"
        )
        let lintConfig = makeLintConfig(pageName: "Outlined", paints: ["textandicon/Primary"])
        let context = makeLintContext(config: config, client: client, lintConfig: lintConfig)

        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }

    @Test("external library variable IDs resolve to local variable names")
    func externalLibraryVariableIdsResolveToLocalVariableNames() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_car", frameName: "Actions", pageName: "Outlined"),
        ], for: ComponentsEndpoint.self)
        client.setResponse([
            "1:1": makeIconNode(
                childFills: [boundPaint(variableId: "VariableID:library-key/2092:51")]
            ),
        ], for: NodesEndpoint.self)
        client.setResponse(VariablesMeta.make(
            variables: [
                (id: "2092:51", name: "TextAndIcon/Primary", valuesByMode: [:]),
            ]
        ), for: VariablesEndpoint.self)

        let config = makeIOSIconsConfig(
            lightFileId: "icons-file",
            commonVariablesFileId: "variables-file",
            pageName: "Outlined"
        )
        let lintConfig = makeLintConfig(pageName: "Outlined", paints: ["TextAndIcon/Primary"])
        let context = makeLintContext(config: config, client: client, lintConfig: lintConfig)

        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }

    @Test("fills and strokes are checked separately")
    func fillsAndStrokesAreCheckedSeparately() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_wallet", frameName: "Finance", pageName: "Double color"),
        ], for: ComponentsEndpoint.self)
        client.setResponse([
            "1:1": makeIconNode(
                childFills: [boundPaint(variableId: "VariableID:bg")],
                childStrokes: [boundPaint(variableId: "VariableID:outline")]
            ),
        ], for: NodesEndpoint.self)
        client.setResponse(VariablesMeta.make(
            variables: [
                (id: "bg", name: "doublecolor/Bg", valuesByMode: [:]),
                (id: "outline", name: "doublecolor/Outline", valuesByMode: [:]),
            ]
        ), for: VariablesEndpoint.self)

        let config = makeIOSIconsConfig(
            lightFileId: "icons-file",
            commonVariablesFileId: "variables-file",
            pageName: "Double color"
        )
        let lintConfig = makeLintConfig(
            pageName: "Double color",
            fills: ["doublecolor/Bg"],
            strokes: ["doublecolor/Outline"]
        )
        let context = makeLintContext(config: config, client: client, lintConfig: lintConfig)

        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }

    @Test("wrong variable emits diagnostic")
    func wrongVariableEmitsDiagnostic() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_home", frameName: "Actions", pageName: "Outlined"),
        ], for: ComponentsEndpoint.self)
        client.setResponse([
            "1:1": makeIconNode(childFills: [boundPaint(variableId: "VariableID:wrong")]),
        ], for: NodesEndpoint.self)
        client.setResponse(VariablesMeta.make(
            variables: [
                (id: "expected", name: "textandicon/Primary", valuesByMode: [:]),
                (id: "wrong", name: "doublecolor/Bg", valuesByMode: [:]),
            ]
        ), for: VariablesEndpoint.self)

        let config = makeIOSIconsConfig(
            lightFileId: "icons-file",
            commonVariablesFileId: "variables-file",
            pageName: "Outlined"
        )
        let lintConfig = makeLintConfig(pageName: "Outlined", paints: ["textandicon/Primary"])
        let context = makeLintContext(config: config, client: client, lintConfig: lintConfig)

        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.ruleId == "icon-color-variables")
        #expect(diagnostics.first?.message.contains("doublecolor/Bg") == true)
        #expect(diagnostics.first?.message.contains("textandicon/Primary") == true)
    }

    @Test("unbound paint is ignored by default")
    func unboundPaintIsIgnoredByDefault() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_home", frameName: "Actions", pageName: "Outlined"),
        ], for: ComponentsEndpoint.self)
        client.setResponse([
            "1:1": makeIconNode(childFills: [unboundPaint()]),
        ], for: NodesEndpoint.self)
        client.setResponse(VariablesMeta.make(
            variables: [
                (id: "expected", name: "textandicon/Primary", valuesByMode: [:]),
            ]
        ), for: VariablesEndpoint.self)

        let config = makeIOSIconsConfig(
            lightFileId: "icons-file",
            commonVariablesFileId: "variables-file",
            pageName: "Outlined"
        )
        let lintConfig = makeLintConfig(pageName: "Outlined", paints: ["textandicon/Primary"])
        let context = makeLintContext(config: config, client: client, lintConfig: lintConfig)

        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }

    @Test("requireBound emits diagnostic for unbound paint")
    func requireBoundEmitsDiagnosticForUnboundPaint() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_home", frameName: "Actions", pageName: "Outlined"),
        ], for: ComponentsEndpoint.self)
        client.setResponse([
            "1:1": makeIconNode(childFills: [unboundPaint()]),
        ], for: NodesEndpoint.self)
        client.setResponse(VariablesMeta.make(
            variables: [
                (id: "expected", name: "textandicon/Primary", valuesByMode: [:]),
            ]
        ), for: VariablesEndpoint.self)

        let config = makeIOSIconsConfig(
            lightFileId: "icons-file",
            commonVariablesFileId: "variables-file",
            pageName: "Outlined"
        )
        let lintConfig = makeLintConfig(pageName: "Outlined", requireBound: true, paints: ["textandicon/Primary"])
        let context = makeLintContext(config: config, client: client, lintConfig: lintConfig)

        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.message.contains("not bound") == true)
    }

    @Test("expected variables absent everywhere emits config warning, not a hard error")
    func expectedVariablesAbsentEmitsConfigWarning() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_home", frameName: "Actions", pageName: "Outlined"),
        ], for: ComponentsEndpoint.self)
        // Reachable file exists, but none of the expected variables are present (e.g. renamed).
        client.setResponse([
            "1:1": makeIconNode(childFills: [unboundPaint()]),
        ], for: NodesEndpoint.self)
        client.setResponse(VariablesMeta.make(
            variables: [
                (id: "other", name: "other/Variable", valuesByMode: [:]),
            ]
        ), for: VariablesEndpoint.self)

        let config = makeIOSIconsConfig(
            lightFileId: "icons-file",
            commonVariablesFileId: "variables-file",
            pageName: "Outlined"
        )
        let lintConfig = makeLintConfig(pageName: "Outlined", paints: ["textandicon/Primary"])
        let context = makeLintContext(config: config, client: client, lintConfig: lintConfig)

        let diagnostics = try await rule.check(context: context)

        // Config drift is surfaced as a warning, not an error that blocks CI.
        let warning = diagnostics.first { $0.message.contains("Expected icon color variables not found") }
        #expect(warning != nil)
        #expect(warning?.severity == .warning)
        // The unbound paint is NOT flagged (requireBound is false) — validation still ran.
        #expect(!diagnostics.contains { $0.message.contains("not bound") })
    }

    @Test("binding validation still runs when expected variables are missing")
    func bindingValidationRunsDespiteMissingExpectedVariables() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_home", frameName: "Actions", pageName: "Outlined"),
        ], for: ComponentsEndpoint.self)
        // The bound variable resolves to a name, but it is the WRONG one. Even though the
        // expected variable is absent from the file, the binding check must still fire —
        // this is the C2 regression guard (a degraded variable set must not silence validation).
        client.setResponse([
            "1:1": makeIconNode(childFills: [boundPaint(variableId: "VariableID:wrong")]),
        ], for: NodesEndpoint.self)
        client.setResponse(VariablesMeta.make(
            variables: [
                (id: "wrong", name: "doublecolor/Bg", valuesByMode: [:]),
            ]
        ), for: VariablesEndpoint.self)

        let config = makeIOSIconsConfig(
            lightFileId: "icons-file",
            commonVariablesFileId: "variables-file",
            pageName: "Outlined"
        )
        let lintConfig = makeLintConfig(pageName: "Outlined", paints: ["textandicon/Primary"])
        let context = makeLintContext(config: config, client: client, lintConfig: lintConfig)

        let diagnostics = try await rule.check(context: context)

        // The mismatch is reported even though "textandicon/Primary" was never found.
        #expect(diagnostics.contains { $0.message.contains("uses 'doublecolor/Bg'") })
    }

    @Test("cross-file: expected variable in a different file than the bound icon")
    func crossFileExpectedVariableResolution() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_home", frameName: "Actions", pageName: "Outlined"),
        ], for: ComponentsEndpoint.self, fileId: "icons-file")
        client.setResponse([
            "1:1": makeIconNode(childFills: [boundPaint(variableId: "VariableID:text")]),
        ], for: NodesEndpoint.self, fileId: "icons-file")
        // The icons file holds NO variables; the library file holds the expected one.
        // Only a fileId-aware mock can express this difference.
        client.setResponse(VariablesMeta.make(variables: []), for: VariablesEndpoint.self, fileId: "icons-file")
        client.setResponse(VariablesMeta.make(
            variables: [
                (id: "text", name: "textandicon/Primary", valuesByMode: [:]),
            ]
        ), for: VariablesEndpoint.self, fileId: "variables-file")

        let config = makeIOSIconsConfig(
            lightFileId: "icons-file",
            commonVariablesFileId: "variables-file",
            pageName: "Outlined"
        )
        let lintConfig = makeLintConfig(pageName: "Outlined", paints: ["textandicon/Primary"])
        let context = makeLintContext(config: config, client: client, lintConfig: lintConfig)

        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }

    @Test("ignores root background invisible and image paints")
    func ignoresRootBackgroundInvisibleAndImagePaints() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_home", frameName: "Actions", pageName: "Outlined"),
        ], for: ComponentsEndpoint.self)
        client.setResponse([
            "1:1": makeIconNode(
                rootFills: [unboundPaint()],
                childFills: [invisiblePaint(), imagePaint(), boundPaint(variableId: "VariableID:text")]
            ),
        ], for: NodesEndpoint.self)
        client.setResponse(VariablesMeta.make(
            variables: [
                (id: "text", name: "textandicon/Primary", valuesByMode: [:]),
            ]
        ), for: VariablesEndpoint.self)

        let config = makeIOSIconsConfig(
            lightFileId: "icons-file",
            commonVariablesFileId: "variables-file",
            pageName: "Outlined"
        )
        let lintConfig = makeLintConfig(pageName: "Outlined", paints: ["textandicon/Primary"])
        let context = makeLintContext(config: config, client: client, lintConfig: lintConfig)

        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }
}

// MARK: - IconColorVariablesLintRule: Failure & Coverage Tests

/// Split from `IconColorVariablesLintRuleTests` to stay under SwiftLint's type_body_length limit.
struct IconColorVariablesLintRuleFailureTests {
    let rule = IconColorVariablesLintRule()

    // MARK: - API Failure Paths (must emit diagnostics, never silently pass)

    @Test("components fetch failure emits diagnostic")
    func componentsFetchFailureEmitsDiagnostic() async throws {
        let client = MockClient()
        client.setError(URLError(.timedOut), for: ComponentsEndpoint.self)
        client.setResponse(VariablesMeta.make(
            variables: [(id: "text", name: "textandicon/Primary", valuesByMode: [:])]
        ), for: VariablesEndpoint.self)

        let config = makeIOSIconsConfig(
            lightFileId: "icons-file",
            commonVariablesFileId: "variables-file",
            pageName: "Outlined"
        )
        let lintConfig = makeLintConfig(pageName: "Outlined", paints: ["textandicon/Primary"])
        let context = makeLintContext(config: config, client: client, lintConfig: lintConfig)

        let diagnostics = try await rule.check(context: context)

        let failure = diagnostics.first { $0.message.contains("Cannot fetch components") }
        #expect(failure != nil)
        #expect(failure?.severity == .error)
    }

    @Test("nodes fetch failure emits diagnostic")
    func nodesFetchFailureEmitsDiagnostic() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_home", frameName: "Actions", pageName: "Outlined"),
        ], for: ComponentsEndpoint.self)
        client.setError(URLError(.timedOut), for: NodesEndpoint.self)
        client.setResponse(VariablesMeta.make(
            variables: [(id: "text", name: "textandicon/Primary", valuesByMode: [:])]
        ), for: VariablesEndpoint.self)

        let config = makeIOSIconsConfig(
            lightFileId: "icons-file",
            commonVariablesFileId: "variables-file",
            pageName: "Outlined"
        )
        let lintConfig = makeLintConfig(pageName: "Outlined", paints: ["textandicon/Primary"])
        let context = makeLintContext(config: config, client: client, lintConfig: lintConfig)

        let diagnostics = try await rule.check(context: context)

        let failure = diagnostics.first { $0.message.contains("Cannot fetch nodes") }
        #expect(failure != nil)
        #expect(failure?.severity == .error)
    }

    @Test("variables fetch failure emits diagnostic")
    func variablesFetchFailureEmitsDiagnostic() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_home", frameName: "Actions", pageName: "Outlined"),
        ], for: ComponentsEndpoint.self)
        client.setResponse([
            "1:1": makeIconNode(childFills: [boundPaint(variableId: "VariableID:text")]),
        ], for: NodesEndpoint.self)
        client.setError(URLError(.timedOut), for: VariablesEndpoint.self)

        let config = makeIOSIconsConfig(
            lightFileId: "icons-file",
            commonVariablesFileId: "variables-file",
            pageName: "Outlined"
        )
        let lintConfig = makeLintConfig(pageName: "Outlined", paints: ["textandicon/Primary"])
        let context = makeLintContext(config: config, client: client, lintConfig: lintConfig)

        let diagnostics = try await rule.check(context: context)

        let failure = diagnostics.first { $0.message.contains("Cannot fetch variables") }
        #expect(failure != nil)
        #expect(failure?.severity == .error)
    }

    @Test("empty file ID emits a precise diagnostic")
    func emptyFileIdEmitsDiagnostic() async throws {
        let client = MockClient()
        // No figma.lightFileId and no entry figmaFileId → entry fileId resolves to "".
        let config = makeIOSIconsConfig(lightFileId: "", pageName: "Outlined")
        let lintConfig = makeLintConfig(pageName: "Outlined", paints: ["textandicon/Primary"])
        let context = makeLintContext(config: config, client: client, lintConfig: lintConfig)

        let diagnostics = try await rule.check(context: context)

        let failure = diagnostics.first { $0.message.contains("No Figma file ID configured") }
        #expect(failure != nil)
        #expect(failure?.suggestion?.contains("figma.lightFileId") == true)
    }

    // MARK: - Selector / Policy Config Diagnostics

    @Test("selector matching no entries emits a warning")
    func selectorMatchingNoEntriesEmitsWarning() async throws {
        let client = MockClient()
        let config = makeIOSIconsConfig(lightFileId: "icons-file", pageName: "Outlined")
        // Selector targets a page that no entry uses.
        let lintConfig = makeLintConfig(pageName: "Nonexistent", paints: ["textandicon/Primary"])
        let context = makeLintContext(config: config, client: client, lintConfig: lintConfig)

        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.message.contains("No icon entries match") == true)
        #expect(diagnostics.first?.severity == .warning)
    }

    @Test("policy with no expected variables emits a warning")
    func emptyExpectedVariablesEmitsWarning() async throws {
        let client = MockClient()
        let config = makeIOSIconsConfig(lightFileId: "icons-file", pageName: "Outlined")
        // No paints/fills/strokes set at all.
        let lintConfig = makeLintConfig(pageName: "Outlined")
        let context = makeLintContext(config: config, client: client, lintConfig: lintConfig)

        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.message.contains("no expected variables") == true)
        #expect(diagnostics.first?.severity == .warning)
    }

    @Test("frame/page matching no component emits a warning")
    func noComponentMatchEmitsWarning() async throws {
        let client = MockClient()
        // Component exists, but on a different page than the entry selects.
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_home", frameName: "Actions", pageName: "Filled"),
        ], for: ComponentsEndpoint.self)
        client.setResponse(VariablesMeta.make(
            variables: [(id: "text", name: "textandicon/Primary", valuesByMode: [:])]
        ), for: VariablesEndpoint.self)

        let config = makeIOSIconsConfig(
            lightFileId: "icons-file",
            commonVariablesFileId: "variables-file",
            pageName: "Outlined"
        )
        let lintConfig = makeLintConfig(pageName: "Outlined", paints: ["textandicon/Primary"])
        let context = makeLintContext(config: config, client: client, lintConfig: lintConfig)

        let diagnostics = try await rule.check(context: context)

        let warning = diagnostics.first { $0.message.contains("No components matched page/frame") }
        #expect(warning != nil)
        #expect(warning?.severity == .warning)
    }

    // MARK: - Node Traversal Coverage

    @Test("flags one wrong fill among multiple fills on a node")
    func flagsWrongFillAmongMultiple() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_home", frameName: "Actions", pageName: "Outlined"),
        ], for: ComponentsEndpoint.self)
        client.setResponse([
            "1:1": makeIconNode(childFills: [
                boundPaint(variableId: "VariableID:ok"),
                boundPaint(variableId: "VariableID:wrong"),
            ]),
        ], for: NodesEndpoint.self)
        client.setResponse(VariablesMeta.make(
            variables: [
                (id: "ok", name: "textandicon/Primary", valuesByMode: [:]),
                (id: "wrong", name: "doublecolor/Bg", valuesByMode: [:]),
            ]
        ), for: VariablesEndpoint.self)

        let config = makeIOSIconsConfig(
            lightFileId: "icons-file",
            commonVariablesFileId: "variables-file",
            pageName: "Outlined"
        )
        let lintConfig = makeLintConfig(pageName: "Outlined", paints: ["textandicon/Primary"])
        let context = makeLintContext(config: config, client: client, lintConfig: lintConfig)

        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.message.contains("doublecolor/Bg") == true)
    }

    @Test("recurses into deeply nested children")
    func recursesIntoNestedChildren() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_home", frameName: "Actions", pageName: "Outlined"),
        ], for: ComponentsEndpoint.self)
        client.setResponse([
            "1:1": makeDeeplyNestedIconNode(childFills: [boundPaint(variableId: "VariableID:wrong")]),
        ], for: NodesEndpoint.self)
        client.setResponse(VariablesMeta.make(
            variables: [
                (id: "wrong", name: "doublecolor/Bg", valuesByMode: [:]),
                (id: "ok", name: "textandicon/Primary", valuesByMode: [:]),
            ]
        ), for: VariablesEndpoint.self)

        let config = makeIOSIconsConfig(
            lightFileId: "icons-file",
            commonVariablesFileId: "variables-file",
            pageName: "Outlined"
        )
        let lintConfig = makeLintConfig(pageName: "Outlined", paints: ["textandicon/Primary"])
        let context = makeLintContext(config: config, client: client, lintConfig: lintConfig)

        let diagnostics = try await rule.check(context: context)

        // The wrong fill is two levels below root — recursion must reach it.
        #expect(diagnostics.contains { $0.message.contains("doublecolor/Bg") })
    }

    @Test("skips fully transparent subtrees")
    func skipsTransparentSubtrees() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_home", frameName: "Actions", pageName: "Outlined"),
        ], for: ComponentsEndpoint.self)
        // The only fill (wrong) lives on a node with opacity 0 → must be skipped.
        client.setResponse([
            "1:1": makeTransparentChildIconNode(childFills: [boundPaint(variableId: "VariableID:wrong")]),
        ], for: NodesEndpoint.self)
        client.setResponse(VariablesMeta.make(
            variables: [
                (id: "wrong", name: "doublecolor/Bg", valuesByMode: [:]),
                (id: "ok", name: "textandicon/Primary", valuesByMode: [:]),
            ]
        ), for: VariablesEndpoint.self)

        let config = makeIOSIconsConfig(
            lightFileId: "icons-file",
            commonVariablesFileId: "variables-file",
            pageName: "Outlined"
        )
        let lintConfig = makeLintConfig(pageName: "Outlined", paints: ["textandicon/Primary"])
        let context = makeLintContext(config: config, client: client, lintConfig: lintConfig)

        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }

    @Test("requireBound flags an unbound stroke")
    func requireBoundFlagsUnboundStroke() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_home", frameName: "Actions", pageName: "Outlined"),
        ], for: ComponentsEndpoint.self)
        client.setResponse([
            "1:1": makeIconNode(childStrokes: [unboundPaint()]),
        ], for: NodesEndpoint.self)
        client.setResponse(VariablesMeta.make(
            variables: [(id: "outline", name: "doublecolor/Outline", valuesByMode: [:])]
        ), for: VariablesEndpoint.self)

        let config = makeIOSIconsConfig(
            lightFileId: "icons-file",
            commonVariablesFileId: "variables-file",
            pageName: "Outlined"
        )
        let lintConfig = makeLintConfig(
            pageName: "Outlined",
            requireBound: true,
            strokes: ["doublecolor/Outline"]
        )
        let context = makeLintContext(config: config, client: client, lintConfig: lintConfig)

        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.message.contains("Stroke") == true)
        #expect(diagnostics.first?.message.contains("not bound") == true)
    }

    @Test("skips RTL variants")
    func skipsRTLVariants() async throws {
        let client = MockClient()
        // An RTL variant inside a component set: it must NOT be checked.
        client.setResponse([
            makeVariantComponent(
                nodeId: "1:1",
                name: "RTL=On",
                frameName: "Actions",
                pageName: "Outlined",
                componentSetName: "ic_home"
            ),
        ], for: ComponentsEndpoint.self)
        client.setResponse(VariablesMeta.make(
            variables: [(id: "text", name: "textandicon/Primary", valuesByMode: [:])]
        ), for: VariablesEndpoint.self)

        let config = makeIOSIconsConfig(
            lightFileId: "icons-file",
            commonVariablesFileId: "variables-file",
            pageName: "Outlined"
        )
        let lintConfig = makeLintConfig(pageName: "Outlined", paints: ["textandicon/Primary"])
        let context = makeLintContext(config: config, client: client, lintConfig: lintConfig)

        let diagnostics = try await rule.check(context: context)

        // Only the RTL variant exists, so after filtering nothing remains → "no components matched".
        #expect(!diagnostics.contains { $0.message.contains("uses") })
    }

    // MARK: - Pure Logic (no network)

    @Test("variableLookupKeys derives all candidate keys")
    func variableLookupKeysDerivesCandidates() {
        // Cross-file library ref: prefix + library-key/localId.
        let libraryKeys = rule.variableLookupKeys(for: "VariableID:library-key/2092:51")
        #expect(libraryKeys.contains("VariableID:library-key/2092:51"))
        #expect(libraryKeys.contains("VariableID:2092:51"))
        #expect(libraryKeys.contains("2092:51"))

        // Prefixed local ID, no slash.
        let prefixedKeys = rule.variableLookupKeys(for: "VariableID:123:45")
        #expect(prefixedKeys.contains("VariableID:123:45"))
        #expect(prefixedKeys.contains("123:45"))

        // Bare ID, no prefix and no slash.
        let bareKeys = rule.variableLookupKeys(for: "123:45")
        #expect(bareKeys.contains("123:45"))
        #expect(bareKeys.contains("VariableID:123:45"))
    }

    @Test("IconColorPolicy fails when no allow-list is set")
    func iconColorPolicyRejectsEmptyAllowList() throws {
        let emptyRule = try #require(makeLintConfig(pageName: "Outlined").iconColorVariables?.first)
        #expect(IconColorPolicy(emptyRule) == nil)
    }

    @Test("IconColorPolicy merges paints into both roles")
    func iconColorPolicyMergesPaints() throws {
        let raw = try #require(makeLintConfig(
            pageName: "Outlined",
            paints: ["shared/Color"],
            fills: ["fill/Only"],
            strokes: ["stroke/Only"]
        ).iconColorVariables?.first)
        let policy = try #require(IconColorPolicy(raw))

        #expect(policy.allowed(for: .fill) == ["shared/Color", "fill/Only"])
        #expect(policy.allowed(for: .stroke) == ["shared/Color", "stroke/Only"])
        #expect(policy.expectedNames == ["shared/Color", "fill/Only", "stroke/Only"])
    }
}

/// A rule that always throws, for testing engine error handling.
private struct FailingLintRule: LintRule {
    let id = "failing-rule"
    let name = "Failing rule"
    let description = "Always fails"
    let severity: LintSeverity = .error

    func check(context: LintContext) async throws -> [LintDiagnostic] {
        throw URLError(.notConnectedToInternet)
    }
}

// MARK: - PathDataLengthRule Tests

/// Creates a PKLConfig with Android icons entries for lint testing.
private func makeAndroidIconsConfig(
    lightFileId: String = "abc123",
    frameName: String? = nil,
    pageName: String? = nil
) -> PKLConfig {
    var entryParts: [String] = [
        "\"output\": \"drawable\"",
    ]
    if let frameName { entryParts.append("\"figmaFrameName\": \"\(frameName)\"") }
    if let pageName { entryParts.append("\"figmaPageName\": \"\(pageName)\"") }

    let json = """
    {
        "figma": { "lightFileId": "\(lightFileId)" },
        "android": {
            "mainRes": "app/src/main/res",
            "icons": [{ \(entryParts.joined(separator: ", ")) }]
        }
    }
    """
    // swiftlint:disable:next force_try
    return try! JSONCodec.decode(PKLConfig.self, from: Data(json.utf8))
}

struct PathDataLengthRuleTests {
    let rule = PathDataLengthRule()

    @Test("checks iOS icon entries too")
    func checksIOSIconEntries() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_flag", frameName: "Icons", pageName: "Components"),
        ], for: ComponentsEndpoint.self)

        let imageURLs: [NodeId: ImagePath?] = ["1:1": "https://invalid.test/flag.svg"]
        client.setResponse(imageURLs, for: ImageEndpoint.self)

        // Uses iOS config, not Android — rule should still check it
        let config = makeIOSIconsConfig(frameName: "Icons", pageName: "Components")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        // Should get a warning (download fails), proving iOS entries are checked
        #expect(diagnostics.contains { $0.severity == .warning })
    }

    @Test("filters by frame and page")
    func filtersByFrameAndPage() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_other", frameName: "OtherFrame", pageName: "OtherPage"),
        ], for: ComponentsEndpoint.self)

        let config = makeAndroidIconsConfig(frameName: "Icons", pageName: "Components")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        // No matching components → no SVG URLs fetched → no diagnostics
        #expect(diagnostics.isEmpty)
    }

    @Test("handles empty fileId")
    func handlesEmptyFileId() async throws {
        let client = MockClient()
        let config = makeAndroidIconsConfig(lightFileId: "")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.message.contains("lightFileId") == true)
    }

    @Test("emits warning when SVG URL is unreachable")
    func emitsWarningWhenSVGUnreachable() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_home", frameName: "Icons", pageName: "Page"),
        ], for: ComponentsEndpoint.self)

        // ImageEndpoint returns a fake URL that will fail to download
        let imageURLs: [NodeId: ImagePath?] = ["1:1": "https://invalid.test/fake.svg"]
        client.setResponse(imageURLs, for: ImageEndpoint.self)

        let config = makeAndroidIconsConfig(frameName: "Icons", pageName: "Page")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        // Should get a warning about download failure, not a crash
        #expect(diagnostics.contains { $0.severity == .warning })
    }

    @Test("skips components not matching configured frame")
    func skipsComponentsNotMatchingFrame() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_a", frameName: "Icons", pageName: "Page"),
            Component.make(nodeId: "1:2", name: "ic_b", frameName: "WrongFrame", pageName: "Page"),
        ], for: ComponentsEndpoint.self)

        // Only ic_a should be checked (matches "Icons" frame)
        let imageURLs: [NodeId: ImagePath?] = ["1:1": "https://invalid.test/a.svg"]
        client.setResponse(imageURLs, for: ImageEndpoint.self)

        let config = makeAndroidIconsConfig(frameName: "Icons", pageName: "Page")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        // Only one warning for ic_a (download fails), ic_b not checked
        let warnings = diagnostics.filter { $0.severity == .warning }
        #expect(warnings.count == 1)
        #expect(warnings.first?.componentName == "ic_a")
    }

    @Test("emits error when components API fails")
    func emitsErrorWhenComponentsFail() async throws {
        let client = MockClient()
        client.setError(URLError(.notConnectedToInternet), for: ComponentsEndpoint.self)

        let config = makeAndroidIconsConfig(frameName: "Icons")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.severity == .error)
        #expect(diagnostics.first?.message.contains("Cannot fetch components") == true)
    }

    @Test("skips RTL variants")
    func skipsRTLVariants() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_home", frameName: "Icons", pageName: "Page"),
            makeVariantComponent(
                nodeId: "1:2", name: "RTL=On", frameName: "Icons", pageName: "Page",
                componentSetName: "ic_home"
            ),
        ], for: ComponentsEndpoint.self)

        let imageURLs: [NodeId: ImagePath?] = ["1:1": "https://invalid.test/home.svg"]
        client.setResponse(imageURLs, for: ImageEndpoint.self)

        let config = makeAndroidIconsConfig(frameName: "Icons", pageName: "Page")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        // Only ic_home checked, RTL variant skipped — one warning from download failure
        let warnings = diagnostics.filter { $0.severity == .warning }
        #expect(warnings.count == 1)
        #expect(warnings.first?.componentName == "ic_home")
    }

    @Test("deduplicates variants by component set")
    func deduplicatesVariants() async throws {
        let client = MockClient()
        client.setResponse([
            makeVariantComponent(
                nodeId: "1:1", name: "Style=Default", frameName: "Icons", pageName: "Page",
                componentSetName: "ic_star", componentSetNodeId: "set:1"
            ),
            makeVariantComponent(
                nodeId: "1:2", name: "Style=Filled", frameName: "Icons", pageName: "Page",
                componentSetName: "ic_star", componentSetNodeId: "set:1"
            ),
        ], for: ComponentsEndpoint.self)

        // Only one SVG URL — only first variant should be checked
        let imageURLs: [NodeId: ImagePath?] = ["1:1": "https://invalid.test/star.svg"]
        client.setResponse(imageURLs, for: ImageEndpoint.self)

        let config = makeAndroidIconsConfig(frameName: "Icons", pageName: "Page")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        // One warning from download failure — proves only one variant was checked
        let warnings = diagnostics.filter { $0.severity == .warning }
        #expect(warnings.count == 1)
    }

    @Test("warns when Figma returns nil SVG URL")
    func warnsWhenNilSVGURL() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "ic_empty", frameName: "Icons", pageName: "Page"),
        ], for: ComponentsEndpoint.self)

        // ImageEndpoint returns nil URL for the component
        let imageURLs: [NodeId: ImagePath?] = ["1:1": nil]
        client.setResponse(imageURLs, for: ImageEndpoint.self)

        let config = makeAndroidIconsConfig(frameName: "Icons", pageName: "Page")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.contains { $0.message.contains("no SVG URL") })
    }

    @Test("validates pathData and reports critical errors")
    func reportsPathDataCriticalError() {
        // Generate a path that exceeds 32,767 bytes
        let longPath = String(repeating: "M0 0L1 1", count: 5000)
        let svg = ParsedSVG(
            width: 24, height: 24, viewportWidth: 24, viewportHeight: 24,
            paths: [SVGPath(
                pathData: longPath, commands: [], fill: nil, fillType: .none,
                stroke: nil, strokeWidth: nil, strokeLineCap: nil, strokeLineJoin: nil,
                strokeDashArray: nil, strokeDashOffset: nil, fillRule: nil, opacity: nil,
                fillOpacity: nil
            )]
        )

        let diagnostics = rule.validateParsedSVG(svg, name: "ic_complex", nodeId: "1:1")

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.severity == .error)
        #expect(diagnostics.first?.message.contains("32,767 bytes") == true)
        #expect(diagnostics.first?.componentName == "ic_complex")
    }

    @Test("no error for short pathData")
    func noErrorForShortPathData() {
        let svg = ParsedSVG(
            width: 24, height: 24, viewportWidth: 24, viewportHeight: 24,
            paths: [SVGPath(
                pathData: "M12 2L22 12L12 22L2 12Z", commands: [], fill: nil, fillType: .none,
                stroke: nil, strokeWidth: nil, strokeLineCap: nil, strokeLineJoin: nil,
                strokeDashArray: nil, strokeDashOffset: nil, fillRule: nil, opacity: nil,
                fillOpacity: nil
            )]
        )

        let diagnostics = rule.validateParsedSVG(svg, name: "ic_simple", nodeId: "1:1")
        #expect(diagnostics.isEmpty)
    }
}

// MARK: - InvalidRTLVariantValueRule Tests

struct InvalidRTLVariantValueRuleTests {
    let rule = InvalidRTLVariantValueRule()

    @Test("passes when RTL variants use valid Off/On values")
    func passesWithValidValues() async throws {
        let client = MockClient()
        client.setResponse([
            makeVariantComponent(nodeId: "1:1", name: "RTL=Off", frameName: "Icons", componentSetName: "arrow"),
            makeVariantComponent(nodeId: "1:2", name: "RTL=On", frameName: "Icons", componentSetName: "arrow"),
        ], for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "Icons", rtlProperty: "RTL")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }

    @Test("error when true/false used instead of Off/On")
    func errorWhenTrueFalseUsed() async throws {
        let client = MockClient()
        client.setResponse([
            makeVariantComponent(nodeId: "1:1", name: "RTL=false", frameName: "Icons", componentSetName: "car"),
            makeVariantComponent(nodeId: "1:2", name: "RTL=true", frameName: "Icons", componentSetName: "car"),
        ], for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "Icons", rtlProperty: "RTL")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.count == 2)
        #expect(diagnostics.allSatisfy { $0.severity == .error })
        #expect(diagnostics.allSatisfy { $0.ruleId == "invalid-rtl-variant-value" })
    }

    @Test("passes for non-variant components (no containingComponentSet)")
    func passesNonVariantComponents() async throws {
        let client = MockClient()
        client.setResponse([
            Component.make(nodeId: "1:1", name: "icon_home", frameName: "Icons"),
        ], for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "Icons", rtlProperty: "RTL")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }

    @Test("passes for variants without RTL property")
    func passesComponentsWithoutRTLProperty() async throws {
        let client = MockClient()
        client.setResponse([
            makeVariantComponent(nodeId: "1:1", name: "Size=Small", frameName: "Icons", componentSetName: "button"),
        ], for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "Icons", rtlProperty: "RTL")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }

    @Test("supports custom rtlProperty name")
    func supportsCustomRTLProperty() async throws {
        let client = MockClient()
        client.setResponse([
            makeVariantComponent(nodeId: "1:1", name: "Direction=yes", frameName: "Icons", componentSetName: "arrow"),
        ], for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "Icons", rtlProperty: "Direction")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.message.contains("Direction=yes") == true)
    }

    @Test("skips entries with nil rtlProperty (RTL disabled)")
    func skipsEntriesWithNilRTLProperty() async throws {
        let client = MockClient()
        client.setResponse([
            makeVariantComponent(nodeId: "1:1", name: "RTL=true", frameName: "Icons", componentSetName: "car"),
        ], for: ComponentsEndpoint.self)

        // No rtlProperty in config → entry skipped → no diagnostics
        let config = makeIOSIconsConfig(frameName: "Icons")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }

    @Test("handles empty fileId with diagnostic")
    func handlesEmptyFileId() async throws {
        let client = MockClient()
        let config = makeIOSIconsConfig(lightFileId: "", frameName: "Icons", rtlProperty: "RTL")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.message.contains("No figma.lightFileId") == true)
    }

    @Test("emits error when components API fails")
    func emitsErrorWhenComponentsFail() async throws {
        let client = MockClient()
        client.setError(
            NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "API error"]),
            for: ComponentsEndpoint.self
        )

        let config = makeIOSIconsConfig(frameName: "Icons", rtlProperty: "RTL")
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.severity == .error)
        #expect(diagnostics.first?.message.contains("Cannot fetch components") == true)
    }

    @Test("suggests adding value to rtlActiveValues or renaming in Figma")
    func suggestsCorrectAction() {
        let entries = [InvalidRTLVariantValueRule.IconEntry(
            fileId: "abc", frameName: "Icons", pageName: nil, rtlProperty: "RTL",
            rtlActiveValues: ["On"]
        )]

        let components = [
            makeVariantComponent(nodeId: "1:1", name: "RTL=true", frameName: "Icons", componentSetName: "car"),
        ]

        let diagnostics = rule.validateRTLValues(components: components, entries: entries)

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.suggestion?.contains("rtlActiveValues") == true)
    }

    @Test("passes when rtlActiveValues includes true/false")
    func passesWithConfiguredTrueFalse() async throws {
        let client = MockClient()
        client.setResponse([
            makeVariantComponent(nodeId: "1:1", name: "RTL=false", frameName: "Icons", componentSetName: "car"),
            makeVariantComponent(nodeId: "1:2", name: "RTL=true", frameName: "Icons", componentSetName: "car"),
        ], for: ComponentsEndpoint.self)

        let config = makeIOSIconsConfig(frameName: "Icons", rtlProperty: "RTL", rtlActiveValues: ["true"])
        let context = makeLintContext(config: config, client: client)
        let diagnostics = try await rule.check(context: context)

        #expect(diagnostics.isEmpty)
    }

    @Test("validValues builds correct set from active values")
    func validValuesBuildCorrectSet() {
        let valid = InvalidRTLVariantValueRule.validValues(for: ["On"])
        #expect(valid == ["Off", "On"])

        let valid2 = InvalidRTLVariantValueRule.validValues(for: ["true"])
        #expect(valid2 == ["false", "true"])

        let valid3 = InvalidRTLVariantValueRule.validValues(for: ["On", "true"])
        #expect(valid3 == ["Off", "On", "false", "true"])

        // Custom value not in knownPairs — only the value itself, no counterpart
        let valid4 = InvalidRTLVariantValueRule.validValues(for: ["Active"])
        #expect(valid4 == ["Active"])
    }

    @Test("validates mixed valid and invalid components in same set")
    func mixedValidAndInvalidComponents() {
        let entries = [InvalidRTLVariantValueRule.IconEntry(
            fileId: "abc", frameName: "Icons", pageName: nil, rtlProperty: "RTL",
            rtlActiveValues: ["On"]
        )]

        let components = [
            makeVariantComponent(nodeId: "1:1", name: "RTL=Off", frameName: "Icons", componentSetName: "arrow"),
            makeVariantComponent(nodeId: "1:2", name: "RTL=On", frameName: "Icons", componentSetName: "arrow"),
            makeVariantComponent(nodeId: "2:1", name: "RTL=true", frameName: "Icons", componentSetName: "car"),
        ]

        let diagnostics = rule.validateRTLValues(components: components, entries: entries)

        #expect(diagnostics.count == 1)
        #expect(diagnostics.first?.message.contains("RTL=true") == true)
    }
}

// swiftlint:enable file_length
