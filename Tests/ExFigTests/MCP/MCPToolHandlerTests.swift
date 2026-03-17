@testable import ExFigCLI
import Foundation
import MCP
import Testing

@Suite("MCP Tool Handlers")
struct MCPToolHandlerTests {
    // MARK: - Validate Tool

    @Test("validate returns error for missing config")
    func validateMissingConfig() async {
        let params = CallTool.Parameters(
            name: "exfig_validate",
            arguments: ["config_path": .string("/nonexistent/path.pkl")]
        )

        let result = await MCPToolHandlers.handle(params: params, state: MCPServerState())

        #expect(result.isError == true)
        if case let .text(text) = result.content.first {
            #expect(text.contains("not found"))
        }
    }

    @Test("validate auto-detects exfig.pkl when no path given")
    func validateAutoDetect() async {
        let params = CallTool.Parameters(
            name: "exfig_validate",
            arguments: nil
        )

        // No exfig.pkl in working directory → error with helpful message
        let result = await MCPToolHandlers.handle(params: params, state: MCPServerState())

        #expect(result.isError == true)
        if case let .text(text) = result.content.first {
            #expect(text.contains("exfig.pkl"))
        }
    }

    // MARK: - Tokens Info Tool

    @Test("tokens_info returns error for missing file_path")
    func tokensInfoMissingParam() async {
        let params = CallTool.Parameters(
            name: "exfig_tokens_info",
            arguments: nil
        )

        let result = await MCPToolHandlers.handle(params: params, state: MCPServerState())

        #expect(result.isError == true)
        if case let .text(text) = result.content.first {
            #expect(text.contains("file_path"))
        }
    }

    @Test("tokens_info returns error for nonexistent file")
    func tokensInfoFileNotFound() async {
        let params = CallTool.Parameters(
            name: "exfig_tokens_info",
            arguments: ["file_path": .string("/tmp/nonexistent.tokens.json")]
        )

        let result = await MCPToolHandlers.handle(params: params, state: MCPServerState())

        #expect(result.isError == true)
        if case let .text(text) = result.content.first {
            #expect(text.contains("not found"))
        }
    }

    @Test("tokens_info parses valid tokens file")
    func tokensInfoValid() async throws {
        let json = """
        {
            "$type": "color",
            "Brand": {
                "Primary": {
                    "$value": {
                        "colorSpace": "srgb",
                        "components": [0.2, 0.4, 0.8],
                        "alpha": 1.0
                    }
                },
                "Secondary": {
                    "$value": {
                        "colorSpace": "srgb",
                        "components": [0.8, 0.2, 0.4],
                        "alpha": 1.0
                    }
                }
            },
            "Spacing": {
                "$type": "dimension",
                "Small": {
                    "$value": { "value": 8, "unit": "px" }
                }
            }
        }
        """

        let tmpFile = NSTemporaryDirectory() + "mcp_test_tokens.json"
        try json.write(toFile: tmpFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: tmpFile) }

        let params = CallTool.Parameters(
            name: "exfig_tokens_info",
            arguments: ["file_path": .string(tmpFile)]
        )

        let result = await MCPToolHandlers.handle(params: params, state: MCPServerState())

        #expect(result.isError != true)

        if case let .text(text) = result.content.first {
            #expect(text.contains("total_tokens"))
            #expect(text.contains("counts_by_type"))
            #expect(text.contains("top_level_groups"))
        }
    }

    // MARK: - Unknown Tool

    @Test("unknown tool returns error")
    func unknownTool() async {
        let params = CallTool.Parameters(
            name: "nonexistent_tool",
            arguments: nil
        )

        let result = await MCPToolHandlers.handle(params: params, state: MCPServerState())

        #expect(result.isError == true)
        if case let .text(text) = result.content.first {
            #expect(text.contains("Unknown tool"))
        }
    }

    // MARK: - Inspect Tool

    @Test("inspect returns error without FIGMA_PERSONAL_TOKEN")
    func inspectNoToken() async {
        let params = CallTool.Parameters(
            name: "exfig_inspect",
            arguments: [
                "config_path": .string("/nonexistent.pkl"),
                "resource_type": .string("colors"),
            ]
        )

        let result = await MCPToolHandlers.handle(params: params, state: MCPServerState())

        #expect(result.isError == true)
    }

    @Test("inspect returns error for missing resource_type")
    func inspectMissingResourceType() async {
        let params = CallTool.Parameters(
            name: "exfig_inspect",
            arguments: ["config_path": .string("exfig.pkl")]
        )

        let result = await MCPToolHandlers.handle(params: params, state: MCPServerState())

        #expect(result.isError == true)
    }
}
