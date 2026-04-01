## TOON Format Convention

Use TOON (Token-Oriented Object Notation) for all tabular data in this file. TOON reduces token usage by 30-60% by declaring fields once in array headers.

```toon
format:
  syntax: name[count]{field1,field2,...}:
  indent: 2 spaces for rows
  delimiter: comma between values

example[2]{id,name,status}:
  1,Build command,active
  2,Test command,active
```

When adding lists of items (modules, commands, files, etc.), always use TOON tables instead of markdown tables or lists.

**Exception:** OpenSpec `tasks.md` — task items MUST use markdown checklists (`- [ ]`) for openspec parsing.

## Context7 for External Libraries

**Always use Context7 MCP** to look up documentation for external tools and libraries before implementing:

1. `resolve-library-id` - find the library ID
2. `get-library-docs` with `topic` - get relevant docs (use `mode: code` for API, `mode: info` for concepts)
3. Paginate with `page: 2, 3...` if context insufficient

This applies to: Swift packages, CLI tools (mise, hk, swiftlint, etc.), Figma API, and any third-party dependency.

# CLAUDE.md

Agent instructions for ExFig - a CLI tool that exports colors, typography, icons, and images from Figma to iOS, Android,
and Flutter projects.

## Quick Reference

```bash
# Build & Test
./bin/mise run build                # Debug build
./bin/mise run build:release        # Release build
./bin/mise run test                 # All tests (prefer over test:filter when 3+ files changed)
./bin/mise run test:filter NAME     # Filter by target/class/method
./bin/mise run test:file FILE       # Run tests for specific file

# Code Quality (run before commit)
./bin/mise run format               # Format all (Swift + Markdown)
./bin/mise run format:swift         # Format Swift only
./bin/mise run lint                 # SwiftLint + actionlint

# Docs & Coverage
./bin/mise run docs                 # Generate DocC documentation
./bin/mise run docs:preview         # Preview docs in browser (localhost:8080/documentation/exfigcli)
./bin/mise run coverage             # Run tests with coverage report

# Maintenance
./bin/mise run codegen:pkl         # Regenerate Swift types from PKL schemas
./bin/mise run generate:llms       # Generate llms.txt + llms-full.txt
./bin/mise run setup                # Install required tools
./bin/mise run clean                # Clean build artifacts

# Run CLI
.build/debug/exfig --help
.build/debug/exfig colors -i exfig.pkl
.build/debug/exfig icons -i exfig.pkl
.build/debug/exfig batch exfig.pkl            # All resources from unified config (positional arg!)
.build/debug/exfig fetch -f FILE_ID -r "Frame" -o ./output
.build/debug/exfig download tokens -o tokens.json  # Unified W3C design tokens
.build/debug/exfig mcp                              # Start MCP server over stdio
```

## Project Context

| Aspect          | Details                                                                                            |
| --------------- | -------------------------------------------------------------------------------------------------- |
| Language        | Swift 6.3, macOS 13.0+                                                                             |
| Package Manager | Swift Package Manager                                                                              |
| CLI Framework   | swift-argument-parser                                                                              |
| Config Format   | PKL (Programmable, Scalable, Safe)                                                                 |
| Templates       | Jinja2 (swift-jinja)                                                                               |
| Required Env    | `FIGMA_PERSONAL_TOKEN`                                                                             |
| Tooling         | mise (`./bin/mise` self-contained), swiftly (Swift toolchain management via `.swift-version`)      |
| Platforms       | macOS 13+ (primary), Linux/Ubuntu 22.04, Windows (Swift 6.3) - see `.claude/rules/linux-compat.md` |

## Architecture

Twelve modules in `Sources/`:

| Module          | Purpose                                                   |
| --------------- | --------------------------------------------------------- |
| `ExFigCLI`      | CLI commands, loaders, file I/O, terminal UI              |
| `ExFigCore`     | Domain models (Color, Image, TextStyle), processors       |
| `ExFigConfig`   | PKL config parsing, evaluation, type bridging             |
| `ExFig-iOS`     | iOS platform plugin (ColorsExporter, IconsExporter, etc.) |
| `ExFig-Android` | Android platform plugin                                   |
| `ExFig-Flutter` | Flutter platform plugin                                   |
| `ExFig-Web`     | Web platform plugin                                       |
| `XcodeExport`   | iOS export (.xcassets, Swift extensions)                  |
| `AndroidExport` | Android export (XML resources, Compose, Vector Drawables) |
| `FlutterExport` | Flutter export (Dart code, SVG/PNG assets)                |
| `WebExport`     | Web/React export (CSS variables, JSX icons)               |
| `JinjaSupport`  | Shared Jinja2 template rendering across Export modules    |

