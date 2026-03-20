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

| Tool                | Description                                          | Requires Token |
| ------------------- | ---------------------------------------------------- | -------------- |
| `exfig_validate`    | Validate a PKL config file                           | No             |
| `exfig_tokens_info` | Inspect a local `.tokens.json`                       | No             |
| `exfig_inspect`     | List resources in a Figma file                       | Yes            |
| `exfig_export`      | Run code export (writes files, returns JSON report)  | Yes            |
| `exfig_download`    | Export W3C Design Tokens JSON (inline, no file I/O)  | Yes            |

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

## Claude Code Plugins

For a turnkey Claude Code experience, install the
[exfig-plugins](https://github.com/DesignPipe/exfig-plugins) marketplace:

```bash
claude /plugin marketplace add https://github.com/DesignPipe/exfig-plugins
```

The marketplace includes:

| Plugin | What it does |
| ------ | ------------ |
| **exfig-mcp** | Pre-configured `.mcp.json` + usage skill |
| **exfig-setup** | Interactive wizard: install → token → config → first export → CI |
| **exfig-export** | `/export-colors`, `/export-icons`, `/export-images`, `/export-all` commands |
| **exfig-config-review** | Reviews `exfig.pkl` for issues and optimizations |
| **exfig-troubleshooting** | Error catalog with diagnostic steps |
| **exfig-migration** | Migration guide between major versions |
| **exfig-rules** | Naming and structure conventions |

## See Also

- <doc:Usage>
- <doc:Configuration>
- <doc:GettingStarted>
