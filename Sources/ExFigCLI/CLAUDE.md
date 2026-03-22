# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Module Overview

ExFigCLI is the main CLI module — the orchestration layer that connects PKL config parsing, Figma API client, domain processing (ExFigCore), and platform plugins (ExFig-iOS/Android/Flutter/Web) into a unified command-line tool. It owns all I/O: terminal output, file writing, image conversion, caching, batch processing, and download pipelining.

**Imports:** ExFigCore, ExFigConfig, FigmaAPI, all four ExFig-{Platform} modules, all four {Platform}Export modules, SVGKit. This is the only module that imports everything.

## Architecture

### Command Structure

`ExFigCommand` (`@main`) registers subcommands via swift-argument-parser:

```
exfig colors     (default)  → ExportColors
exfig icons                 → ExportIcons
exfig images                → ExportImages
exfig typography            → ExportTypography
exfig init                  → GenerateConfigFile
exfig schemas               → ExtractSchemas
exfig fetch                 → FetchImages
exfig download {colors|icons|images|typography|tokens|all} → Download (nested)
exfig batch                 → Batch
exfig mcp                   → MCPServe
```

Each subcommand composes options via `@OptionGroup`:

- `GlobalOptions` — `--verbose/-v`, `--quiet/-q`
- `ExFigOptions` — `--input/-i`, validates PKL config + FIGMA_PERSONAL_TOKEN
- `CacheOptions` — `--cache`, `--no-cache`, `--force`, `--experimental-granular-cache`
- `FaultToleranceOptions` — retry/timeout configuration

### Subcommand Execution Pattern

Every export subcommand follows the same flow:

```
run()
  → initializeTerminalUI(verbose:quiet:)
  → checkSchemaVersionIfNeeded()
  → resolveClient(accessToken:timeout:options:ui:)
  → performExportWithResult(client:ui:context:)
      → VersionTrackingHelper.checkForChanges()  [skip if unchanged]
      → Route to platform-specific export methods
      → VersionTrackingHelper.updateCacheIfNeeded()
      → Return result with metadata (count, fileVersions, hashes)
```

`performExportWithResult()` is the key method — called both by standalone subcommands and by `BatchConfigRunner` in batch mode.

### Plugin Routing

`PluginRegistry.default` holds 4 built-in plugins (iOS, Android, Flutter, Web). Each export subcommand iterates platform sections from PKL config and dispatches to platform-specific export methods:

```swift
if let ios = params.ios, let colors = ios.colors {
    exportiOSColorsViaPlugin(entries: colors, ...)
}
if let android = params.android, let colors = android.colors {
    exportAndroidColorsViaPlugin(entries: colors, ...)
}
// ... flutter, web
```

Platform export orchestrators live in `Subcommands/Export/` (e.g., `iOSColorsExport.swift`, `AndroidImagesExport.swift`). They create context implementations and invoke plugin exporters.

### Context Bridge Pattern

`Context/` implementations bridge CLI infrastructure to ExFigCore's export context protocols:

```
IconsExportContextImpl  → implements IconsExportContext
  .loadIcons()          → creates IconsLoader, calls Figma API
  .writeFiles()         → delegates to FileWriter
  .withSpinner()        → delegates to TerminalUI
  .downloadFile()       → delegates to FileDownloader / PipelinedDownloader
```

Each context holds: `Client`, `TerminalUI`, `PKLConfig`, filter, batch mode flag, `ConfigExecutionContext`, optional `GranularCacheManager`.

### Batch Processing

`Batch` subcommand orchestrates multi-config export with shared state:

```
Batch.run()
  → ConfigDiscovery.discover()         [find *.pkl files]
  → FileIdExtractor.extractUniqueFileIds()  [collect all file IDs]
  → FileVersionPreFetcher              [fetch metadata once, shared]
  → GranularCacheSetup                 [optional per-node cache]
  → BatchExecutor.execute()            [parallel, max 3 configs]
      For each config:
        → BatchSharedState.$current.withValue(state) {
            BatchConfigRunner.run()
          }
```

