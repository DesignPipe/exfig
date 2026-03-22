# ExFig Architecture

ExFig v2.0 uses a plugin-based architecture with twelve modules. This document explains the system design and how to extend it.

@Metadata {
    @PageImage(purpose: icon, source: "architecture-icon", alt: "Architecture overview")
    @PageColor(orange)
    @TitleHeading("Contributing")
}

## Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         ExFig CLI                               │
│  ┌─────────────┐  ┌─────────────┐  ┌───────────────────────┐   │
│  │ Subcommands │  │ PluginReg.  │  │ Context Impls         │   │
│  │ (colors,    │──│ (routing)   │──│ (ColorsExportContext  │   │
│  │  icons...)  │  │             │  │  IconsExportContext)  │   │
│  └─────────────┘  └─────────────┘  └───────────────────────┘   │
└────────────────────────────┬────────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
┌───────────────┐   ┌────────────────┐   ┌────────────────────┐
│  ExFig-iOS    │   │ ExFig-Android  │   │ ExFig-Flutter/Web  │
│  ┌─────────┐  │   │  ┌─────────┐   │   │   ┌─────────┐      │
│  │iOSPlugin│  │   │  │Android  │   │   │   │Flutter  │      │
│  └────┬────┘  │   │  │Plugin   │   │   │   │Plugin   │      │
│       │       │   │  └────┬────┘   │   │   └────┬────┘      │
│  ┌────▼────┐  │   │  ┌────▼────┐   │   │   ┌────▼────┐      │
│  │Exporters│  │   │  │Exporters│   │   │   │Exporters│      │
│  │ Colors  │  │   │  │ Colors  │   │   │   │ Colors  │      │
│  │ Icons   │  │   │  │ Icons   │   │   │   │ Icons   │      │
│  │ Images  │  │   │  │ Images  │   │   │   │ Images  │      │
│  └─────────┘  │   │  └─────────┘   │   │   └─────────┘      │
└───────────────┘   └────────────────┘   └────────────────────┘
        │                    │                    │
        └────────────────────┼────────────────────┘
                             │
                             ▼
        ┌────────────────────────────────────────┐
        │              ExFigCore                  │
        │  ┌──────────────┐  ┌───────────────┐   │
        │  │  Protocols   │  │ Domain Models │   │
        │  │PlatformPlugin│  │ Color, Image  │   │
        │  │AssetExporter │  │ TextStyle     │   │
        │  │ColorsExporter│  │ ColorPair     │   │
        │  └──────────────┘  └───────────────┘   │
        └────────────────────────────────────────┘
```

## Module Responsibilities

### ExFigCLI

Main executable. Handles:
- CLI commands (colors, icons, images, typography, batch)
- PKL config loading via ExFigConfig
- Plugin coordination via PluginRegistry
- Context implementations bridging plugins to services
- File I/O, TerminalUI, caching

### ExFigCore

Shared protocols and domain models:
- `PlatformPlugin` — platform registration
- `AssetExporter` — base export protocol
- `ColorsExporter` / `IconsExporter` / `ImagesExporter` — specialized protocols
- `ColorsExportContext` / `IconsExportContext` — dependency injection
- Domain models: `Color`, `ColorPair`, `Image`, `TextStyle`

### ExFigConfig

PKL configuration:
- `PKLLocator` — finds pkl CLI
- `PKLEvaluator` — runs pkl eval and decodes JSON
- Shared config types: `SourceConfig`, `AssetConfiguration`

### ExFig-iOS / Android / Flutter / Web

Platform plugins:
- `*Plugin` — platform registration, exporter factory
- `*Entry` types — configuration models
- `*Exporter` — export implementations

### External Packages

- **swift-figma-api** (`FigmaAPI`) — Figma REST API client with rate limiting, retry, and 46 endpoints
- **swift-penpot-api** (`PenpotAPI`) — Penpot RPC API client with SVG shape reconstruction
- **swift-svgkit** (`SVGKit`) — SVG parsing, ImageVector and VectorDrawable generation

### XcodeExport / AndroidExport / FlutterExport / WebExport

Platform-specific file generation:
- Asset catalog generation (xcassets, VectorDrawable)
- Code generation (Swift extensions, Kotlin, Dart, CSS)
- Template rendering via Jinja2

### JinjaSupport

Shared Jinja2 template rendering utilities used across all Export modules.

## Key Protocols

### PlatformPlugin

Represents a target platform:

```swift
public protocol PlatformPlugin: Sendable {
    var identifier: String { get }        // "ios", "android", etc.
    var platform: Platform { get }        // .ios, .android, etc.
    var configKeys: Set<String> { get }   // ["ios"] for PKL routing

    func exporters() -> [any AssetExporter]
}
```

### AssetExporter

Base protocol for all exporters:

```swift
public protocol AssetExporter: Sendable {
    var assetType: AssetType { get }  // .colors, .icons, .images, .typography
}
```

### ColorsExporter

Specialized protocol for colors:

```swift
public protocol ColorsExporter: AssetExporter {
    associatedtype Entry: Sendable
    associatedtype PlatformConfig: Sendable

