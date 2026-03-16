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
./bin/mise run docs:preview         # Preview docs in browser
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

# PKL Validation (validate config templates against schemas)
pkl eval --format json <file.pkl>   # Package URI requires published package
# For local validation, replace package:// URIs with local Schemas/ paths
```

## Project Context

| Aspect          | Details                                                                            |
| --------------- | ---------------------------------------------------------------------------------- |
| Language        | Swift 6.2, macOS 13.0+                                                             |
| Package Manager | Swift Package Manager                                                              |
| CLI Framework   | swift-argument-parser                                                              |
| Config Format   | PKL (Programmable, Scalable, Safe)                                                 |
| Templates       | Jinja2 (swift-jinja)                                                               |
| Required Env    | `FIGMA_PERSONAL_TOKEN`                                                             |
| Config Files    | `exfig.pkl` (PKL configuration)                                                    |
| Tooling         | mise (`./bin/mise` self-contained, no global install needed)                       |
| Platforms       | macOS 13+ (primary), Linux/Ubuntu 22.04 (CI) - see `.claude/rules/linux-compat.md` |

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
6. DocC docs (`ExFig.docc/**/*.md`), CONFIG.md, MIGRATION.md

### Module Boundaries

ExFigCore does NOT import FigmaAPI. Constants on `Component` (FigmaAPI, extended in ExFigCLI) are
not accessible from ExFigCore types (`IconsSourceInput`, `ImagesSourceInput`). Keep default values
as string literals in ExFigCore inits; use shared constants only within ExFigCLI.

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

### Adding a Figma API Endpoint

FigmaAPI is now an external package (`swift-figma-api`). See its repository for endpoint patterns.

### Adding a Platform Plugin Exporter

See `ExFigCore/CLAUDE.md` (Modification Checklist) and platform module CLAUDE.md files.

### Destination.url Contract (FileContents.swift)

`URL(fileURLWithPath:)` → `lastPathComponent` (iOS/Android/Web). `URL(string:)` → preserves subdirectories (Flutter). See `ExFigCore/CLAUDE.md`.

## Code Conventions

| Area            | Use                               | Instead of                            |
| --------------- | --------------------------------- | ------------------------------------- |
| JSON parsing    | `JSONCodec` (swift-yyjson)        | `JSONDecoder`/`JSONEncoder`           |
| JSON DOM access | `JSONCodec.parseValue(from:)`     | `JSONSerialization` / `import YYJSON` |
| Terminal UI     | Noora (`NooraUI`, `TerminalText`) | Rainbow color methods                 |
| Terminal output | `TerminalUI` facade               | Direct `print()` calls                |
| README.md       | Keep compact (~300 lines)         | Detailed docs (use CONFIG.md / DocC)  |

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

## Dependencies

| Package               | Version | Purpose                                            |
| --------------------- | ------- | -------------------------------------------------- |
| swift-argument-parser | 1.5.0+  | CLI framework                                      |
| swift-collections     | 1.2.x   | Ordered collections                                |
| swift-jinja           | 2.0.0+  | Jinja2 template engine                             |
| XcodeProj             | 8.27.0+ | Xcode project manipulation                         |
| swift-log             | 1.6.0+  | Logging                                            |
| Rainbow               | 4.2.0+  | Terminal colors                                    |
| libwebp               | 1.4.1+  | WebP encoding                                      |
| libpng                | 1.6.45+ | PNG decoding                                       |
| swift-custom-dump     | 1.3.0+  | Test assertions                                    |
| Noora                 | 0.54.0+ | Terminal UI design system                          |
| swift-figma-api       | 0.1.0+  | Figma REST API client (async/await, rate limiting) |
| swift-svgkit          | 0.1.0+  | SVG parsing, ImageVector/VectorDrawable generation |
| swift-resvg           | 0.45.1  | SVG parsing/rendering                              |
| swift-docc-plugin     | 1.4.5+  | DocC documentation                                 |
| swift-yyjson          | 0.5.0+  | High-performance JSON codec                        |
| pkl-swift             | 0.8.0+  | PKL config evaluation & codegen                    |

## Troubleshooting

| Problem                     | Solution                                                                                                     |
| --------------------------- | ------------------------------------------------------------------------------------------------------------ |
| codegen:pkl gen.pkl error   | gen.pkl `read?` bug: needs `--generator-settings` + `--project-dir` flags (see mise.toml)                    |
| xcsift "signal code 5"      | False positive when piping `swift test` through xcsift; run `swift test` directly to verify                  |
| PKL tests need Pkl 0.31+    | Schemas use `isNotEmpty`; run tests via `./bin/mise exec -- swift test` to get correct Pkl in PATH           |
| PKL FrameSource change      | Update ALL entry init calls in tests (EnumBridgingTests, IconsLoaderConfigTests)                             |
| Build fails                 | `swift package clean && swift build`                                                                         |
| Tests fail                  | Check `FIGMA_PERSONAL_TOKEN` is set                                                                          |
| Formatting fails            | Run `./bin/mise run setup` to install tools                                                                  |
| test:filter no matches      | SPM converts hyphens→underscores: use `ExFig_FlutterTests` not `ExFig-FlutterTests`                          |
| Template errors             | Check Jinja2 syntax and context variables                                                                    |
| Linux test hangs            | Build first: `swift build --build-tests`, then `swift test --skip-build --parallel`                          |
| Android pathData long       | Simplify in Figma or use `--strict-path-validation`                                                          |
| PKL parse error 1           | Check `PklError.message` — actual error is in `.message`, not `.localizedDescription`                        |
| Test target won't compile   | Broken test files block entire target; use `swift test --filter Target.Class` after `build`                  |
| Test helper JSON decode     | `ContainingFrame` uses default Codable (camelCase: `nodeId`, `pageName`), NOT snake_case                     |
| Web entry test fails        | Web entry types use `outputDirectory` field, while Android/Flutter use `output`                              |
| Logger concatenation err    | `Logger.Message` (swift-log) requires interpolation `"\(a) \(b)"`, not concatenation `a + b`                 |
| Deleted variables in output | Filter `VariableValue.deletedButReferenced != true` in variable loaders AND `CodeSyntaxSyncer`               |
| mise "sources up-to-date"   | mise caches tasks with `sources`/`outputs` — run script directly via `bash` when debugging                   |
| Jinja trailing `\n`         | `{% if false %}...{% endif %}\n` renders `"\n"`, not `""` — strip whitespace-only partial template results   |
| `Bundle.module` in tests    | SPM test targets without declared resources don't have `Bundle.module` — use `Bundle.main` or temp bundle    |
| SwiftLint trailing closure  | When function takes 2+ closures, use explicit label for last closure (`export: { ... }`) not trailing syntax |

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
| `gotchas.md`          | Swift 6 concurrency, SwiftLint, rate limits        |
| `linux-compat.md`     | Linux-specific workarounds                         |
| `testing-workflow.md` | Testing guidelines, commit format                  |
| `pkl-codegen.md`      | pkl-swift generated types, enum bridging, codegen  |
| `Sources/*/CLAUDE.md` | Module-specific patterns, modification checklists  |

These rules are loaded lazily when working with related files.

## Session Wrap-Up

After completing a task, call `Skill(claude-md-management:revise-claude-md)` to capture learnings and update CLAUDE.md.
