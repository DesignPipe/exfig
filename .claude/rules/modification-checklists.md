# Modification Checklists

When modifying specific parts of the codebase, ALL listed sites must be updated.

## Modifying Loader Configs (IconsLoaderConfig / ImagesLoaderConfig)

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

## Adding a New Filter Level (e.g., page filtering)

Filter predicate sites that ALL need updating:

1. `ImageLoaderBase.swift` — `fetchImageComponents` (icons + images)
2. `DownloadImageLoader.swift` — `fetchImageComponents`
3. `DownloadExportHelpers.swift` — `AssetExportHelper.fetchComponents`
4. Inline `SourceInput()` constructions in platform exporters (iOS `svgSourceInput`, Android `loadAndProcessSVG`)
5. `DownloadAll.swift` — pass filter value to both `exportIcons` and `exportImages`

## Moving/Renaming PKL Types Between Modules

When relocating a type (e.g., `Android.WebpOptions` → `Common.WebpOptions`), update ALL reference sites:

1. PKL schemas (`Schemas/*.pkl`) — definition + imports + field types
2. Codegen (`./bin/mise run codegen:pkl`)
3. Swift bridging (`Sources/ExFig-*/Config/*Entry.swift`) — typealiases + extensions
4. Init-template configs (`Sources/ExFigCLI/Resources/*Config.swift`) — `new Type { }` refs
5. PKL examples (`Schemas/examples/*.pkl`)
6. DocC docs (`ExFig.docc/**/*.md`), CONFIG.md

## Modifying SourceFactory Signatures

`createComponentsSource` has 8 call sites (4 in `PluginIconsExport` + 4 in `PluginImagesExport`) plus tests in `PenpotSourceTests.swift`. Icons sites pass `componentsCache:`, Images sites use default `nil`.
`createTypographySource` call sites: only tests (not yet wired to production export flow).
Use `replace_all` on the trailing parameter pattern (e.g., `filter: filter\n        )`) to update all sites at once.

## Modifying Node ID Logic (AssetMetadata / ImagePack)

When changing how node IDs are resolved (e.g., `codeConnectNodeId`), update ALL construction sites in `ImageLoaderBase.swift`:

1. `AssetMetadata` in `fetchImageComponentsWithGranularCache` (~line 156)
2. `AssetMetadata` in `fetchImageComponentsWithGranularCacheAndPairing` (~line 220)
3. `ImagePack` primaryNodeId in `loadVectorImages` (vector/SVG path)
4. `ImagePack` primaryNodeId in `loadPNGImages` (raster path)

## Modifying ColorsVariablesLoader Return Type

`ColorsLoaderOutput` is a tuple typealias used by both `ColorsLoader` and `ColorsVariablesLoader`.
Changing `load()` return type affects:

1. `ColorsExportContextImpl.loadColors()` — main export flow
2. `Download.Colors.exportW3C()` — download command (inside `@Sendable withSpinner` closure)
3. `DownloadAll.exportColors()` — download all command (inside `@Sendable withSpinner` closure)
4. ALL assertions in `ColorsVariablesLoaderTests` — `result.light` → `result.output.light` etc.

**`withSpinner` gotcha:** Closure is `@Sendable` — cannot capture mutable vars. Return full result from closure.

## Refactoring *SourceInput Types

When changing fields on `ColorsSourceInput` / `IconsSourceInput` / `ImagesSourceInput`:

1. Construction sites: `validatedColorsSourceInput()` in `VariablesSourceValidation.swift`, entry bridge methods in `Sources/ExFig-*/Config/*Entry.swift`
2. **Read sites in platform exporters**: `Sources/ExFig-*/Export/*Exporter.swift` — spinner messages may reference SourceInput fields
3. Download commands (`DownloadColors`, `DownloadAll`) use loaders directly, NOT `*SourceInput` — typically unaffected
4. `BatchConfigRunner` delegates via `performExportWithResult()` — typically unaffected

## Adding a CLI Command

See `ExFigCLI/CLAUDE.md` (Adding a New Subcommand).

**Important:** When adding/changing CLI flags or subcommands, update `exfig.usage.kdl` (Usage spec) to keep shell completions and docs in sync. When bumping the app version in `ExFigCommand.swift`, also update the `version` field in `exfig.usage.kdl`.

## Adding an Interactive Wizard

Follow `InitWizard.swift` / `FetchWizard.swift` pattern:

- `enum` with `static func run()` for interactive flow (NooraUI prompts)
- Pure function for testable transformation logic (e.g., `applyResult(_:to:)`)
- Reuse `WizardPlatform` from `FetchWizard.swift` (has `asPlatform` property)
- Gate on `TTYDetector.isTTY`; throw `ValidationError` for non-TTY without required flags
- Use `extractFigmaFileId(from:)` for file ID inputs (auto-extracts ID from full Figma URLs)
- Trim text prompt results with `.trimmingCharacters(in: .whitespacesAndNewlines)` before `.isEmpty` default checks

### Design Source Branching

Both `InitWizard` and `FetchWizard` ask "Figma or Penpot?" first (`WizardDesignSource` enum in `FetchWizard.swift`).
`extractPenpotFileId(from:)` extracts UUID from Penpot workspace URLs (`file-id=UUID` query param).
`InitWizardTransform` has separate methods: `applyResult` (Figma) and `applyPenpotResult` (Penpot — removes figma section, inserts penpotSource blocks).

## Adding a NooraUI Prompt Wrapper

Follow the existing pattern in `NooraUI.swift`: static method delegating to `shared` instance with matching parameter names.
Noora's `multipleChoicePrompt` uses `MultipleChoiceLimit` — `.unlimited` or `.limited(count:errorMessage:)`.

## Adding a Platform Plugin Exporter

See `ExFigCore/CLAUDE.md` (Modification Checklist) and platform module CLAUDE.md files.