    func exportColors(
        entries: [Entry],
        platformConfig: PlatformConfig,
        context: some ColorsExportContext
    ) async throws -> Int
}
```

### ColorsExportContext

Dependency injection for exporters:

```swift
public protocol ColorsExportContext: ExportContext {
    func loadColors(from source: ColorsSourceInput) async throws -> ColorsLoadOutput
    func processColors(
        _ colors: ColorsLoadOutput,
        platform: Platform,
        nameValidateRegexp: String?,
        nameReplaceRegexp: String?,
        nameStyle: NameStyle
    ) throws -> ColorsProcessResult
}
```

## Data Flow

```
┌──────────────┐
│ exfig.pkl    │
└──────┬───────┘
       │
       ▼ PKLEvaluator (pkl eval --format json)
       │
       ▼ JSON → PKLConfig (JSONDecoder)
       │
       ▼ PluginRegistry.plugin(forConfigKey: "ios")
       │
       ▼ iOSPlugin.exporters()
       │
       ▼ [iOSColorsExporter, iOSIconsExporter, ...]
       │
       ▼ exporter.exportColors(entries, platformConfig, context)
       │
       ├──▶ context.loadColors(source)  → Figma Variables API
       │
       ├──▶ context.processColors(...)  → ColorsProcessor
       │
       └──▶ exporter → XcodeExport (xcassets, Swift)
                │
                ▼ context.writeFiles([FileContents])
```

## Plugin Registry

Central coordination point:

```swift
let registry = PluginRegistry.default  // Contains all 4 plugins

// Find plugin by config key
if let plugin = registry.plugin(forConfigKey: "ios") {
    for exporter in plugin.exporters() {
        if let colorsExporter = exporter as? iOSColorsExporter {
            try await colorsExporter.exportColors(...)
        }
    }
}

// Find plugin by platform
if let plugin = registry.plugin(for: .android) {
    // Use Android plugin
}
```

## Adding a New Platform

### 1. Create Module

Create `Sources/ExFig-NewPlatform/`:

```
Sources/ExFig-NewPlatform/
├── NewPlatformPlugin.swift
├── Config/
│   ├── NewPlatformColorsEntry.swift
│   ├── NewPlatformIconsEntry.swift
│   └── NewPlatformImagesEntry.swift
└── Export/
    ├── NewPlatformColorsExporter.swift
    ├── NewPlatformIconsExporter.swift
    └── NewPlatformImagesExporter.swift
```

### 2. Define Plugin

```swift
// NewPlatformPlugin.swift
import ExFigCore

public struct NewPlatformPlugin: PlatformPlugin {
    public let identifier = "newplatform"
    public let platform: Platform = .custom("newplatform")
    public let configKeys: Set<String> = ["newplatform"]

    public init() {}

    public func exporters() -> [any AssetExporter] {
        [
            NewPlatformColorsExporter(),
            NewPlatformIconsExporter(),
            NewPlatformImagesExporter(),
        ]
    }
}
```

### 3. Define Entry Types

```swift
// Config/NewPlatformColorsEntry.swift
public struct NewPlatformColorsEntry: Codable, Sendable {
    // Source fields (can use common.variablesColors)
    public let tokensFileId: String?
    public let tokensCollectionName: String?
    public let lightModeName: String?
    public let darkModeName: String?

    // Platform-specific fields
    public let outputPath: String
    public let format: OutputFormat
}
```

### 4. Implement Exporter

```swift
// Export/NewPlatformColorsExporter.swift
import ExFigCore

public struct NewPlatformColorsExporter: ColorsExporter {
    public typealias Entry = NewPlatformColorsEntry
    public typealias PlatformConfig = NewPlatformConfig

    public func exportColors(
        entries: [Entry],
        platformConfig: PlatformConfig,
        context: some ColorsExportContext
    ) async throws -> Int {
        var totalCount = 0

        for entry in entries {
            // 1. Load from Figma
            let source = ColorsSourceInput(
                tokensFileId: entry.tokensFileId ?? context.commonSource?.tokensFileId,
                // ... other fields
            )
            let loaded = try await context.loadColors(from: source)

            // 2. Process
            let processed = try context.processColors(
                loaded,
                platform: .custom("newplatform"),
                nameValidateRegexp: entry.nameValidateRegexp,
                nameReplaceRegexp: entry.nameReplaceRegexp,
                nameStyle: entry.nameStyle
            )

            // 3. Generate output files
            let files = try generateOutput(processed, entry: entry)

            // 4. Write files
            try context.writeFiles(files)

            totalCount += processed.colorPairs.count
        }

        return totalCount
    }
}
```

### 5. Add PKL Schema

```pkl
// Sources/ExFigCLI/Resources/Schemas/NewPlatform.pkl
module NewPlatform

