# MCP Server

Integrate ExFig with AI assistants via the Model Context Protocol.

## Overview

ExFig includes an [MCP](https://modelcontextprotocol.io) server that exposes tools, resources,
and prompts over stdio. This lets AI coding assistants (Claude Code, Cursor, Codex, etc.) validate
configs, inspect Figma files, and work with design tokens — without leaving the editor.

## Starting the Server

```bash
exfig mcp
```

The server communicates over stdin/stdout using JSON-RPC. All CLI output goes to stderr to avoid
protocol interference.

## Client Configuration

Add to your `.mcp.json` (Claude Code, Cursor, Codex):

```json
{
  "mcpServers": {
    "exfig": {
      "command": "exfig",
      "args": ["mcp"],
      "env": {
        "FIGMA_PERSONAL_TOKEN": "figd_..."
      }
    }
  }
}
```

> Tip: The Figma token is optional. Tools that don't access the Figma API (config validation,
> token file inspection) work without it.

## Available Tools

| Tool                | Description                      | Requires Token |
| ------------------- | -------------------------------- | -------------- |
| `exfig_validate`    | Validate a PKL config file       | No             |
| `exfig_tokens_info` | Inspect a local `.tokens.json`   | No             |
| `exfig_inspect`     | List resources in a Figma file   | Yes            |

## Resources

The server exposes read-only resources:

- **PKL schemas** (`exfig://schemas/*.pkl`) — ExFig, iOS, Android, Flutter, Web, Common, Figma
- **Config templates** (`exfig://templates/{ios,android,flutter,web}`) — starter configs for each platform

AI assistants can read these to understand config structure and generate valid configurations.

## Prompts

| Prompt                | Description                                   |
| --------------------- | --------------------------------------------- |
| `setup-config`        | Guide through creating an `exfig.pkl` config  |
| `troubleshoot-export` | Diagnose and fix export errors                |

## See Also

- <doc:Usage>
- <doc:Configuration>
- <doc:GettingStarted>