**Data flow:** CLI -> PKL config parsing -> FigmaAPI fetch -> ExFigCore processing -> Platform plugin -> Export module -> File write
**Alt flows:** tokens (.tokens.json → TokensFileSource), penpot (PenpotAPI → Penpot*Source)
**MCP:** `exfig mcp` → StdioTransport → tool handlers. `OutputMode.mcp` routes all output to stderr.
**Batch mode:** Single `@TaskLocal` via `BatchSharedState` actor — see `ExFigCLI/CLAUDE.md`.
**Parallelism:** All exporters use `parallelMapEntries()` (max 5 concurrent) — see `ExFigCore/CLAUDE.md`.

## Key Directories

```
Sources/ExFigCLI/
├── Subcommands/     # CLI commands (ExportColors, ExportIcons, DownloadImages, etc.)
│   └── Export/      # Platform-specific export logic
├── Loaders/         # Figma data loaders
├── Input/           # Config & CLI options
├── Output/          # File writers, converters, factories
├── TerminalUI/      # Progress bars, spinners, logging
├── Cache/           # Version tracking, granular cache
├── Batch/           # Batch processing (executor, runner, checkpoint)
├── Source/          # Design source implementations (SourceFactory, Figma*Source, Penpot*Source)
├── MCP/             # Model Context Protocol server
└── Lint/            # Figma structure validation rules

Sources/ExFig-{iOS,Android,Flutter,Web}/
├── Config/          # Entry types (iOSColorsEntry, AndroidIconsEntry, etc.)
└── Export/          # Exporters (iOSColorsExporter, AndroidImagesExporter, etc.)

Sources/ExFigConfig/Generated/  # PKL codegen output (DO NOT edit manually)
Sources/ExFigCLI/Resources/Schemas/  # PKL schemas
Tests/                               # Test targets mirror source structure
```

## Code Conventions

| Area            | Use                                   | Instead of                            |
| --------------- | ------------------------------------- | ------------------------------------- |
| JSON parsing    | `JSONCodec` (swift-yyjson)            | `JSONDecoder`/`JSONEncoder`           |
| JSON DOM access | `JSONCodec.parseValue(from:)`         | `JSONSerialization` / `import YYJSON` |
| Terminal UI     | Noora (`NooraUI`, `TerminalText`)     | Rainbow color methods                 |
| Terminal output | `TerminalUI` facade                   | Direct `print()` calls                |
| README.md       | Keep compact (~80 lines, pain-driven) | Detailed docs (use CONFIG.md / DocC)  |

**Documentation:** README is short. Detailed docs in DocC articles (`Sources/ExFigCLI/ExFig.docc/`).
`docs/` is DocC OUTPUT (gitignored) — never put source docs there.

**Plugin sync:** When adding user-visible features, update [exfig-plugins](https://github.com/DesignPipe/exfig-plugins) skills.

## Additional Rules

Contextual documentation is in `.claude/rules/`:

| Rule File                    | When to Consult                                                                       |
| ---------------------------- | ------------------------------------------------------------------------------------- |
| `modification-checklists.md` | Adding/modifying loader configs, filters, PKL types, CLI commands, wizards, exporters |
| `variable-dark-mode.md`      | VariableModeDarkGenerator, SVGColorReplacer, cross-file variables, caching            |
| `lint-patterns.md`           | Lint command, rule development, PathDataLengthRule                                    |
| `source-patterns.md`         | Source dispatch, Penpot, MCP SDK, module boundaries, RTL, build env                   |
| `config-patterns.md`         | Multi-entry Icons/Colors/Images config, codeSyntax                                    |
| `image-formats.md`           | SVG source format, HEIC output                                                        |
| `terminal-ui.md`             | TerminalUI, warnings, errors systems                                                  |
| `fault-tolerance.md`         | Retry, rate limiting, timeout                                                         |
| `batch-processing.md`        | Batch pre-fetch, pipelined downloads                                                  |
| `cache-granular.md`          | Experimental granular node-level cache                                                |
| `api-reference.md`           | Figma API endpoints, response mapping                                                 |
| `troubleshooting.md`         | Build/test/PKL/MCP/Penpot problem-solution pairs                                      |
| `gotchas.md`                 | Swift 6 concurrency, SwiftLint, rate limits                                           |
| `linux-compat.md`            | Linux/Windows platform workarounds                                                    |
| `testing-workflow.md`        | Testing guidelines, commit format                                                     |
| `pkl-codegen.md`             | pkl-swift generated types, enum bridging, codegen                                     |
| `Sources/*/CLAUDE.md`        | Module-specific patterns, modification checklists                                     |

These rules are loaded lazily when working with related files.

## Session Wrap-Up

After completing a task, call `Skill(claude-md-management:revise-claude-md)` to capture learnings and update CLAUDE.md.
