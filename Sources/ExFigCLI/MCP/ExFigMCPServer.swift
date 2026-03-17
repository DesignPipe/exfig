import Foundation
import Logging
import MCP

/// Main MCP server lifecycle manager.
/// Sets up the server, registers all handlers, and runs with StdioTransport.
struct ExFigMCPServer {
    private let logger = Logger(label: "com.designpipe.exfig.mcp")

    func run() async throws {
        let server = Server(
            name: "exfig",
            version: ExFigCommand.version,
            capabilities: .init(
                prompts: .init(listChanged: false),
                resources: .init(subscribe: false, listChanged: false),
                tools: .init(listChanged: false)
            )
        )

        let state = MCPServerState()

        // Register all handlers
        await registerToolHandlers(server: server, state: state)
        await registerResourceHandlers(server: server)
        await registerPromptHandlers(server: server)

        // Start with stdio transport
        let transport = StdioTransport(logger: logger)
        try await server.start(transport: transport)

        // Keep running until cancelled
        try await Task.sleep(for: .seconds(365 * 24 * 3600))
    }

    // MARK: - Tool Handlers

    private func registerToolHandlers(server: Server, state: MCPServerState) async {
        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: MCPToolDefinitions.allTools)
        }

        await server.withMethodHandler(CallTool.self) { params in
            await MCPToolHandlers.handle(params: params, state: state)
        }
    }

    // MARK: - Resource Handlers

    private func registerResourceHandlers(server: Server) async {
        await server.withMethodHandler(ListResources.self) { _ in
            .init(resources: MCPResources.allResources, nextCursor: nil)
        }

        await server.withMethodHandler(ReadResource.self) { params in
            try MCPResources.read(uri: params.uri)
        }
    }

    // MARK: - Prompt Handlers

    private func registerPromptHandlers(server: Server) async {
        await server.withMethodHandler(ListPrompts.self) { _ in
            .init(prompts: MCPPrompts.allPrompts, nextCursor: nil)
        }

        await server.withMethodHandler(GetPrompt.self) { params in
            try MCPPrompts.get(name: params.name, arguments: params.arguments)
        }
    }
}
