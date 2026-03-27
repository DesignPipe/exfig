@testable import ExFigCLI
import ExFigCore
import FigmaAPI
import Foundation

// MARK: - PKLConfig.Figma Extension

extension PKLConfig.Figma {
    /// Creates a PKLConfig.Figma for testing with minimal required fields.
    static func make(
        lightFileId: String,
        darkFileId: String? = nil,
        lightHighContrastFileId: String? = nil,
        darkHighContrastFileId: String? = nil,
        timeout: TimeInterval? = nil
    ) -> PKLConfig.Figma {
        let json = """
        {
            "lightFileId": "\(lightFileId)"
            \(darkFileId.map { ", \"darkFileId\": \"\($0)\"" } ?? "")
            \(lightHighContrastFileId.map { ", \"lightHighContrastFileId\": \"\($0)\"" } ?? "")
            \(darkHighContrastFileId.map { ", \"darkHighContrastFileId\": \"\($0)\"" } ?? "")
            \(timeout.map { ", \"timeout\": \($0)" } ?? "")
        }
        """
        // swiftlint:disable:next force_try
        return try! JSONCodec.decode(PKLConfig.Figma.self, from: Data(json.utf8))
    }
}

// MARK: - PKLConfig.Common.Colors Extension

extension PKLConfig.Common.Colors {
    /// Creates a PKLConfig.Common.Colors for testing.
    static func make(
        suffixDarkMode: String? = nil,
        lightHCModeSuffix: String? = nil,
        darkHCModeSuffix: String? = nil
    ) -> PKLConfig.Common.Colors {
        var components: [String] = []
        if let suffixDarkMode {
            components.append("\"suffixDarkMode\": { \"suffix\": \"\(suffixDarkMode)\" }")
        }
        if let lightHCModeSuffix {
            components.append("\"lightHCModeSuffix\": \"\(lightHCModeSuffix)\"")
        }
        if let darkHCModeSuffix {
            components.append("\"darkHCModeSuffix\": \"\(darkHCModeSuffix)\"")
        }

        let json = "{ \(components.joined(separator: ", ")) }"
        // swiftlint:disable:next force_try
        return try! JSONCodec.decode(PKLConfig.Common.Colors.self, from: Data(json.utf8))
    }
}

// MARK: - Node Extension for Testing

extension Node {
    /// Creates a Node for testing color extraction.
    static func makeColor(
        r: Double,
        g: Double,
        b: Double,
        a: Double,
        opacity: Double? = nil
    ) -> Node {
        let json = """
        {
            "document": {
                "id": "test",
                "name": "test",
                "fills": [
                    {
                        "type": "SOLID",
                        "opacity": \(opacity ?? 1.0),
                        "color": {
                            "r": \(r),
                            "g": \(g),
                            "b": \(b),
                            "a": \(a)
                        }
                    }
                ]
            }
        }
        """
        // swiftlint:disable:next force_try
        return try! JSONCodec.decode(Node.self, from: Data(json.utf8))
    }
}

// MARK: - Style Extension for Testing

extension Style {
    /// Creates a Style for testing.
    static func make(
        styleType: StyleType = .fill,
        nodeId: String,
        name: String,
        description: String = ""
    ) -> Style {
        Style(styleType: styleType, nodeId: nodeId, name: name, description: description)
    }
}

// MARK: - PKLConfig.Common.VariablesColors Extension

extension PKLConfig.Common.VariablesColors {
    /// Creates a PKLConfig.Common.VariablesColors for testing.
    static func make(
        tokensFileId: String,
        tokensCollectionName: String,
        lightModeName: String = "Light",
        darkModeName: String = "Dark",
        lightHCModeName: String? = nil,
        darkHCModeName: String? = nil,
        primitivesModeName: String? = nil
    ) -> PKLConfig.Common.VariablesColors {
        var components: [String] = [
            "\"tokensFileId\": \"\(tokensFileId)\"",
            "\"tokensCollectionName\": \"\(tokensCollectionName)\"",
            "\"lightModeName\": \"\(lightModeName)\"",
            "\"darkModeName\": \"\(darkModeName)\"",
        ]
        if let lightHCModeName {
            components.append("\"lightHCModeName\": \"\(lightHCModeName)\"")
        }
        if let darkHCModeName {
            components.append("\"darkHCModeName\": \"\(darkHCModeName)\"")
        }
        if let primitivesModeName {
            components.append("\"primitivesModeName\": \"\(primitivesModeName)\"")
        }

        let json = "{ \(components.joined(separator: ", ")) }"
        // swiftlint:disable:next force_try
        return try! JSONCodec.decode(PKLConfig.Common.VariablesColors.self, from: Data(json.utf8))
    }
}

