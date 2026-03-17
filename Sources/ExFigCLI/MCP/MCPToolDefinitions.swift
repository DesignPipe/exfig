import MCP

/// Tool schemas for all ExFig MCP tools.
enum MCPToolDefinitions {
    static let allTools: [Tool] = [
        validateTool,
        tokensInfoTool,
        inspectTool,
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
}
