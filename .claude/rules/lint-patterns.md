# Lint Command Patterns

`exfig lint -i exfig.pkl` validates Figma file structure against PKL config.
Rules in `Sources/ExFigCLI/Lint/Rules/`, engine in `LintEngine.swift`.
Each rule implements `LintRule` protocol with `check(context: LintContext) -> [LintDiagnostic]`.
`LintRule` extension provides `diagnostic()` factory pre-filled with rule metadata — use instead of raw `LintDiagnostic` init.
Uses `FigmaAPI.Client.request(SomeEndpoint(...))` directly (no convenience methods on Client).
`ComponentsEndpoint` returns `[Component]`, `VariablesEndpoint` returns `VariablesMeta`,
`NodesEndpoint` returns `[NodeId: Node]`.

## Rule Development Patterns

- Every rule must filter components by BOTH `figmaFrameName` AND `figmaPageName` from config entries
- Skip RTL variants: `comp.containingFrame.containingComponentSet != nil && comp.name.contains("RTL=")`
- Skip root frame fills when checking boundVariables — root `Document` fills are backgrounds, check only children
- Cross-file variable IDs (32+ char hex hash before `/`) are valid external library refs, not broken aliases
- `LintDataCache` actor caches Components/Variables API responses — use `context.cache.components(for:client:)`
- Rules MUST emit diagnostics on API failure — never `catch { continue }` silently. Follow `FramePageMatchRule` pattern
- Empty `fileId` guards must return a diagnostic, not silently `return []`
- `LintSeverity` is `Comparable` — use `>=` directly, no `severityRank()` helpers
- `LintOutputFormat` and `LintSeverity` conform to `ExpressibleByArgument` — use as `@Option` types directly
- Lint rules checking component names MUST use `comp.iconName` (not `comp.name`) — for variants, `name` is the variant value, not the icon name
- Deduplicate variants by `containingComponentSet.nodeId` before grouping — multiple variants of one set are NOT duplicates
- Adding error handling to `check()` increases cyclomatic complexity — extract per-entry logic into private methods
- For unit-testable validation logic in lint rules, use `internal` (not `private`) methods — allows `@testable import` testing without network calls (e.g., `validateParsedSVG`)
- `LintEngineTests.defaultEngineHasAllRules` checks exact set of rule IDs — must add new rule ID when registering in `LintEngine.default`
- `NodesEndpoint` supports `geometry: .paths` parameter — returns `fillGeometry`/`strokeGeometry` with SVG path data on vector nodes. **Not suitable for pathData validation** — Figma's SVG export flattens masks/booleans into different paths than raw geometry
- `PathDataLengthRule` checks ALL platform icon entries (iOS/Android/Flutter/Web), deduplicates by fileId+frame+page. Downloads SVGs via `ImageEndpoint` + `URLSession`, parses with `SVGParser`, validates with `PathDataValidator`. Only reports critical >32,767 byte errors (800-char threshold removed as too noisy). Groups by fileId, batches ImageEndpoint by 50, parallelizes SVG downloads (max 10 concurrent) and fileIds
- `InvalidRTLVariantValueRule` validates RTL variant property values against configured `rtlActiveValues` (default `["On"]`) and their known counterpart pairs (On↔Off, true↔false, True↔False, Yes↔No, 0↔1). Uses Components API only (no ImageEndpoint). Collects icon entries from all platforms with `rtlProperty` and `rtlActiveValues`, deduplicates by fileId+frame+page+rtlProperty. `validateRTLValues` and `validValues(for:)` are internal for testability. Suggests either renaming in Figma or adding value to `rtlActiveValues` config