// MARK: - Component Extension

extension Component {
    /// Creates a Component for testing.
    static func make(
        key: String = "test-key",
        nodeId: String,
        name: String,
        description: String? = nil,
        frameName: String = "Icons",
        pageName: String = "Components"
    ) -> Component {
        var json = """
        {
            "key": "\(key)",
            "node_id": "\(nodeId)",
            "name": "\(name)",
            "containing_frame": {
                "nodeId": "\(nodeId)",
                "name": "\(frameName)",
                "pageName": "\(pageName)"
            }
        """
        if let description {
            json = json.replacingOccurrences(
                of: "\"containing_frame\"",
                with: "\"description\": \"\(description)\", \"containing_frame\""
            )
        }
        json += "}"

        // Model uses explicit CodingKeys for snake_case mapping
        // swiftlint:disable:next force_try
        return try! JSONCodec.decode(Component.self, from: Data(json.utf8))
    }
}

// MARK: - PKLConfig Extension

extension PKLConfig {
    /// Creates a minimal PKLConfig for testing image loading.
    static func make(
        lightFileId: String,
        darkFileId: String? = nil,
        iconsFrameName: String? = nil,
        iconsPageName: String? = nil,
        imagesFrameName: String? = nil,
        imagesPageName: String? = nil,
        iconsSuffixDarkMode: String? = nil,
        imagesSuffixDarkMode: String? = nil
    ) -> PKLConfig {
        var commonComponents: [String] = []

        if iconsFrameName != nil || iconsPageName != nil || iconsSuffixDarkMode != nil {
            var iconParts: [String] = []
            if let frameName = iconsFrameName {
                iconParts.append("\"figmaFrameName\": \"\(frameName)\"")
            }
            if let pageName = iconsPageName {
                iconParts.append("\"figmaPageName\": \"\(pageName)\"")
            }
            if let suffix = iconsSuffixDarkMode {
                iconParts.append("\"suffixDarkMode\": { \"suffix\": \"\(suffix)\" }")
            }
            commonComponents.append("\"icons\": { \(iconParts.joined(separator: ", ")) }")
        }

        if imagesFrameName != nil || imagesPageName != nil || imagesSuffixDarkMode != nil {
            var imageParts: [String] = []
            if let frameName = imagesFrameName {
                imageParts.append("\"figmaFrameName\": \"\(frameName)\"")
            }
            if let pageName = imagesPageName {
                imageParts.append("\"figmaPageName\": \"\(pageName)\"")
            }
            if let suffix = imagesSuffixDarkMode {
                imageParts.append("\"suffixDarkMode\": { \"suffix\": \"\(suffix)\" }")
            }
            commonComponents.append("\"images\": { \(imageParts.joined(separator: ", ")) }")
        }

        let commonJson = commonComponents.isEmpty ? "" : ", \"common\": { \(commonComponents.joined(separator: ", ")) }"
        let darkJson = darkFileId.map { ", \"darkFileId\": \"\($0)\"" } ?? ""

        let json = """
        {
            "figma": {
                "lightFileId": "\(lightFileId)"\(darkJson)
            }\(commonJson)
        }
        """

        // swiftlint:disable:next force_try
        return try! JSONCodec.decode(PKLConfig.self, from: Data(json.utf8))
    }
}

// MARK: - VariablesMeta Extension

/// Value that can be either a color or an alias to another variable.
enum TestVariableValue {
    case color(r: Double, g: Double, b: Double, a: Double)
    case alias(String) // Reference to another variable ID
}

