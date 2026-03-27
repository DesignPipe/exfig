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
# Linux: swift build --build-tests && swift test --skip-build --parallel
./bin/mise run test:filter NAME     # Filter by target/class/method
./bin/mise run test:file FILE       # Run tests for specific file

# Code Quality (run before commit)
./bin/mise run format               # Format all (Swift + Markdown)
./bin/mise run format:swift         # Format Swift only
./bin/mise run format:md            # Format Markdown only
./bin/mise run format-check         # Check formatting (CI) - fix with format:swift
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
./bin/mise run clean:all            # Clean build + derived data

# Shell Completions & CLI Docs (via Usage spec)
./bin/mise run completions:bash     # Generate bash completions
./bin/mise run completions:zsh      # Generate zsh completions
./bin/mise run completions:fish     # Generate fish completions
./bin/mise run docs:cli-reference   # Generate CLI reference docs

# Run CLI
.build/debug/exfig --help
.build/debug/exfig colors -i exfig.pkl
.build/debug/exfig icons -i exfig.pkl
.build/debug/exfig batch exfig.pkl            # All resources from unified config (positional arg!)
.build/debug/exfig fetch -f FILE_ID -r "Frame" -o ./output
.build/debug/exfig download tokens -o tokens.json  # Unified W3C design tokens
.build/debug/exfig mcp                              # Start MCP server over stdio

# PKL Validation (validate config templates against schemas)
pkl eval --format json <file.pkl>   # Package URI requires published package
# For local validation, replace package:// URIs with local Schemas/ paths
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
| Config Files    | `exfig.pkl` (PKL configuration)                                                                    |
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

**Data flow:** CLI -> PKL config parsing -> FigmaAPI (external) fetch -> ExFigCore processing -> Platform plugin -> Export module -> File write
**Alt data flow (tokens):** CLI -> local .tokens.json file -> TokensFileSource -> ExFigCore models -> W3C JSON export
**Alt data flow (penpot):** CLI -> PenpotAPI fetch -> Penpot*Source -> ExFigCore models -> Platform plugin -> Export module -> File write

