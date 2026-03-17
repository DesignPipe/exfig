import MCP

/// MCP prompt definitions for guided AI workflows.
enum MCPPrompts {
    static let allPrompts: [Prompt] = [
        setupConfigPrompt,
        troubleshootPrompt,
    ]

    // MARK: - Prompt Definitions

    private static let setupConfigPrompt = Prompt(
        name: "setup-config",
        description: "Guide through creating an exfig.pkl configuration file for a specific platform",
        arguments: [
            .init(name: "platform", description: "Target platform: ios, android, flutter, or web", required: true),
            .init(
                name: "project_path",
                description: "Path to the project directory (defaults to current directory)"
            ),
        ]
    )

    private static let troubleshootPrompt = Prompt(
        name: "troubleshoot-export",
        description: "Diagnose and fix ExFig export errors",
        arguments: [
            .init(name: "error_message", description: "The error message from the failed export", required: true),
            .init(
                name: "config_path",
                description: "Path to the PKL config file used during export"
            ),
        ]
    )

    // MARK: - Get Prompt

    static func get(name: String, arguments: [String: Value]?) throws -> GetPrompt.Result {
        switch name {
        case "setup-config":
            return try getSetupConfig(arguments: arguments)
        case "troubleshoot-export":
            return try getTroubleshoot(arguments: arguments)
        default:
            throw MCPError.invalidParams("Unknown prompt: \(name)")
        }
    }

    // MARK: - Setup Config

    private static func getSetupConfig(arguments: [String: Value]?) throws -> GetPrompt.Result {
        guard let platform = arguments?["platform"]?.stringValue else {
            throw MCPError.invalidParams("Missing required argument: platform")
        }

        let projectPath = arguments?["project_path"]?.stringValue ?? "."

        let validPlatforms = ["ios", "android", "flutter", "web"]
        guard validPlatforms.contains(platform) else {
            throw MCPError.invalidParams(
                "Invalid platform '\(platform)'. Must be one of: \(validPlatforms.joined(separator: ", "))"
            )
        }

        let schemaName = platform == "ios" ? "iOS" : platform.capitalized

        let text = """
        I need to create an exfig.pkl configuration file for the \(platform) platform \
        in the project at \(projectPath).

        Please help me:
        1. Read the ExFig \(schemaName) schema (use exfig://schemas/\(schemaName).pkl resource)
        2. Read the starter template (use exfig://templates/\(platform) resource)
        3. Examine my project structure to determine correct output paths
        4. Create a properly configured exfig.pkl file

        I need to set:
        - Figma file ID(s) for my design files
        - Output paths matching my project structure
        - Entry configurations for colors, icons, and/or images

        First, validate the config with exfig_validate after creating it.
        """

        return .init(
            description: "Setup ExFig \(platform) configuration at \(projectPath)",
            messages: [.user(.text(text: text))]
        )
    }

    // MARK: - Troubleshoot

    private static func getTroubleshoot(arguments: [String: Value]?) throws -> GetPrompt.Result {
        guard let errorMessage = arguments?["error_message"]?.stringValue else {
            throw MCPError.invalidParams("Missing required argument: error_message")
        }

        let configPath = arguments?["config_path"]?.stringValue ?? "exfig.pkl"

        let text = """
        I'm getting this error when running ExFig export:

        ```
        \(errorMessage)
        ```

        Config file: \(configPath)

        Please help me diagnose and fix this error:
        1. First, validate the config with exfig_validate (config_path: "\(configPath)")
        2. Check if FIGMA_PERSONAL_TOKEN is set if the error is auth-related
        3. If it's a PKL error, read the relevant schema to understand the expected structure
        4. Suggest specific fixes with code examples
        """

        return .init(
            description: "Troubleshoot ExFig export error",
            messages: [.user(.text(text: text))]
        )
    }
}
