import MCP

/// Tool schemas for all ExFig MCP tools.
enum MCPToolDefinitions {
    static let allTools: [Tool] = [
        validateTool,
        tokensInfoTool,
        inspectTool,
        exportTool,
        downloadTool,
    ]

    // MARK: - Tool Definitions

    static let validateTool = Tool(
        name: "exfig_validate",
        description: """
        Validate an ExFig PKL configuration file. Returns a JSON summary with platforms, \
        entry counts, and file IDs — or the full PKL error if validation fails. \
        Does not require FIGMA_PERSONAL_TOKEN.
        """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "config_path": .object([
                    "type": .string("string"),
                    "description": .string(
                        "Path to PKL config file. Auto-detects exfig.pkl in current directory if omitted."
                    ),
                ]),
            ]),
        ])
    )

    static let tokensInfoTool = Tool(
        name: "exfig_tokens_info",
        description: """
        Inspect a W3C DTCG .tokens.json file. Returns token counts by type, \
        top-level groups, alias count, and any parse warnings. \
        Does not require FIGMA_PERSONAL_TOKEN.
        """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "file_path": .object([
                    "type": .string("string"),
                    "description": .string("Path to the .tokens.json file"),
                ]),
            ]),
            "required": .array([.string("file_path")]),
        ])
    )

    static let inspectTool = Tool(
        name: "exfig_inspect",
        description: """
        List Figma resources (colors, icons, images, typography) without exporting. \
        Returns JSON with resource names, counts, and metadata. \
        Requires FIGMA_PERSONAL_TOKEN.
        """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "config_path": .object([
                    "type": .string("string"),
                    "description": .string(
                        "Path to PKL config file. Auto-detects exfig.pkl if omitted."
                    ),
                ]),
                "resource_type": .object([
                    "type": .string("string"),
                    "description": .string(
                        "Type of resources to inspect"
                    ),
                    "enum": .array([
                        .string("colors"),
                        .string("icons"),
                        .string("images"),
                        .string("typography"),
                        .string("all"),
                    ]),
                ]),
            ]),
            "required": .array([.string("resource_type")]),
        ])
    )
    static let exportTool = Tool(
        name: "exfig_export",
        description: """
        Run platform code export (Swift/Kotlin/Dart/CSS) from PKL config. \
        Writes generated files to disk and returns a structured JSON report. \
        Requires FIGMA_PERSONAL_TOKEN.
        """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "resource_type": .object([
                    "type": .string("string"),
                    "description": .string("Type of resources to export"),
                    "enum": .array([
                        .string("colors"),
                        .string("icons"),
                        .string("images"),
                        .string("typography"),
                        .string("all"),
                    ]),
                ]),
                "config_path": .object([
                    "type": .string("string"),
                    "description": .string(
                        "Path to PKL config file. Auto-detects exfig.pkl in current directory if omitted."
                    ),
                ]),
                "filter": .object([
                    "type": .string("string"),
                    "description": .string("Filter by name pattern (e.g., \"background/*\")"),
                ]),
                "rate_limit": .object([
                    "type": .string("integer"),
                    "description": .string("Figma API requests per minute (default: 10)"),
                ]),
                "max_retries": .object([
                    "type": .string("integer"),
                    "description": .string("Max retry attempts (default: 4)"),
                ]),
                "cache": .object([
                    "type": .string("boolean"),
                    "description": .string("Enable version tracking cache (default: false)"),
                ]),
                "force": .object([
                    "type": .string("boolean"),
                    "description": .string("Force export ignoring cache (default: false)"),
                ]),
                "granular_cache": .object([
                    "type": .string("boolean"),
                    "description": .string("Enable per-node granular cache (default: false)"),
                ]),
            ]),
            "required": .array([.string("resource_type")]),
        ])
    )

    static let downloadTool = Tool(
        name: "exfig_download",
        description: """
        Export design data from Figma as W3C Design Tokens JSON. \
        Returns JSON directly in the response — does not write files. \
        Requires FIGMA_PERSONAL_TOKEN.
        """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "resource_type": .object([
                    "type": .string("string"),
                    "description": .string("Type of design data to export"),
                    "enum": .array([
                        .string("colors"),
                        .string("typography"),
                        .string("tokens"),
                    ]),
                ]),
                "config_path": .object([
                    "type": .string("string"),
                    "description": .string(
                        "Path to PKL config file. Auto-detects exfig.pkl if omitted."
                    ),
                ]),
                "format": .object([
                    "type": .string("string"),
                    "description": .string("Token format: w3c (default) or raw"),
                    "enum": .array([
                        .string("w3c"),
                        .string("raw"),
                    ]),
                ]),
                "filter": .object([
                    "type": .string("string"),
                    "description": .string("Filter by name pattern. Only for colors."),
                ]),
            ]),
            "required": .array([.string("resource_type")]),
        ])
    )
}