**Critical: Single TaskLocal pattern.** `BatchSharedState` actor consolidates ALL shared state (context, progressView, themeCollector, downloadQueue) into ONE `@TaskLocal`. This avoids the Linux crash from 10+ nested `withValue()` calls (https://github.com/swiftlang/swift/issues/75501). Per-config data goes through `ConfigExecutionContext` parameter, NOT TaskLocal.

### Cache System

Two layers:

1. **Version tracking** (`ImageTrackingCache`) — file-level: skip export if Figma file version hasn't changed
2. **Granular cache** (`GranularCacheManager`) — node-level: FNV-1a hash per Figma node, export only changed components

Granular cache flow: pre-fetch nodes → compute hashes → compare with cached → filter to changed only.

`ExportCheckpoint` / `CheckpointTracker` — resume batch from last successful config on failure.

### Download Pipeline

`SharedDownloadQueue` actor manages cross-config download coordination in batch mode:

- Priority-ordered queue (lower configPriority = higher priority)
- Concurrent download limit
- LRU result eviction
- Seamless integration via `PipelinedDownloader` wrapper

### Terminal UI Coordination

`TerminalUI` is the output facade. In batch mode, output coordination is critical:

- `info()` / `success()` — suppressed when `BatchProgressView` or parent spinner is active
- `warning()` / `error()` — NEVER suppressed; queued to `BatchProgressView.queueLogMessage()` for coordinated rendering
- `TerminalOutputManager` singleton prevents race conditions between animations and log output via `hasActiveAnimation` flag
- `withParallelEntries()` creates parent spinner suppressing all inner output (except warnings/errors)

### Image Conversion Pipeline

`Output/` contains native image encoders and converters:

```
SVG source → SvgToPngConverter (via resvg)  → PNG
           → SvgToWebpConverter (via libwebp) → WebP
           → SvgToHeicConverter (PNG → ImageIO) → HEIC (macOS only, falls back to PNG on Linux)
```

Converter factories (`WebpConverterFactory`, `HeicConverterFactory`) handle platform detection and fallback.

### PKL Config Loading

`ExFigOptions.validate()` uses a semaphore bridge to call async `PKLEvaluator.evaluate()` from sync `validate()` context (swift-argument-parser limitation). 30-second timeout. Auto-detects `exfig.pkl` if `-i` not specified.

## Key Files

| File                                     | Role                                                                |
| ---------------------------------------- | ------------------------------------------------------------------- |
| `ExFigCommand.swift`                     | Entry point, version, shared instances, subcommand registration     |
| `Input/ExFigOptions.swift`               | PKL config loading, token validation, auto-detection                |
| `Batch/BatchContext.swift`               | `BatchContext`, `ConfigExecutionContext`, `BatchSharedState` actor  |
| `Batch/BatchExecutor.swift`              | Parallel config execution with rate limiting                        |
| `Plugin/PluginRegistry.swift`            | Platform plugin routing (config key → plugin → exporters)           |
| `TerminalUI/TerminalUI.swift`            | Output facade (info/success/warning/error, spinners, progress)      |
| `TerminalUI/TerminalOutputManager.swift` | Thread-safe output synchronization, animation coordination          |
| `TerminalUI/BatchProgressView.swift`     | Multi-config progress display with log queuing                      |
| `Cache/GranularCacheManager.swift`       | Per-node change detection with FNV-1a hashing                       |
| `Pipeline/SharedDownloadQueue.swift`     | Cross-config download pipelining actor                              |
| `Output/FileWriter.swift`                | Sequential and parallel file writing with directory creation        |
| `Shared/ComponentPreFetcher.swift`       | Pre-fetch components for multi-entry exports                        |
| `Input/TokensFileSource.swift`           | W3C DTCG .tokens.json parser (local file → ExFigCore models)        |
| `Output/W3CTokensExporter.swift`         | W3C design token JSON exporter (v1/v2025 formats)                   |
| `Loaders/NumberVariablesLoader.swift`    | Figma number variables → dimension/number tokens                    |
| `Subcommands/DownloadTokens.swift`       | Unified `download tokens` subcommand                                |
| `MCP/ExFigMCPServer.swift`               | MCP server setup and lifecycle (stdio transport)                    |
| `MCP/MCPToolDefinitions.swift`           | MCP tool schemas (export colors, icons, images, etc.)               |
| `MCP/MCPToolHandlers.swift`              | MCP tool request handlers                                           |
| `MCP/MCPResources.swift`                 | MCP resource providers (config, schemas)                            |
| `MCP/MCPPrompts.swift`                   | MCP prompt templates                                                |
| `MCP/MCPServerState.swift`               | MCP server shared state                                             |
| `Source/SourceFactory.swift`             | Centralized factory creating source instances by `DesignSourceKind` |
| `Source/Figma*Source.swift`              | Figma source implementations wrapping existing loaders              |
| `Source/Penpot*Source.swift`             | Penpot source implementations (colors, components, typography)      |
| `Source/TokensFileColorsSource.swift`    | Local .tokens.json source (extracted from ColorsExportContextImpl)  |

### MCP Server Architecture

`MCPServe` subcommand does NOT use `ExFigOptions` or `@OptionGroup` — it creates its own
`OutputMode.mcp` and bootstraps logging independently. `MCPServerState` actor manages a lazy
`FigmaClient` shared across all tool calls (long-lived process, unlike one-shot CLI commands).

`TerminalOutputManager.setStderrMode(true)` must be called before any output — stdout is
reserved for MCP JSON-RPC protocol.

**Name collision:** Both `FigmaAPI` and `MCP` export `Client` — always use `FigmaAPI.Client` in MCP/ files.

**Keepalive:** `withCheckedContinuation { _ in }` — suspends indefinitely without hacks (no `Task.sleep(365 days)`).

**Guide resources:** `exfig://guides/` serves markdown files from `Resources/Guides/` (copied from DocC articles).
DocC `.docc` articles are NOT accessible via `Bundle.module` at runtime — must be separately copied to `Resources/Guides/`.

**Tool handler order:** Validate input parameters BEFORE expensive operations (PKL eval, API client creation).

### Adding an MCP Tool Handler

1. Add tool definition in `MCP/MCPToolDefinitions.swift` (JSON Schema via `.object([...])`)
2. Add case in `MCPToolHandlers.handle()` dispatch switch
3. Implement handler in an `extension MCPToolHandlers` (keeps `type_body_length` under 300)
4. `ExFigWarning` → string via `ExFigWarningFormatter().format(warning)` (no `.formattedMessage` property)
5. `Color.hex` is in AndroidExport, not accessible from ExFigCLI — use RGBA components
6. `ColorsVariablesLoader` takes `PKLConfig.Common.VariablesColors?`, not `.Colors?`
7. MCP `CallTool.Parameters.arguments` type is `[String: Value]?` (not `JSONValue`); accessors: `.stringValue`, `.intValue`, `.boolValue`
8. Export tools: `exfig_export` runs subprocess (self-invoke), reads JSON report from temp file; `exfig_download` returns tokens inline via loaders
9. `runSubprocess` pattern: set `terminationHandler` BEFORE `process.run()` (race condition); read stderr pipe concurrently via `Task` (deadlock at 64KB buffer); use `withThrowingTaskGroup` race for timeout
10. Validate cheap params (format, resource_type) BEFORE expensive operations (PKL eval, `state.getClient()`) — keeps tests fast and error messages clear

## Modification Patterns

### Source Dispatch Pattern

`ColorsExportContextImpl.loadColors()` creates source via `SourceFactory.createColorsSource(for:...)` per call.
`IconsExportContextImpl` / `ImagesExportContextImpl` use injected `componentsSource` (Figma and Penpot supported via `SourceFactory`).
`PluginColorsExport` does NOT create sources — context handles dispatch internally.
**Source dispatch gap:** `PluginIconsExport` iOS uses `SourceFactory`; Android/Flutter/Web still hardcode `FigmaComponentsSource`. `PluginImagesExport` all platforms hardcoded.
When adding a new source kind: update `SourceFactory`, add source impl in `Source/`, update error `assetType`.
Penpot sources create `BasePenpotClient` internally from `PENPOT_ACCESS_TOKEN` env var (like TokensFileSource reads local files — no injected client).

### Adding a New Subcommand

1. Create `Subcommands/NewCommand.swift` implementing `AsyncParsableCommand`
2. Register in `ExFigCommand.configuration.subcommands`
3. Use `@OptionGroup` for shared options
4. Call `initializeTerminalUI()` + `checkSchemaVersionIfNeeded()` in `run()`

### Adding an Interactive Wizard

Follow `InitWizard.swift` / `FetchWizard.swift` pattern:

1. Create `Subcommands/NewWizard.swift` as `enum` with `static func run() -> Result`
2. Use NooraUI prompts (`textPrompt`, `singleChoicePrompt`, `multipleChoicePrompt`, `yesOrNoPrompt`)
3. Extract testable pure logic into a separate static method (e.g., `applyResult(_:to:)`)
4. Reuse `WizardPlatform` from `FetchWizard.swift` (has `asPlatform` → `Platform` mapping)
5. Gate on `TTYDetector.isTTY` in the calling command; throw `ValidationError` for non-TTY

**File split pattern:** Keep types + interactive prompts in `*Wizard.swift` (~230 lines), extract pure
transformation logic into `*WizardTransform.swift` as `extension`. SwiftLint enforces 400-line file / 300-line type body limits.

**Test file split pattern:** When a `@Suite` struct exceeds 300 lines, extract groups of tests into separate `@Suite` structs in the same file (e.g., `InitWizardCrossPlatformTests`, `InitWizardTransformUtilityTests`).

**Template transformations** (three operations on PKL templates):

- **Remove section** — brace-counting (`removeSection`), strips preceding comments
- **Substitute value** — simple `replacingOccurrences` for file IDs, frame names
- **Uncomment block** — strip `//` prefix, substitute values (variablesColors, figmaPageName)
- **Insert block** (Penpot) — `applyPenpotResult` removes figma section, inserts `penpotSource` blocks into platform entries

### Penpot Fetch Path

`DownloadImages.runPenpotFetch()` uses `PenpotAPI` directly (not `DownloadImageLoader`).
Creates `BasePenpotClient`, fetches file, filters components by path, downloads thumbnails as PNG.
Triggered when `wizardResult?.designSource == .penpot` after wizard flow.

### Adding a New Platform Export

1. Create platform export orchestrator in `Subcommands/Export/` (e.g., `NewPlatformColorsExport.swift`)
2. Create context implementation in `Context/` implementing the ExFigCore protocol
3. Wire into the export subcommand's platform dispatch section

### Modifying Batch Shared State

Never add new `@TaskLocal` properties. Add fields to `BatchSharedState` actor or `ConfigExecutionContext` struct. If the data is immutable and shared, add to `BatchContext`. If per-config, add to `ConfigExecutionContext`.

### Modifying Terminal Output

- Use `TerminalUI` methods, never `print()` directly
- Warnings/errors must always be visible — never add suppression checks for them
- In batch mode, queue to `BatchProgressView` via `TerminalUI.warning()` (it handles routing automatically)

## Conventions

- `ExFigCommand.terminalUI` is `nonisolated(unsafe) static var` — initialized once per subcommand via `initializeTerminalUI()`
- `ExFigCommand.fileWriter`, `.svgFileConverter`, `.logger` are `static let` — safe shared instances
- `resolveClient()` is a free function (in a separate file) that creates `FigmaClient` → wraps in `RateLimitedClient`
- PKL config type is `ExFig.ModuleImpl` (generated by `pkl run @pkl.swift/gen.pkl`), aliased as `PKLConfig` in `PKLConfigCompat.swift`
- `BatchContextStorage` is a legacy shim — use `BatchSharedState.current` directly