**MCP data flow:** `exfig mcp` → StdioTransport (JSON-RPC on stdin/stdout) → tool handlers → PKLEvaluator / TokensFileSource / FigmaAPI
**MCP stdout safety:** `OutputMode.mcp` + `TerminalOutputManager.setStderrMode(true)` — all CLI output goes to stderr
**Claude Code plugins:** [exfig-plugins](https://github.com/DesignPipe/exfig-plugins) marketplace — MCP integration, setup wizard, export commands, config review, troubleshooting

**Variable-mode dark icons:** `FigmaComponentsSource.loadIcons()` → `VariableModeDarkGenerator` — fetches Variables API, resolves alias chains, replaces hex colors in SVG via `SVGColorReplacer`. Third dark mode approach alongside `darkFileId` and `suffixDarkMode`.

**Batch mode:** Single `@TaskLocal` via `BatchSharedState` actor — see `ExFigCLI/CLAUDE.md`.

**Entry-level parallelism:** All exporters use `parallelMapEntries()` (max 5 concurrent) — see `ExFigCore/CLAUDE.md`.

## Key Directories

```
Sources/ExFigCLI/
├── Subcommands/     # CLI commands (ExportColors, ExportIcons, DownloadImages, etc.)
│   └── Export/      # Platform-specific export logic (iOSIconsExport, AndroidImagesExport, etc.)
├── Loaders/         # Figma data loaders (ColorsLoader, ImagesLoader, etc.)
├── Input/           # Config & CLI options (ExFigOptions, DownloadOptions, etc.)
├── Output/          # File writers, converters, factories (WebpConverterFactory, HeicConverterFactory)
├── TerminalUI/      # Progress bars, spinners, logging, output coordination
├── Cache/           # Version tracking, granular cache (GranularCacheHelper, GranularCacheManager)
├── Pipeline/        # Cross-config download pipelining (SharedDownloadQueue)
├── Batch/           # Batch processing (executor, runner, checkpoint)
├── Sync/            # Figma sync functionality (state tracking, diff detection)
├── Plugin/          # Plugin registry
├── Context/         # Export context implementations (ColorsExportContextImpl, etc.)
├── Source/          # Design source implementations (SourceFactory, Figma*Source, Penpot*Source, TokensFile*Source)
├── MCP/             # Model Context Protocol server (tools, resources, prompts)
└── Shared/          # Cross-cutting helpers (PlatformExportResult, HashMerger)

Sources/ExFig-{iOS,Android,Flutter,Web}/
├── Config/          # Entry types (iOSColorsEntry, AndroidIconsEntry, etc.)
└── Export/          # Exporters (iOSColorsExporter, AndroidImagesExporter, etc.)

Sources/ExFigConfig/
└── PKL/             # PKL evaluator, error types

Sources/ExFigCLI/Resources/
├── Schemas/         # PKL schemas (ExFig.pkl, iOS.pkl, Android.pkl, Flutter.pkl, Web.pkl, Common.pkl, Figma.pkl)
│   └── examples/    # Example PKL configs (exfig-ios.pkl, exfig-multi.pkl, base.pkl)
├── *Config.swift    # Init templates: PKL content as Swift raw string literals (ios, android, flutter, web)
└── *.jinja          # Jinja2 templates for code generation

Sources/*/Resources/ # Jinja2 templates for code generation
Tests/               # Test targets mirror source structure
```

## Code Patterns

### Generated PKL Config URIs

Templates in `*Config.swift` use `.exfig/schemas/` as placeholder paths. `GenerateConfigFile.substitutePackageURI()`
replaces them with `package://github.com/DesignPipe/exfig/releases/download/v{VERSION}/exfig@{VERSION}#/` at generation
time. Version comes from `ExFigCommand.version`. `exfig init` does NOT extract local schemas — config references the
published PKL package directly.

### PKL Consumer Config DRY Patterns

Consumer `exfig.pkl` configs can use `local` Mapping + `for`-generators to eliminate entry duplication:

```pkl
local categories: Mapping<String, String> = new { ["FrameName"] = "folder" }
icons = new Listing {
  for (frameName, folder in categories) {
    new iOS.IconsEntry { figmaFrameName = frameName; assetsFolder = folder; /* ... */ }
  }
}
```

`local` properties don't appear in JSON output. Verify refactoring with `pkl eval --format json` diff.

### Modifying Loader Configs (IconsLoaderConfig / ImagesLoaderConfig)

When adding fields to loader configs, update ALL construction sites:

1. Factory methods (`forIOS`, `forAndroid`, `forFlutter`, `forWeb`, `defaultConfig`)
2. Context implementations (`Sources/ExFigCLI/Context/*ExportContextImpl.swift`) — direct constructions in `loadIcons`/`loadImages`
3. Test files (`IconsLoaderConfigTests.swift`, `EnumBridgingTests.swift`) — direct init calls

**EnumBridgingTests gotcha:** Entry constructions have TWO indentation levels — 16-space (inside `for` loop)
and 12-space ("defaults to" tests outside loop). A single `replace_all` with fixed indent misses one level.

When adding fields to `FrameSource` (PKL) / `SourceInput` (ExFigCore), also update:

4. Entry bridge methods (`iconsSourceInput()`/`imagesSourceInput()`) in ALL `Sources/ExFig-*/Config/*Entry.swift`
5. Inline `SourceInput(` constructions in exporters (`iOSImagesExporter.svgSourceInput`, `AndroidImagesExporter.loadAndProcessSVG`)
6. "Through" tests in `IconsLoaderConfigTests` — use `source.field` not hardcoded `nil`
7. Download command files: `DownloadOptions.swift` (CLI flag), `DownloadImageLoader.swift` (filter), `DownloadExportHelpers.swift`, `DownloadImages.swift`, `DownloadIcons.swift`
8. `DownloadAll.swift` — pass filter value to both `exportIcons` and `exportImages`
9. Error/warning types with context (`ExFigError`, `ExFigWarning`) — add associated values if needed

### Adding a New Filter Level (e.g., page filtering)

Filter predicate sites that ALL need updating:

1. `ImageLoaderBase.swift` — `fetchImageComponents` (icons + images)
2. `DownloadImageLoader.swift` — `fetchImageComponents`
3. `DownloadExportHelpers.swift` — `AssetExportHelper.fetchComponents`
4. Inline `SourceInput()` constructions in platform exporters (iOS `svgSourceInput`, Android `loadAndProcessSVG`)
5. `DownloadAll.swift` — pass filter value to both `exportIcons` and `exportImages`

### Moving/Renaming PKL Types Between Modules

When relocating a type (e.g., `Android.WebpOptions` → `Common.WebpOptions`), update ALL reference sites:

1. PKL schemas (`Schemas/*.pkl`) — definition + imports + field types
2. Codegen (`./bin/mise run codegen:pkl`)
3. Swift bridging (`Sources/ExFig-*/Config/*Entry.swift`) — typealiases + extensions
4. Init-template configs (`Sources/ExFigCLI/Resources/*Config.swift`) — `new Type { }` refs
5. PKL examples (`Schemas/examples/*.pkl`)
6. DocC docs (`ExFig.docc/**/*.md`), CONFIG.md

### Variable-Mode Dark Icons (VariableModeDarkGenerator)

Three dark mode approaches for icons (mutually exclusive):

1. `darkFileId` — separate Figma file for dark icons (global `figma` section)
2. `suffixDarkMode` — `Common.SuffixDarkMode` on `Common.Icons`/`Images`/`Colors`, splits by name suffix
3. `variablesDarkMode` — `Common.VariablesDarkMode` on `FrameSource` (per-entry), resolves Figma Variable bindings

Approach 3 is configured via nested `variablesDarkMode: VariablesDarkMode?` on `FrameSource`.
Integration point: `FigmaComponentsSource.loadIcons()`.

**Algorithm:** fetch `VariablesMeta` → fetch icon nodes → walk children tree to find `Paint.boundVariables["color"]`
→ resolve dark value via alias chain (depth limit 10, same pattern as `ColorsVariablesLoader.handleColorMode()`)
→ build `lightHex → darkHex` map → `SVGColorReplacer.replaceColors()` → write dark SVG to temp file.

Key files: `VariableModeDarkGenerator.swift`, `SVGColorReplacer.swift`, `FigmaComponentsSource.swift`.

**Logging requirements:** Every `guard ... else { continue }` in the generation loop must log a warning — silent skips cause invisible data loss. `resolveDarkColor` must check `deletedButReferenced != true` (same as all other variable loaders). `SVGColorReplacer` uses separate regex replacement templates per pattern (attribute patterns have 3 capture groups, CSS patterns have 2 — never share a single template).

**pkl-swift decoding:** pkl-swift uses **keyed** decoding (by property name, not positional). TypeRegistry is only for `PklAny` polymorphic types and performance — concrete `Decodable` structs (like `VariablesDarkMode`) decode via synthesized `init(from:)` regardless of `registerPklTypes`. New types should still be added to `registerPklTypes()` for completeness, but missing entries do NOT cause silent nil for concrete typed fields.

**Cross-file variable resolution:** Figma variable IDs are file-scoped — alias targets from the icons file don't exist in library files by ID. When `variablesFileId` is set, variables are loaded from BOTH files: icons file (semantic variables matching node boundVariables) + library file (primitives for alias resolution). Matching is by variable **name** across files and mode **name** across collections (not IDs).

**VariablesCache pattern:** `VariablesCache` (Lock + Task dedup) caches Variables API responses by fileId across parallel entries. Created per platform section in `PluginIconsExport`, injected through `SourceFactory` → `FigmaComponentsSource` → `VariableModeDarkGenerator`. Same pattern applicable to `ColorsVariablesLoader` if needed.

**Alpha handling:** `SVGColorReplacer` supports opacity via `ColorReplacement(hex, alpha)`. When `alpha < 1.0`, replacement adds `fill-opacity`/`stroke-opacity` attributes (SVG) or `;fill-opacity:N` (CSS). Same hex with different alpha IS a valid replacement (e.g., `#D6FB94` opaque → `#D6FB94` transparent).

**Granular cache path:** `IconsExportContextImpl.loadIconsWithGranularCache()` creates its own `IconsLoader` and bypasses `FigmaComponentsSource` entirely. Variable-mode dark generation must be applied explicitly at the end of that method via `applyVariableModeDark(to:source:)`.

### Module Boundaries

ExFigCore does NOT import FigmaAPI. Constants on `Component` (FigmaAPI, extended in ExFigCLI) are
not accessible from ExFigCore types (`IconsSourceInput`, `ImagesSourceInput`). Keep default values
as string literals in ExFigCore inits; use shared constants only within ExFigCLI.

ExFigConfig imports ExFigCore but NOT ExFigCLI — `ExFigError` is not available. Use `ColorsConfigError` (ExFigCore) for validation errors.

### Modifying SourceFactory Signatures

`createComponentsSource` has 8 call sites (4 in `PluginIconsExport` + 4 in `PluginImagesExport`) plus tests in `PenpotSourceTests.swift`.
`createTypographySource` call sites: only tests (not yet wired to production export flow).
Use `replace_all` on the trailing parameter pattern (e.g., `filter: filter\n        )`) to update all sites at once.

### Source-Aware File ID Resolution (SourceKindBridging)

`resolvedFileId` must be source-kind-aware: when `resolvedSourceKind == .penpot`, return ONLY `penpotSource?.fileId` (not coalescent `?? figmaFileId`).
Passing a Figma file key to Penpot API causes cryptic UUID parse errors. Same principle applies to any future source-specific identifiers.

### RTL Detection Design

- `Component.iconName`: uses `containingComponentSet.name` for variants, own `name` otherwise
- `Component.codeConnectNodeId`: uses `containingComponentSet.nodeId` for variants, own `nodeId` otherwise (Figma Code Connect rejects variant node IDs)
- `Component.defaultRTLProperty = "RTL"`: shared constant in ExFigCLI for the magic string
- PNG images intentionally do NOT carry `isRTL` — raster images skip mirroring by design
- `buildPairedComponents` must use `iconName` (not `name`) — variant `name` is `"RTL=Off"`, not the icon name

### Modifying Node ID Logic (AssetMetadata / ImagePack)

When changing how node IDs are resolved (e.g., `codeConnectNodeId`), update ALL construction sites in `ImageLoaderBase.swift`:

1. `AssetMetadata` in `fetchImageComponentsWithGranularCache` (~line 156)
2. `AssetMetadata` in `fetchImageComponentsWithGranularCacheAndPairing` (~line 220)
3. `ImagePack` primaryNodeId in `loadVectorImages` (vector/SVG path)
4. `ImagePack` primaryNodeId in `loadPNGImages` (raster path)

### Modifying ColorsVariablesLoader Return Type

`ColorsLoaderOutput` is a tuple typealias used by both `ColorsLoader` and `ColorsVariablesLoader`.
Changing `load()` return type affects:

1. `ColorsExportContextImpl.loadColors()` — main export flow
2. `Download.Colors.exportW3C()` — download command (inside `@Sendable withSpinner` closure)
3. `DownloadAll.exportColors()` — download all command (inside `@Sendable withSpinner` closure)
4. ALL assertions in `ColorsVariablesLoaderTests` — `result.light` → `result.output.light` etc.

**`withSpinner` gotcha:** Closure is `@Sendable` — cannot capture mutable vars. Return full result from closure.

### Adding a CLI Command

See `ExFigCLI/CLAUDE.md` (Adding a New Subcommand).

**Important:** When adding/changing CLI flags or subcommands, update `exfig.usage.kdl` (Usage spec) to keep shell completions and docs in sync. When bumping the app version in `ExFigCommand.swift`, also update the `version` field in `exfig.usage.kdl`.

### Adding an Interactive Wizard

Follow `InitWizard.swift` / `FetchWizard.swift` pattern:

- `enum` with `static func run()` for interactive flow (NooraUI prompts)
- Pure function for testable transformation logic (e.g., `applyResult(_:to:)`)
- Reuse `WizardPlatform` from `FetchWizard.swift` (has `asPlatform` property)
- Gate on `TTYDetector.isTTY`; throw `ValidationError` for non-TTY without required flags
- Use `extractFigmaFileId(from:)` for file ID inputs (auto-extracts ID from full Figma URLs)
- Trim text prompt results with `.trimmingCharacters(in: .whitespacesAndNewlines)` before `.isEmpty` default checks

#### Design Source Branching

Both `InitWizard` and `FetchWizard` ask "Figma or Penpot?" first (`WizardDesignSource` enum in `FetchWizard.swift`).
`extractPenpotFileId(from:)` extracts UUID from Penpot workspace URLs (`file-id=UUID` query param).
`InitWizardTransform` has separate methods: `applyResult` (Figma) and `applyPenpotResult` (Penpot — removes figma section, inserts penpotSource blocks).

### Adding a NooraUI Prompt Wrapper

Follow the existing pattern in `NooraUI.swift`: static method delegating to `shared` instance with matching parameter names.
Noora's `multipleChoicePrompt` uses `MultipleChoiceLimit` — `.unlimited` or `.limited(count:errorMessage:)`.

### MCP SDK Windows Exclusion

MCP `swift-sdk` depends on `swift-nio` which doesn't compile on Windows. All MCP files are wrapped
in `#if canImport(MCP)` and the dependency is conditionally included via `#if !os(Windows)` in Package.swift.
`ExFigCommand.allSubcommands` computed property (not array literal) handles conditional `MCPServe` registration.

### MCP SDK Version (0.12.0+)

MCP SDK 0.12.0 changed Content enum: `.text` case now has `(text:, annotations:, _meta:)`.
Both `.text(_:metadata:)` and `.text(text:metadata:)` factories are deprecated but functional.
`GetPrompt.Parameters.arguments` changed from `[String: Value]?` to `[String: String]?`.

### Build Environment (Swift 6.3 via swiftly)

Swift 6.3 is managed by swiftly (`.swift-version` file), not mise. Always use `./bin/mise run build` and `./bin/mise run test` — mise handles PATH and DEVELOPER_DIR automatically.
Under the hood: swiftly provides Swift 6.3; Xcode provides macOS SDK with XCTest. Both are needed for `swift test`.

### Dependency Version Coupling (swift-resvg ↔ swift-svgkit)

`swift-svgkit` uses `exact:` pin on `swift-resvg`. When bumping resvg version (e.g., for Windows artifactbundle),
must first update and tag swift-svgkit with the new resvg version, then update ExFig's Package.swift.

### Adding a Figma API Endpoint

FigmaAPI is now an external package (`swift-figma-api`). See its repository for endpoint patterns.

### Source Dispatch (ColorsExportContextImpl)

`ColorsExportContextImpl.loadColors()` uses `SourceFactory` per-call dispatch (NOT injected source).
This enables per-entry `sourceKind` — different entries in one config can use different sources.
Do NOT inject `colorsSource` at context construction time — it breaks multi-source configs.

### Lazy Figma Client Pattern

`resolveClient(accessToken:...)` accepts `String?`. When nil (no `FIGMA_PERSONAL_TOKEN`), returns `NoTokenFigmaClient()` — a fail-fast client that throws `accessTokenNotFound` on any request. Non-Figma sources never call it. `SourceFactory` also guards the `.figma` branch. This avoids making `Client?` cascade through 20+ type signatures.

### Penpot Source Patterns

- `PenpotClientFactory.makeClient(baseURL:)` — shared factory in `Source/PenpotClientFactory.swift`. Returns `any PenpotClient` (protocol, not `BasePenpotClient`) for testability. All Penpot sources use this (NOT a static on any single source).
- `PenpotShape.ShapeType` enum — `.path`, `.rect`, `.circle`, `.group`, `.frame`, `.bool`, `.unknown(String)`. Exhaustive switch in renderer (no `default` branch).
- `PenpotComponent.MainInstance` struct — pairs `id` + `page` (both or neither). Computed properties `mainInstanceId`/`mainInstancePage` for backward compat.
- `PenpotShapeRenderer.renderSVGResult()` — returns `Result<RenderResult, RenderFailure>` with `skippedShapeTypes` and typed failure reasons. `renderSVG()` is a convenience wrapper.
- Dictionary iteration from Penpot API (`colors`, `typographies`, `components`) must be sorted by key for deterministic export order: `.sorted(by: { $0.key < $1.key })`.
- `exfig fetch --source penpot` — `FetchSource` enum in `DownloadOptions.swift`. Route: `--source` flag > wizard result > default `.figma`. Also `--penpot-base-url` for self-hosted.
- Penpot fetch supports only `svg` and `png` formats — unsupported formats (pdf, webp, jpg) throw an error.
- Download commands (`download all/colors/icons/images/typography`) are **Figma-only** by design. Penpot export uses `exfig colors/icons/images` (via SourceFactory) and `exfig fetch --source penpot`.

### Entry Bridge Source Kind Resolution

Entry bridge methods (`iconsSourceInput()`, `imagesSourceInput()`) use `resolvedSourceKind` (computed property on `Common_FrameSource`)
instead of `sourceKind?.coreSourceKind ?? .figma`. This auto-detects Penpot when `penpotSource` is set.
`Common_VariablesSource` has its own `resolvedSourceKind` in `VariablesSourceValidation.swift` (includes tokensFile + penpot detection).

Entry bridge methods also use `resolvedFileId` (`penpotSource?.fileId ?? figmaFileId`) and `resolvedPenpotBaseURL`
(`penpotSource?.baseUrl`) from `SourceKindBridging.swift` to pass source-specific values through flat SourceInput fields.

### Adding a Platform Plugin Exporter

See `ExFigCore/CLAUDE.md` (Modification Checklist) and platform module CLAUDE.md files.

### Destination.url Contract (FileContents.swift)

`URL(fileURLWithPath:)` → `lastPathComponent` (iOS/Android/Web). `URL(string:)` → preserves subdirectories (Flutter). See `ExFigCore/CLAUDE.md`.

### Refactoring *SourceInput Types

When changing fields on `ColorsSourceInput` / `IconsSourceInput` / `ImagesSourceInput`:

1. Construction sites: `validatedColorsSourceInput()` in `VariablesSourceValidation.swift`, entry bridge methods in `Sources/ExFig-*/Config/*Entry.swift`
2. **Read sites in platform exporters**: `Sources/ExFig-*/Export/*Exporter.swift` — spinner messages may reference SourceInput fields
3. Download commands (`DownloadColors`, `DownloadAll`) use loaders directly, NOT `*SourceInput` — typically unaffected
4. `BatchConfigRunner` delegates via `performExportWithResult()` — typically unaffected

## Code Conventions

| Area            | Use                                   | Instead of                            |
| --------------- | ------------------------------------- | ------------------------------------- |
| JSON parsing    | `JSONCodec` (swift-yyjson)            | `JSONDecoder`/`JSONEncoder`           |
| JSON DOM access | `JSONCodec.parseValue(from:)`         | `JSONSerialization` / `import YYJSON` |
| Terminal UI     | Noora (`NooraUI`, `TerminalText`)     | Rainbow color methods                 |
| Terminal output | `TerminalUI` facade                   | Direct `print()` calls                |
| README.md       | Keep compact (~80 lines, pain-driven) | Detailed docs (use CONFIG.md / DocC)  |

**Documentation structure:** README is a short pain-driven intro (~80 lines). Detailed docs live in DocC articles
(`Sources/ExFigCLI/ExFig.docc/`). Architecture, PKL Guide, and Migration are also DocC articles.
`docs/` is DocC OUTPUT (gitignored, for GitHub Pages) — never put source docs there.
When adding new features, mention briefly in README Quick Start AND update relevant DocC articles.

**DocC visual directives:** Articles use `@Metadata` with `@PageImage`, `@PageColor`, `@TitleHeading`.
SVG icons from Lucide (MIT) in `ExFig.docc/Resources/`. Dark variants use `~dark.svg` suffix
with `#ffffff` stroke (light uses `#1d1d1f`). `currentColor` does NOT work in DocC icon SVGs
(`<img>` tag context). `@Links(visualStyle: compactGrid|detailedGrid)` for card-grid navigation.
`theme-settings.json` in docc root for global color/font customization.
Color scheme: Getting Started → blue, iOS → blue, Android → green, Flutter → blue, Advanced → purple, Contributing → orange.

**JSONCodec usage:**

```swift
import YYJSON

// Decode
let data = try JSONCodec.decode(MyType.self, from: jsonData)

// Encode
let jsonData = try JSONCodec.encode(myValue)

// DOM access (for dynamic JSON without Codable types)
let json = try JSONCodec.parseValue(from: data)  // returns JSONValue
let name = json["key"]?.string                    // String?
let count = json["count"]?.number                 // Double?
if let obj = json.object { for (k, v) in obj { } }  // iterate keys
if let arr = json["items"]?.array { arr.compactMap(\.string) }  // array
```

**Noora usage:** See `.claude/rules/terminal-ui.md` for full patterns.

**NooraUI quick reference:**

```swift
// Format a single component (uses format(_ component:) overload)
NooraUI.format(.primary("text"))    // cyan
NooraUI.format(.success("✓"))      // green
NooraUI.format(.danger("✗"))       // red
NooraUI.format(.accent("⚠"))      // yellow
NooraUI.format(.muted("dim"))      // gray
NooraUI.format(.command("bold"))   // bold/secondary
NooraUI.formatLink("url", useColors: true)  // underlined primary
```

| Tests fail | Check `FIGMA_PERSONAL_TOKEN` is set |
| Formatting fails | Run `./bin/mise run setup` to install tools |
| test:filter no matches | SPM converts hyphens→underscores: use `ExFig_FlutterTests` not `ExFig-FlutterTests` |
| Template errors | Check Jinja2 syntax and context variables |
| Linux test hangs | Build first: `swift build --build-tests`, then `swift test --skip-build --parallel` |
| Android pathData long | Simplify in Figma or use `--strict-path-validation` |
| PKL parse error 1 | Check `PklError.message` — actual error is in `.message`, not `.localizedDescription` |
| Test target won't compile | Broken test files block entire target; use `swift test --filter Target.Class` after `build` |
| Test helper JSON decode | `ContainingFrame` uses default Codable (camelCase: `nodeId`, `pageName`), NOT snake_case |
| Web entry test fails | Web entry types use `outputDirectory` field, while Android/Flutter use `output` |
| Logger concatenation err | `Logger.Message` (swift-log) requires interpolation `"\(a) \(b)"`, not concatenation `a + b` |
| Deleted variables in output | Filter `VariableValue.deletedButReferenced != true` in variable loaders AND `CodeSyntaxSyncer` |
| Jinja trailing `\n` | `{% if false %}...{% endif %}\n` renders `"\n"`, not `""` — strip whitespace-only partial template results |
| `Bundle.module` in tests | SPM test targets without declared resources don't have `Bundle.module` — use `Bundle.main` or temp bundle |
| SwiftFormat breaks `::` syntax | SwiftFormat 0.60.1+ required for Swift 6.3 module selectors (`FigmaAPI::Client`) |
| MCP SDK 0.12.0 breaking | `.text` has 3 associated values — pattern match as `.text(text, _, _)`; `GetPrompt.arguments` is `[String: String]?` now |
| Tests need XCTest from Xcode | swiftly's Swift 6.3 lacks XCTest; set `DEVELOPER_DIR` to Xcode app path for `swift test` |
| `swift test` pkl failures | Run via `./bin/mise exec -- swift test` to get pkl 0.31+ in PATH; bare `swift test` uses system pkl |
| SwiftFormat `#if` indent | SwiftFormat 0.60.1 indents content inside `#if canImport()` — this is intentional project style, do not "fix" |
| SPM `from:` too loose | When code uses APIs from version X, set `from: "X"` not older — SPM may resolve an incompatible earlier version |
| Granular cache "Access denied" | `GranularCacheManager.filterChangedComponents` degrades gracefully — returns all components on node fetch error instead of failing config |
| Empty `fileId` in variable dark | `FigmaComponentsSource` must guard `fileId` not empty before calling `VariableModeDarkGenerator` — `?? ""` causes cryptic Figma API 404 |
| PKL field always `nil` | `registerPklTypes()` is a performance optimization, NOT a correctness requirement for concrete typed fields. For optional nested PKL objects returning `nil`, check: (1) `pkl eval --format json` confirms field present, (2) unit test with `PKLEvaluator.evaluate()` decodes correctly, (3) trace values at bridge layer (`iconsSourceInput()`) with diagnostic log |
| Granular cache skips dark gen | `loadIconsWithGranularCache()` in `IconsExportContextImpl` bypasses `FigmaComponentsSource` — must call `VariableModeDarkGenerator` explicitly via `applyVariableModeDark()` helper |
| Variable dark always empty maps | Alias targets are external library variables — set `variablesFileId` in `VariablesDarkMode` PKL config to the library file ID containing primitives |
| Figma variable IDs file-scoped | Variable IDs differ between files — alias targets from file A can't be found by ID in file B. Use name-based matching (`resolveViaLibrary`) + mode name matching (not modeId) for cross-file resolution |

## Additional Rules

Contextual documentation is in `.claude/rules/`:

| Rule File             | When to Consult                                    |
| --------------------- | -------------------------------------------------- |
| `config-patterns.md`  | Multi-entry Icons/Colors/Images config, codeSyntax |
| `image-formats.md`    | SVG source format, HEIC output                     |
| `terminal-ui.md`      | TerminalUI, warnings, errors systems               |
| `fault-tolerance.md`  | Retry, rate limiting, timeout                      |
| `batch-processing.md` | Batch pre-fetch, pipelined downloads               |
| `cache-granular.md`   | Experimental granular node-level cache             |
| `api-reference.md`    | Figma API endpoints, response mapping              |
| `troubleshooting.md`  | Build/test/PKL/MCP/Penpot problem-solution pairs   |
| `gotchas.md`          | Swift 6 concurrency, SwiftLint, rate limits        |
| `linux-compat.md`     | Linux/Windows platform workarounds                 |
| `testing-workflow.md` | Testing guidelines, commit format                  |
| `pkl-codegen.md`      | pkl-swift generated types, enum bridging, codegen  |
| `Sources/*/CLAUDE.md` | Module-specific patterns, modification checklists  |

These rules are loaded lazily when working with related files.

## Session Wrap-Up

After completing a task, call `Skill(claude-md-management:revise-claude-md)` to capture learnings and update CLAUDE.md.
