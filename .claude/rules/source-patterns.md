# Source & Integration Patterns

## Module Boundaries

ExFigCore does NOT import FigmaAPI. Constants on `Component` (FigmaAPI, extended in ExFigCLI) are
not accessible from ExFigCore types (`IconsSourceInput`, `ImagesSourceInput`). Keep default values
as string literals in ExFigCore inits; use shared constants only within ExFigCLI.

ExFigConfig imports ExFigCore but NOT ExFigCLI — `ExFigError` is not available. Use `ColorsConfigError` (ExFigCore) for validation errors.

## Source-Aware File ID Resolution (SourceKindBridging)

`resolvedFileId` must be source-kind-aware: when `resolvedSourceKind == .penpot`, return ONLY `penpotSource?.fileId` (not coalescent `?? figmaFileId`).
Passing a Figma file key to Penpot API causes cryptic UUID parse errors. Same principle applies to any future source-specific identifiers.

## Source Dispatch (ColorsExportContextImpl)

`ColorsExportContextImpl.loadColors()` uses `SourceFactory` per-call dispatch (NOT injected source).
This enables per-entry `sourceKind` — different entries in one config can use different sources.
Do NOT inject `colorsSource` at context construction time — it breaks multi-source configs.

## Lazy Figma Client Pattern

`resolveClient(accessToken:...)` accepts `String?`. When nil (no `FIGMA_PERSONAL_TOKEN`), returns `NoTokenFigmaClient()` — a fail-fast client that throws `accessTokenNotFound` on any request. Non-Figma sources never call it. `SourceFactory` also guards the `.figma` branch. This avoids making `Client?` cascade through 20+ type signatures.

## RTL Detection Design

- `Component.iconName`: uses `containingComponentSet.name` for variants, own `name` otherwise
- `Component.codeConnectNodeId`: uses `containingComponentSet.nodeId` for variants, own `nodeId` otherwise (Figma Code Connect rejects variant node IDs)
- `Component.defaultRTLProperty = "RTL"`: shared constant in ExFigCLI for the magic string
- `rtlActiveValues: Listing<String>? = new { "On" }`: configurable per-entry list of variant values that mean "active RTL" (skipped during export). `shouldSkipAsRTLVariant(propertyName:activeValues:)` checks against this list. Known pairs (case-sensitive): Off↔On, off↔on, false↔true, False↔True, No↔Yes, no↔yes, 0↔1
- PNG images intentionally do NOT carry `isRTL` — raster images skip mirroring by design
- `buildPairedComponents` must use `iconName` (not `name`) — variant `name` is `"RTL=Off"`, not the icon name

## Penpot Source Patterns

- `PenpotClientFactory.makeClient(baseURL:)` — shared factory in `Source/PenpotClientFactory.swift`. Returns `any PenpotClient` (protocol, not `BasePenpotClient`) for testability. All Penpot sources use this (NOT a static on any single source).
- `PenpotShape.ShapeType` enum — `.path`, `.rect`, `.circle`, `.group`, `.frame`, `.bool`, `.unknown(String)`. Exhaustive switch in renderer (no `default` branch).
- `PenpotComponent.MainInstance` struct — pairs `id` + `page` (both or neither). Computed properties `mainInstanceId`/`mainInstancePage` for backward compat.
- `PenpotShapeRenderer.renderSVGResult()` — returns `Result<RenderResult, RenderFailure>` with `skippedShapeTypes` and typed failure reasons. `renderSVG()` is a convenience wrapper.
- Dictionary iteration from Penpot API (`colors`, `typographies`, `components`) must be sorted by key for deterministic export order: `.sorted(by: { $0.key < $1.key })`.
- `exfig fetch --source penpot` — `FetchSource` enum in `DownloadOptions.swift`. Route: `--source` flag > wizard result > default `.figma`. Also `--penpot-base-url` for self-hosted.
- Penpot fetch supports only `svg` and `png` formats — unsupported formats (pdf, webp, jpg) throw an error.
- Download commands (`download all/colors/icons/images/typography`) are **Figma-only** by design. Penpot export uses `exfig colors/icons/images` (via SourceFactory) and `exfig fetch --source penpot`.

## Entry Bridge Source Kind Resolution

Entry bridge methods (`iconsSourceInput()`, `imagesSourceInput()`) use `resolvedSourceKind` (computed property on `Common_FrameSource`)
instead of `sourceKind?.coreSourceKind ?? .figma`. This auto-detects Penpot when `penpotSource` is set.
`Common_VariablesSource` has its own `resolvedSourceKind` in `VariablesSourceValidation.swift` (includes tokensFile + penpot detection).

Entry bridge methods also use `resolvedFileId` (`penpotSource?.fileId ?? figmaFileId`) and `resolvedPenpotBaseURL`
(`penpotSource?.baseUrl`) from `SourceKindBridging.swift` to pass source-specific values through flat SourceInput fields.

## Generated PKL Config URIs

Templates in `*Config.swift` use `.exfig/schemas/` as placeholder paths. `GenerateConfigFile.substitutePackageURI()`
replaces them with `package://github.com/DesignPipe/exfig/releases/download/v{VERSION}/exfig@{VERSION}#/` at generation
time. Version comes from `ExFigCommand.version`. `exfig init` does NOT extract local schemas — config references the
published PKL package directly.

## PKL Consumer Config DRY Patterns

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

## Destination.url Contract (FileContents.swift)

`URL(fileURLWithPath:)` → `lastPathComponent` (iOS/Android/Web). `URL(string:)` → preserves subdirectories (Flutter). See `ExFigCore/CLAUDE.md`.

## MCP SDK Windows Exclusion

MCP `swift-sdk` depends on `swift-nio` which doesn't compile on Windows. All MCP files are wrapped
in `#if canImport(MCP)` and the dependency is conditionally included via `#if !os(Windows)` in Package.swift.
`ExFigCommand.allSubcommands` computed property (not array literal) handles conditional `MCPServe` registration.

## MCP SDK Version (0.12.0+)

MCP SDK 0.12.0 changed Content enum: `.text` case now has `(text:, annotations:, _meta:)`.
Both `.text(_:metadata:)` and `.text(text:metadata:)` factories are deprecated but functional.
`GetPrompt.Parameters.arguments` changed from `[String: Value]?` to `[String: String]?`.

## Build Environment (Swift 6.3 via swiftly)

Swift 6.3 is managed by swiftly (`.swift-version` file), not mise. Always use `./bin/mise run build` and `./bin/mise run test` — mise handles PATH and DEVELOPER_DIR automatically.
Under the hood: swiftly provides Swift 6.3; Xcode provides macOS SDK with XCTest. Both are needed for `swift test`.

## Dependency Version Coupling (swift-resvg ↔ swift-svgkit)

`swift-svgkit` uses `exact:` pin on `swift-resvg`. When bumping resvg version (e.g., for Windows artifactbundle),
must first update and tag swift-svgkit with the new resvg version, then update ExFig's Package.swift.

## Figma API Endpoint

FigmaAPI is now an external package (`swift-figma-api`). See its repository for endpoint patterns.
