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
            .init(name: "source", description: "Design source: figma (default) or penpot"),
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

        let source = arguments?["source"]?.stringValue ?? "figma"
        let projectPath = arguments?["project_path"]?.stringValue ?? "."

        let validPlatforms = ["ios", "android", "flutter", "web"]
        guard validPlatforms.contains(platform) else {
            throw MCPError.invalidParams(
                "Invalid platform '\(platform)'. Must be one of: \(validPlatforms.joined(separator: ", "))"
            )
        }

        let validSources = ["figma", "penpot"]
        guard validSources.contains(source) else {
            throw MCPError.invalidParams(
                "Invalid source '\(source)'. Must be one of: \(validSources.joined(separator: ", "))"
            )
        }

        if source == "penpot" {
            return try getSetupConfigPenpot(platform: platform, projectPath: projectPath)
        }

        return try getSetupConfigFigma(platform: platform, projectPath: projectPath)
    }

    private static func getSetupConfigFigma(platform: String, projectPath: String) throws -> GetPrompt.Result {
        let schemaName = platform == "ios" ? "iOS" : platform.capitalized

        let text = """
        I need to create an exfig.pkl configuration file for the \(platform) platform \
        in the project at \(projectPath).

        Please help me:
        1. Read the ExFig \(schemaName) schema (use exfig://schemas/\(schemaName).pkl resource)
        2. Read the starter template (use exfig://templates/\(platform) resource)
        3. Read the design file structure guide (use exfig://guides/DesignRequirements.md resource)
        4. Examine my project structure to determine correct output paths
        5. Create a properly configured exfig.pkl file

        I need to set:
        - Figma file ID(s) for my design files
        - Output paths matching my project structure
        - Entry configurations for colors, icons, and/or images

        First, validate the config with exfig_validate after creating it.
        """

        return .init(
            description: "Setup ExFig \(platform) configuration with Figma at \(projectPath)",
            messages: [.user(.text(text: text))]
        )
    }

    // swiftlint:disable function_body_length
    private static func getSetupConfigPenpot(platform: String, projectPath: String) throws -> GetPrompt.Result {
        let schemaName = platform == "ios" ? "iOS" : platform.capitalized

        let text = """
        I need to create an exfig.pkl configuration file for the \(platform) platform \
        using **Penpot** as the design source in the project at \(projectPath).

        Please help me:
        1. Read the Common schema for PenpotSource (use exfig://schemas/Common.pkl resource)
        2. Read the \(schemaName) schema (use exfig://schemas/\(schemaName).pkl resource)
        3. Read the design file structure guide (use exfig://guides/DesignRequirements.md resource) \
        — focus on the Penpot section
        4. Read the starter template (use exfig://templates/\(platform) resource)
        5. Examine my project structure to determine correct output paths
        6. Create a properly configured exfig.pkl file with penpotSource entries

        I need to set:
        - Penpot file UUID (from the Penpot workspace URL)
        - Optional: custom Penpot instance URL (if self-hosted, default: design.penpot.app)
        - Path filters matching my Penpot library structure
        - Output paths matching my project structure

        Important notes:
        - PENPOT_ACCESS_TOKEN must be set (not FIGMA_PERSONAL_TOKEN)
        - No `figma` section needed when using only Penpot sources
        - v1 limitation: icons/images export as raster thumbnails only

        First, validate the config with exfig_validate after creating it.
        """

        return .init(
            description: "Setup ExFig \(platform) configuration with Penpot at \(projectPath)",
            messages: [.user(.text(text: text))]
        )
    }

    // swiftlint:enable function_body_length

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
        2. Check authentication:
           - If the error mentions Figma or 401: check FIGMA_PERSONAL_TOKEN
           - If the error mentions Penpot or PENPOT_ACCESS_TOKEN: check PENPOT_ACCESS_TOKEN
           - For Penpot "malformed-json" errors: ensure ExFig is up to date
        3. If it's a PKL error, read the relevant schema to understand the expected structure
        4. Read the design file structure guide (exfig://guides/DesignRequirements.md) for \
        file preparation requirements
        5. Suggest specific fixes with code examples
        """

        return .init(
            description: "Troubleshoot ExFig export error",
            messages: [.user(.text(text: text))]
        )
    }
}