import "Common.pkl"

class ColorsEntry extends Common.VariablesSource {
    outputPath: String
    format: "json"|"xml"|"yaml"
}

class NewPlatformConfig {
    basePath: String
    colors: (ColorsEntry|Listing<ColorsEntry>)?
}
```

### 6. Register in Package.swift

```swift
.target(
    name: "ExFig-NewPlatform",
    dependencies: ["ExFigCore"],
    path: "Sources/ExFig-NewPlatform"
),
```

### 7. Register in PluginRegistry

```swift
// Sources/ExFigCLI/Plugin/PluginRegistry.swift
import ExFig_NewPlatform

public static let `default` = PluginRegistry(plugins: [
    iOSPlugin(),
    AndroidPlugin(),
    FlutterPlugin(),
    WebPlugin(),
    NewPlatformPlugin(),  // Add here
])
```

## Context Implementation Pattern

Exporters receive a context for dependencies. The CLI provides concrete implementations:

```swift
// Plugin defines protocol
public protocol ColorsExportContext: ExportContext {
    func loadColors(from: ColorsSourceInput) async throws -> ColorsLoadOutput
    func processColors(...) throws -> ColorsProcessResult
}

// CLI provides implementation
struct ColorsExportContextImpl: ColorsExportContext {
    let client: FigmaClient
    let ui: TerminalUI

    func loadColors(from source: ColorsSourceInput) async throws -> ColorsLoadOutput {
        let loader = ColorsVariablesLoader(client: client, ...)
        return try await loader.load()
    }

    func processColors(...) throws -> ColorsProcessResult {
        let processor = ColorsProcessor(...)
        return processor.process(...)
    }
}
```

This enables:
- Plugins are testable with mock contexts
- CLI controls batch optimizations (pipelining, caching)
- Exporters remain simple and focused

## Batch Processing Integration

Plugins don't know about batch mode. Context implementations check for batch state:

```swift
struct IconsExportContextImpl: IconsExportContext {
    func downloadFiles(_ files: [DownloadRequest]) async throws {
        if BatchSharedState.current != nil {
            // Use shared download queue for batch optimization
            try await pipelinedDownloader.download(files)
        } else {
            // Standalone mode
            try await fileDownloader.download(files)
        }
    }
}
```

## Testing

### Plugin Tests

```swift
// Tests/ExFig-iOSTests/iOSPluginTests.swift
func testIdentifier() {
    let plugin = iOSPlugin()
    XCTAssertEqual(plugin.identifier, "ios")
}

func testExportersCount() {
    let plugin = iOSPlugin()
    XCTAssertEqual(plugin.exporters().count, 4)
}
```

### Exporter Tests with Mock Context

```swift
struct MockColorsExportContext: ColorsExportContext {
    var loadedColors: ColorsLoadOutput?

    func loadColors(from: ColorsSourceInput) async throws -> ColorsLoadOutput {
        return loadedColors ?? ColorsLoadOutput(light: [], dark: [], lightHC: [], darkHC: [])
    }
}

func testColorsExporter() async throws {
    let exporter = iOSColorsExporter()
    let context = MockColorsExportContext(loadedColors: mockColors)

    let count = try await exporter.exportColors(
        entries: [testEntry],
        platformConfig: testConfig,
        context: context
    )

    XCTAssertEqual(count, 5)
}
```

## File Structure Summary

```
Sources/
├── ExFigCLI/                 # CLI executable
│   ├── Subcommands/          # colors, icons, images commands
│   ├── Plugin/               # PluginRegistry
│   ├── Context/              # *ExportContextImpl
│   ├── Source/               # Design source implementations
│   ├── MCP/                  # Model Context Protocol server
│   └── Resources/Schemas/    # PKL schemas
├── ExFigCore/                # Protocols, domain models
│   └── Protocol/             # PlatformPlugin, *Exporter
├── ExFigConfig/              # PKL infrastructure
│   └── PKL/                  # PKLLocator, PKLEvaluator
├── ExFig-iOS/                # iOS plugin
│   ├── Config/               # Entry types
│   └── Export/               # Exporters
├── ExFig-Android/            # Android plugin
├── ExFig-Flutter/            # Flutter plugin
├── ExFig-Web/                # Web plugin
├── XcodeExport/              # iOS file generation
├── AndroidExport/            # Android file generation
├── FlutterExport/            # Flutter file generation
├── WebExport/                # Web file generation
└── JinjaSupport/             # Shared Jinja2 template rendering
```

## Design Principles

1. **Plugin isolation**: Each platform is independent, can build/test separately
2. **Protocol-based**: Exporters depend on protocols, not concrete types
3. **Context injection**: Dependencies passed via context, enabling testing
4. **Batch transparency**: Plugins don't know about batch optimizations
5. **PKL-first**: Configuration is type-safe at parse time
6. **Sendable**: All protocols require Sendable for async safety
