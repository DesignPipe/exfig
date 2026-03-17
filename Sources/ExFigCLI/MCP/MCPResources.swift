import Foundation
import MCP

/// MCP resource definitions — PKL schemas and starter config templates.
enum MCPResources {
    // MARK: - Schema file names

    private static let schemaFiles = [
        "ExFig.pkl",
        "Common.pkl",
        "Figma.pkl",
        "iOS.pkl",
        "Android.pkl",
        "Flutter.pkl",
        "Web.pkl",
    ]

    // MARK: - Template entries

    private static let templateEntries: [(name: String, platform: String, content: String)] = [
        ("iOS Starter Config", "ios", iosConfigFileContents),
        ("Android Starter Config", "android", androidConfigFileContents),
        ("Flutter Starter Config", "flutter", flutterConfigFileContents),
        ("Web Starter Config", "web", webConfigFileContents),
    ]

    // MARK: - Public API

    static var allResources: [Resource] {
        var resources: [Resource] = []

        // PKL schemas
        for file in schemaFiles {
            let name = file.replacingOccurrences(of: ".pkl", with: "")
            resources.append(Resource(
                name: "\(name) Schema",
                uri: "exfig://schemas/\(file)",
                description: "PKL schema for ExFig \(name) configuration",
                mimeType: "text/plain"
            ))
        }

        // Config templates
        for entry in templateEntries {
            resources.append(Resource(
                name: entry.name,
                uri: "exfig://templates/\(entry.platform)",
                description: "Starter PKL config template for \(entry.platform) platform",
                mimeType: "text/plain"
            ))
        }

        return resources
    }

    static func read(uri: String) throws -> ReadResource.Result {
        // Schema resources
        if uri.hasPrefix("exfig://schemas/") {
            let fileName = String(uri.dropFirst("exfig://schemas/".count))
            guard schemaFiles.contains(fileName) else {
                throw MCPError.invalidParams("Unknown schema: \(fileName)")
            }

            let content = try loadSchemaContent(fileName: fileName)
            return .init(contents: [Resource.Content.text(content, uri: uri, mimeType: "text/plain")])
        }

        // Template resources
        if uri.hasPrefix("exfig://templates/") {
            let platform = String(uri.dropFirst("exfig://templates/".count))
            guard let entry = templateEntries.first(where: { $0.platform == platform }) else {
                throw MCPError.invalidParams("Unknown template platform: \(platform)")
            }

            return .init(contents: [Resource.Content.text(entry.content, uri: uri, mimeType: "text/plain")])
        }

        throw MCPError.invalidParams("Unknown resource URI: \(uri)")
    }

    // MARK: - Schema Loading

    private static func loadSchemaContent(fileName: String) throws -> String {
        // Load from Bundle.module (SPM resource bundle)
        guard let url = Bundle.module.url(forResource: fileName, withExtension: nil, subdirectory: "Schemas") else {
            throw MCPError.invalidParams("Schema file not found in bundle: \(fileName)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
