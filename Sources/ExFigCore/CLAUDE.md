# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Module Overview

ExFigCore is the domain core of ExFig — zero external dependencies (Foundation only), no imports of FigmaAPI or CLI modules. All types are `Sendable` for Swift 6 concurrency. Other modules depend on ExFigCore's protocols and models, never the reverse.

## Architecture

### Protocol-Driven Export Pipeline

```
PlatformPlugin (iOS/Android/Flutter/Web)
  → registers AssetExporter conformances
    → ColorsExporter / IconsExporter / ImagesExporter / TypographyExporter

Exporter.export*(entries, platformConfig, context)
  1. context.load*()    → raw assets from Figma
  2. context.process*() → normalized AssetPair arrays
  3. exporter writes    → FileContents to disk
```

**Context protocols** (`ColorsExportContext`, `IconsExportContext`, etc.) inject all I/O dependencies — Figma loading, downloading, format conversion — so exporters stay pure transform logic.

### Design Source Abstraction

`Protocol/DesignSource.swift` defines per-asset-type source protocols:

- `ColorsSource`, `ComponentsSource`, `TypographySource` — no `sourceKind` in protocols (clean contract)
- `DesignSourceKind` enum — dispatch discriminator (.figma, .penpot, .tokensFile, .tokensStudio, .sketchFile)
- `ColorsSourceConfig` protocol + `FigmaColorsConfig` / `TokensFileColorsConfig` — type-erased source-specific config
- `ColorsSourceInput` uses `sourceKind` + `sourceConfig: any ColorsSourceConfig` instead of flat fields
- `ColorsSourceInput.spinnerLabel`: computed property for user-facing spinner messages (dispatches on `sourceConfig` type)
- `TokensFileColorsConfig.ignoredModeNames`: carries Figma-specific mode field names set by user for warning
- `IconsSourceInput`, `ImagesSourceInput`, `TypographySourceInput` have `sourceKind` field (default `.figma`)
- When adding a new `ColorsSourceConfig` subtype: update `spinnerLabel` switch in `ExportContext.swift`

Implementations live in `Sources/ExFigCLI/Source/` — `FigmaColorsSource`, `TokensFileColorsSource`, `FigmaComponentsSource`, `FigmaTypographySource`, `SourceFactory`.

### Domain Models

| Type            | Role                                                                                       |
| --------------- | ------------------------------------------------------------------------------------------ |
| `Color`         | RGBA (0.0–1.0), original + processed name                                                  |
| `Image`         | Single variant: scale (`.all` vector / `.individual` raster), format, URL, idiom, RTL flag |
| `ImagePack`     | Collection of `Image` variants + Code Connect metadata (nodeId, fileId)                    |
| `TextStyle`     | Font, size, line height, letter spacing, text case, dynamic type style                     |
| `AssetPair<T>`  | Groups up to 4 appearance variants: light, dark, lightHC, darkHC                           |
| `AssetMetadata` | Figma node/file identifiers for cache and Code Connect                                     |

All conform to `Asset` protocol (`name: String`, `platform: Platform?`, `Hashable`, `Sendable`).

### Input/Output Type Pattern

Each asset type has a symmetric set:

- `*SourceInput` — what to fetch (file IDs, frame names, options)
- `*LoadOutput` — raw fetched data (light/dark arrays)
- `*ProcessResult` — validated pairs + optional warning
- `*ExportResult` — write summary (count, skipped, hashes)

### Processing Pipeline (Processor/)

`ColorsProcessor`, `ImagesProcessor`, `TypographyProcessor` conform to `AssetsProcessable`:

1. Normalize names (`/` → `_`, deduplicate prefixes)
2. Validate via regex (`AssetsValidatorError`: badName, duplicate, countMismatch)
3. Apply `NameStyle` (camelCase, snake_case, PascalCase, flatCase, kebab-case, SCREAMING_SNAKE_CASE)
4. Pair light/dark/HC variants into `AssetPair`s
5. Return `AssetResult<Success, Error>` — data + optional warning (non-fatal issues proceed)

### FileContents & Destination

`FileContents` represents a file to write with three data sources: in-memory `data`, on-disk `dataFile`, remote `sourceURL`.

**`Destination.url` contract:** `URL(fileURLWithPath:)` → `lastPathComponent` only (iOS/Android/Web); `URL(string:)` → preserves subdirectories (Flutter). `FileWriter` creates intermediate dirs from `destination.url.deletingLastPathComponent()`.

### Concurrency (Concurrency/)

`parallelMapEntries()` — sliding window of max 5 concurrent tasks, preserves result order, cancels on first failure. Single entry bypasses TaskGroup overhead. Used by all platform exporters.

### Granular Cache Extensions

Optional protocols `IconsExportContextWithGranularCache` / `ImagesExportContextWithGranularCache` add:

- `loadIconsWithGranularCache()` / `loadImagesWithGranularCache()` — return computed hashes per node
- `processIconNames()` / `processImageNames()` — lightweight name-only processing for skipped assets

## Key Conventions

- **AssetPair variant matching:** dark/HC variants fall back to light (universal) when incomplete — generates warning, not error
- **Name processing order:** normalize → filter → replace (regex capture groups) → apply NameStyle → validate uniqueness
- **NameStyle dark suffixes** are platform-aware: `"Dark"` (camelCase), `"_dark"` (snake), `"-dark"` (kebab)
- **ImagePack.name setter** propagates to all contained `Image` instances
- **`AssetsFilter`** converts wildcard patterns (`"icon_*"`) to regex via `NSRegularExpression`

## Modification Checklist

When adding a field to `*SourceInput`:

1. Update all platform entry bridge methods (`iconsSourceInput()`/`imagesSourceInput()`) in `Sources/ExFig-*/Config/*Entry.swift`
2. Update inline `SourceInput()` constructions in exporters
3. Update loader config factory methods and context implementations
4. Update test fixtures (EnumBridgingTests, LoaderConfigTests)

When adding a new `AssetExporter` type:

1. Define protocol in `Protocol/`
2. Add corresponding `*ExportContext`, `*SourceInput`, `*LoadOutput`, `*ProcessResult`
3. Add processor in `Processor/`
4. Register in `PlatformPlugin.exporters()` for each platform
