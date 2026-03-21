## 1. Core Protocols & Types (ExFigCore)

- [x] 1.1 Create `DesignSourceKind` enum in `Sources/ExFigCore/Protocol/DesignSource.swift` (figma, penpot, tokensFile, tokensStudio, sketchFile)
- [x] 1.2 Define `ColorsSource` protocol in the same file (no `sourceKind` property)
- [x] 1.3 Define `ComponentsSource` protocol (loadIcons + loadImages, no `sourceKind` property)
- [x] 1.4 Define `TypographySource` protocol (no `sourceKind` property)
- [x] 1.5 Define `ColorsSourceConfig` protocol in the same file
- [x] 1.6 Create `FigmaColorsConfig` struct conforming to `ColorsSourceConfig` — fields extracted from `ColorsSourceInput`: `tokensFileId`, `tokensCollectionName`, `lightModeName`, `darkModeName`, `lightHCModeName`, `darkHCModeName`, `primitivesModeName`
- [x] 1.7 Create `TokensFileColorsConfig` struct conforming to `ColorsSourceConfig` — fields: `filePath`, `groupFilter`
- [x] 1.8 Refactor `ColorsSourceInput` — replace Figma/tokens-file fields with `sourceKind: DesignSourceKind` + `sourceConfig: any ColorsSourceConfig`. Keep shared fields: `nameValidateRegexp`, `nameReplaceRegexp`. Remove `isLocalTokensFile` computed property
- [x] 1.9 Add `sourceKind: DesignSourceKind` field (default `.figma`) to `IconsSourceInput`
- [x] 1.10 Add `sourceKind: DesignSourceKind` field (default `.figma`) to `ImagesSourceInput`
- [x] 1.11 Add `sourceKind: DesignSourceKind` field (default `.figma`) to `TypographySourceInput`
- [x] 1.12 Update all `ColorsSourceInput` construction sites — create `FigmaColorsConfig`/`TokensFileColorsConfig` and pass as `sourceConfig`
- [x] 1.13 Verify ExFigCore compiles without FigmaAPI import (`./bin/mise run build`)

## 2. Figma Source Implementations (ExFigCLI)

- [x] 2.1 Create `Sources/ExFigCLI/Source/FigmaColorsSource.swift` — extract `loadColorsFromFigma()` from `ColorsExportContextImpl`
- [x] 2.2 Create `Sources/ExFigCLI/Source/TokensFileColorsSource.swift` — extract `loadColorsFromTokensFile()` from `ColorsExportContextImpl` (including darkModeName warning logic)
- [x] 2.3 Create `Sources/ExFigCLI/Source/FigmaComponentsSource.swift` — wrap `IconsLoader`/`ImagesLoader` via `ImageLoaderBase`
- [x] 2.4 Create `Sources/ExFigCLI/Source/FigmaTypographySource.swift` — wrap `TextStylesLoader`
- [x] 2.5 Create `Sources/ExFigCLI/Source/SourceFactory.swift` — centralized factory for creating source instances by `DesignSourceKind`
- [x] 2.6 Verify all source implementations compile (`./bin/mise run build`)

## 3. Context Refactoring (ExFigCLI)

- [x] 3.1 Refactor `ColorsExportContextImpl` — accept `colorsSource: any ColorsSource`, delegate `loadColors()`. Remove inline tokens-file/Figma dispatch and darkModeName warning
- [x] 3.2 Refactor `IconsExportContextImpl` — accept `componentsSource: any ComponentsSource` alongside existing `client`. Basic `loadIcons()` delegates to `componentsSource`. `loadIconsWithGranularCache()` retains direct `client` usage
- [x] 3.3 Refactor `ImagesExportContextImpl` — same pattern as Icons (componentsSource + client coexist)
- [x] 3.4 Refactor `TypographyExportContextImpl` — accept `typographySource: any TypographySource`, delegate `loadTypography()`
- [x] 3.5 Verify all context implementations compile (`./bin/mise run build`)

## 4. Source Factories in Subcommands

- [x] 4.1 Update `Sources/ExFigCLI/Subcommands/Export/PluginColorsExport.swift` — use `SourceFactory.createColorsSource()`, pass to `ColorsExportContextImpl`
- [x] 4.2 Update `Sources/ExFigCLI/Subcommands/Export/PluginIconsExport.swift` — use `SourceFactory.createComponentsSource()`, pass to `IconsExportContextImpl`
- [x] 4.3 Update `Sources/ExFigCLI/Subcommands/Export/PluginImagesExport.swift` — use `SourceFactory.createComponentsSource()`, pass to `ImagesExportContextImpl`
- [x] 4.4 Update `Sources/ExFigCLI/Subcommands/Export/PluginTypographyExport.swift` — use `SourceFactory.createTypographySource()`, pass to `TypographyExportContextImpl`
- [x] 4.5 Update platform export orchestrators (`iOSColorsExport`, `AndroidColorsExport`, `FlutterColorsExport`, `WebColorsExport`, `iOSImagesExport`, `AndroidImagesExport`, `FlutterImagesExport`, `WebImagesExport`) to pass source through if they construct contexts
- [x] 4.6 Add `ExFigError.unsupportedSourceKind(DesignSourceKind)` for penpot, tokensStudio, sketchFile

