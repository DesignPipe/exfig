# Variable-Mode Dark Icons (VariableModeDarkGenerator)

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

## Logging & Validation

- Every `guard ... else { continue }` in the generation loop must log a warning — silent skips cause invisible data loss
- `resolveDarkColor` must check `deletedButReferenced != true` (same as all other variable loaders)
- `SVGColorReplacer` uses separate regex replacement templates per pattern (attribute patterns have 3 capture groups, CSS patterns have 2 — never share a single template)
- `Config.init` uses `precondition(!fileId.isEmpty)` — catches the documented empty-fileId bug at construction time

## Alias Resolution

`resolveDarkColor` alias targets resolve using the target collection's `defaultModeId`, NOT the requested modeId — test expectations must account for this (e.g., alias to primitive resolves via "light" default mode, not "dark").

## pkl-swift Decoding

pkl-swift uses **keyed** decoding (by property name, not positional). TypeRegistry is only for `PklAny` polymorphic types and performance — concrete `Decodable` structs (like `VariablesDarkMode`) decode via synthesized `init(from:)` regardless of `registerPklTypes`. New types should still be added to `registerPklTypes()` for completeness, but missing entries do NOT cause silent nil for concrete typed fields.

## Cross-File Variable Resolution

Figma variable IDs are file-scoped — alias targets from the icons file don't exist in library files by ID. When `variablesFileId` is set, variables are loaded from BOTH files: icons file (semantic variables matching node boundVariables) + library file (primitives for alias resolution). Matching is by variable **name** across files and mode **name** across collections (not IDs).

## Caching Patterns

**VariablesCache:** `VariablesCache` (Lock + Task dedup) caches Variables API responses by fileId across parallel entries. Created per platform section in `PluginIconsExport`, injected through `SourceFactory` → `FigmaComponentsSource` → `VariableModeDarkGenerator`. Failed tasks are evicted (`lock.withLock { tasks[fileId] = nil }` in catch) — transient Figma API errors (429) don't permanently poison the cache.

**ComponentsCache:** `ComponentsCache` (same Lock + Task dedup) caches Components API responses by fileId across parallel entries in standalone mode. Solves the problem that `ComponentPreFetcher` only works in batch mode (`BatchSharedState` is nil in standalone). Created per platform section in `PluginIconsExport`, injected through `SourceFactory` → `FigmaComponentsSource` → `ImageLoaderBase`.

## Alpha Handling

`SVGColorReplacer` supports opacity via `ColorReplacement(hex, alpha)`. When `alpha < 1.0`, replacement adds `fill-opacity`/`stroke-opacity` attributes (SVG) or `;fill-opacity:N` (CSS). Same hex with different alpha IS a valid replacement (e.g., `#D6FB94` opaque → `#D6FB94` transparent).

## Granular Cache Path

`IconsExportContextImpl.loadIconsWithGranularCache()` creates its own `IconsLoader` and bypasses `FigmaComponentsSource` entirely. Variable-mode dark generation must be applied explicitly at the end of that method via `applyVariableModeDark(to:source:)`.

## RTL in Variable-Mode Dark

`buildDarkPack` iterates ALL images in a pack (not just `.first`), preserving `isRTL`, `scale`, `idiom`, and `format` from the light variant. Temp file names include index for uniqueness: `{name}{_rtl}_{index}_dark.{format}`.