extension VariablesMeta {
    /// Creates a VariablesMeta for testing with specified colors and modes.
    static func make(
        collectionName: String = "Colors",
        modes: [(id: String, name: String)] = [("1:0", "Light"), ("1:1", "Dark")],
        variables: [(id: String, name: String, valuesByMode: [String: (r: Double, g: Double, b: Double, a: Double)])]
    ) -> VariablesMeta {
        let converted: [(id: String, name: String, collectionId: String?, valuesByMode: [String: TestVariableValue])]
        converted = variables.map { variable in
            let values = variable.valuesByMode.mapValues { color in
                TestVariableValue.color(r: color.r, g: color.g, b: color.b, a: color.a)
            }
            return (variable.id, variable.name, nil, values)
        }
        return makeWithAliases(
            collectionName: collectionName,
            modes: modes,
            variables: converted,
            primitiveCollections: []
        )
    }

    // swiftlint:disable function_body_length large_tuple
    /// Creates a VariablesMeta with support for variable aliases.
    /// This allows testing alias resolution where one variable references another.
    static func makeWithAliases(
        collectionName: String = "Colors",
        modes: [(id: String, name: String)] = [("1:0", "Light"), ("1:1", "Dark")],
        variables: [(id: String, name: String, collectionId: String?, valuesByMode: [String: TestVariableValue])],
        primitiveCollections: [(
            id: String, name: String, defaultModeId: String, modes: [(id: String, name: String)],
            variableIds: [String]
        )] = [],
        deletedVariableIds: Set<String> = []
    ) -> VariablesMeta {
        // swiftlint:enable function_body_length large_tuple
        let modesJson = modes.map { mode in
            "{\"modeId\": \"\(mode.id)\", \"name\": \"\(mode.name)\"}"
        }.joined(separator: ", ")

        // Only include variables from main collection in variable_ids
        let mainCollectionVariableIds = variables
            .filter { $0.collectionId == nil || $0.collectionId == "VariableCollectionId:1:1" }
            .map { "\"VariableID:\($0.id)\"" }
            .joined(separator: ", ")

        // Build variables JSON
        let variablesJson = variables.map { variable in
            let valuesJson = variable.valuesByMode.map { modeId, value in
                switch value {
                case let .color(r, g, b, a):
                    "\"\(modeId)\": {\"r\": \(r), \"g\": \(g), \"b\": \(b), \"a\": \(a)}"
                case let .alias(refId):
                    "\"\(modeId)\": {\"id\": \"VariableID:\(refId)\", \"type\": \"VARIABLE_ALIAS\"}"
                }
            }.joined(separator: ", ")

            let collectionId = variable.collectionId ?? "VariableCollectionId:1:1"
            let deletedJson = deletedVariableIds.contains(variable.id)
                ? ",\n            \"deletedButReferenced\": true"
                : ""

            return """
            "VariableID:\(variable.id)": {
                "id": "VariableID:\(variable.id)",
                "name": "\(variable.name)",
                "variableCollectionId": "\(collectionId)",
                "valuesByMode": { \(valuesJson) },
                "description": ""\(deletedJson)
            }
            """
        }.joined(separator: ", ")

        // Build primitive collections JSON
        var collectionsJson = """
        "VariableCollectionId:1:1": {
            "defaultModeId": "\(modes.first?.id ?? "1:0")",
            "id": "VariableCollectionId:1:1",
            "name": "\(collectionName)",
            "modes": [\(modesJson)],
            "variableIds": [\(mainCollectionVariableIds)]
        }
        """

        for collection in primitiveCollections {
            let primModesJson = collection.modes.map { mode in
                "{\"modeId\": \"\(mode.id)\", \"name\": \"\(mode.name)\"}"
            }.joined(separator: ", ")
            let primVarIds = collection.variableIds.map { "\"VariableID:\($0)\"" }.joined(separator: ", ")

            collectionsJson += """
            ,
            "\(collection.id)": {
                "defaultModeId": "\(collection.defaultModeId)",
                "id": "\(collection.id)",
                "name": "\(collection.name)",
                "modes": [\(primModesJson)],
                "variableIds": [\(primVarIds)]
            }
            """
        }

        let json = """
        {
            "variableCollections": { \(collectionsJson) },
            "variables": { \(variablesJson) }
        }
        """

        // JSON uses camelCase keys matching real Figma API responses
        // swiftlint:disable:next force_try
        return try! JSONCodec.decode(VariablesMeta.self, from: Data(json.utf8))
    }
}
