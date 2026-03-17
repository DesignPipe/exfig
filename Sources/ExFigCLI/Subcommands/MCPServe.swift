import ArgumentParser
import Foundation

struct MCPServe: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mcp",
        abstract: "Start MCP (Model Context Protocol) server for AI agent integration",
        discussion: """
        Starts a JSON-RPC server over stdin/stdout using the Model Context Protocol.
        AI agents (Claude Code, Cursor, etc.) can use this server to validate configs,
        inspect Figma resources, and run exports programmatically.

        All CLI output is redirected to stderr to keep stdout clean for JSON-RPC.
        """
    )

    func run() async throws {
        // MCP mode: all output goes to stderr, stdout is reserved for JSON-RPC
        let outputMode = OutputMode.mcp
        ExFigLogging.bootstrap(outputMode: outputMode)
        TerminalOutputManager.shared.setStderrMode(true)

        ExFigCommand.terminalUI = TerminalUI(outputMode: outputMode)

        let server = ExFigMCPServer()
        try await server.run()
    }
}