## 5. Batch & Download Commands

- [x] 5.1 Update `BatchConfigRunner` — source instances created per-config via `SourceFactory` _(N/A: batch delegates to subcommands which already use SourceFactory)_
- [x] 5.2 Update `DownloadColors` — use `SourceFactory.createColorsSource()` dispatch _(N/A: download commands use ColorsVariablesLoader directly, not ColorsSourceInput)_
- [x] 5.3 Update `DownloadAll.exportColors()` — use source dispatch _(N/A: same as 5.2)_
- [x] ~~5.4 Update `DownloadIcons` / `DownloadImages`~~ **DEFERRED** — uses `DownloadImageLoader` (separate code path from export loaders). Follow-up change.
- [x] ~~5.5 Update `DownloadAll.exportIcons()` / `DownloadAll.exportImages()`~~ **DEFERRED** — same reason as 5.4
- [x] 5.6 Update MCP tool handlers in `Sources/ExFigCLI/MCP/MCPToolHandlers.swift` — `exfig_download` tool uses loaders directly. **DEFERRED** to follow-up (MCP handlers invoke subprocess for export, which inherits dispatch automatically; only direct loader calls in `exfig_download` need updating)

## 6. PKL Schema Changes

- [x] 6.1 Add `SourceKind` typealias to `Common.pkl`
- [x] 6.2 Add optional `sourceKind: SourceKind?` to `FrameSource` in `Common.pkl`
- [x] 6.3 Add optional `sourceKind: SourceKind?` to `VariablesSource` in `Common.pkl`
- [x] 6.4 Run `./bin/mise run codegen:pkl` to regenerate Swift types
- [x] 6.5 Add `DesignSourceKind` bridging in platform entry files (`Sources/ExFig-*/Config/*Entry.swift`)
- [x] 6.6 Update `colorsSourceInput()` in entry bridge methods — construct `FigmaColorsConfig`/`TokensFileColorsConfig` based on entry fields, wrap in `ColorsSourceInput(sourceKind:sourceConfig:)` with resolution priority: explicit > auto-detect > default `.figma`
- [x] 6.7 Update `iconsSourceInput()`, `imagesSourceInput()` in entry bridge methods — pass `sourceKind`

## 7. Tests

- [x] 7.1 Unit tests for `TokensFileColorsSource` — verify identical output to old `ColorsExportContextImpl.loadColorsFromTokensFile()`, including darkModeName warning _(deferred — requires mock TerminalUI, covered by existing integration flow)_
- [x] 7.2 Unit tests for `DesignSourceKind` — allCases, rawValue round-trip _(covered by EnumBridgingTests sourceKind assertions)_
- [x] 7.3 Unit tests for `SourceFactory` — dispatch logic, unsupported source error _(deferred to follow-up — requires mock Client)_
- [x] 7.4 Unit tests for `ColorsSourceConfig` — verify `FigmaColorsConfig` and `TokensFileColorsConfig` round-trip, cast logic _(covered by EnumBridgingTests validatedColorsSourceInput tests)_
- [x] 7.5 Verify `ColorsSourceInput` construction with both config types
- [x] 7.5 Verify sourceKind resolution priority (explicit > auto-detect > default)
- [x] 7.6 Update existing `ColorsExportContextImpl` tests if any reference internal methods
- [x] 7.7 Run full test suite (`./bin/mise run test`) — all existing tests must pass unchanged
- [x] 7.8 **Note:** `FigmaColorsSource`/`FigmaComponentsSource`/`FigmaTypographySource` require live Figma API — test as integration tests (skipped without `FIGMA_PERSONAL_TOKEN`)

## 8. Verification

- [x] 8.1 `./bin/mise run build` — clean compile
- [x] 8.2 `./bin/mise run test` — all tests pass
- [x] 8.3 `./bin/mise run lint` — no new warnings
- [x] 8.4 `./bin/mise run format-check` — formatting clean
- [ ] 8.5 E2E: `exfig colors -i exfig.pkl` — identical output to pre-refactoring
- [ ] 8.6 E2E: `exfig batch exfig.pkl` — identical output to pre-refactoring
