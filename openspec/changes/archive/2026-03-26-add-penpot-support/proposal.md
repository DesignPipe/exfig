## Why

Penpot is an open-source Figma competitor with a rapidly growing user base. ExFig already has a `DesignSource` abstraction with `DesignSourceKind.penpot` (declared but not implemented). Adding Penpot as a second data source implements Phase 3 of ROADMAP.md and validates the multi-source architecture.

## What Changes

- New `PenpotAPI` module — Swift HTTP client for Penpot RPC API (analogous to `swift-figma-api`)
- `PenpotColorsSource` — loads library colors from Penpot files
- `PenpotComponentsSource` — loads components (icons, illustrations) via thumbnails API
- `PenpotTypographySource` — loads typographies from Penpot files
- `PenpotColorsConfig` in ExFigCore — type-erased config for Penpot colors
- `PenpotSource` PKL class in Common.pkl — Penpot source configuration
- `SourceFactory` — replaces `throw unsupportedSourceKind(.penpot)` with real implementations
- Env var `PENPOT_ACCESS_TOKEN` for authentication
- E2E tests against a real Penpot instance

**v1 limitation**: Penpot API has no public endpoint for rendering components as SVG/PNG (the exporter is an internal service based on headless Chromium). Icons and illustrations are exported as raster thumbnails.

## Capabilities

### New Capabilities

- `penpot-api`: HTTP client for Penpot RPC API (`/api/main/methods/`) — client, endpoints (`get-file`, `get-profile`, `get-file-object-thumbnails`), response models (Color, Component, Typography, Shape), error handling. JSON responses use camelCase (standard Codable, no CodingKeys needed)
- `penpot-source`: Penpot integration with ExFig DesignSource — `PenpotColorsSource`, `PenpotComponentsSource`, `PenpotTypographySource`, `PenpotColorsConfig`, PKL schema, SourceFactory wiring

### Modified Capabilities

- `source-dispatch`: SourceFactory replaces `throw unsupportedSourceKind(.penpot)` with real Penpot source implementations
- `design-source-protocol`: Adds `PenpotColorsConfig: ColorsSourceConfig` and spinnerLabel for `.penpot`

## Impact

- **New module**: `Sources/PenpotAPI/` (~13 files), `Tests/PenpotAPITests/`
- **New files**: `Sources/ExFigCLI/Source/Penpot{Colors,Components,Typography}Source.swift`
- **Modified files**: `Package.swift`, `DesignSource.swift`, `ExportContext.swift`, `SourceFactory.swift`, `Common.pkl`
- **Dependencies**: PenpotAPI → swift-yyjson (already present). No new external dependencies
- **Env vars**: `PENPOT_ACCESS_TOKEN` (required when sourceKind=penpot), `PENPOT_BASE_URL` (optional)
- **PKL codegen**: `./bin/mise run codegen:pkl` after modifying Common.pkl
- **Entry bridge**: `Sources/ExFig-*/Config/*Entry.swift` — mapping `penpotSource` fields
