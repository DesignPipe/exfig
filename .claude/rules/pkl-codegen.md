# PKL Codegen (pkl-swift)

Config types are generated from PKL schemas via `pkl run @pkl.swift/gen.pkl`. DO NOT edit `Sources/ExFigConfig/Generated/*.pkl.swift` manually.

## Regeneration

```bash
./bin/mise run codegen:pkl   # requires pkl 0.31+ (uses pkl run @pkl.swift/gen.pkl)
```

The codegen uses `pkl run @pkl.swift/gen.pkl` (not the removed `pkl-gen-swift` binary).
Requires `PklProject.deps.json` and `generator-settings.pkl` in `Schemas/` directory.
If `PklProject.deps.json` is missing, run: `cd Sources/ExFigCLI/Resources/Schemas && pkl project resolve`

Schemas: `Sources/ExFigCLI/Resources/Schemas/{ExFig,Common,Figma,iOS,Android,Flutter,Web}.pkl`
Output: `Sources/ExFigConfig/Generated/*.pkl.swift` (committed to repo)

## Codegen Side Effects

`codegen:pkl` rewrites ALL 9 `Generated/*.pkl.swift` even when one schema changed, and the
generator omits the trailing newline. This (a) breaks the `hk` `newlines` (end-of-file-fixer)
hook and (b) leaves 8 unrelated files with a 1-line newline-only diff.
Fix: `git checkout --` the files whose schema you didn't touch, then
`./bin/mise exec -- hk util end-of-file-fixer --fix Sources/ExFigConfig/Generated/<Changed>.pkl.swift`.

## Type Mapping

| PKL | Swift Generated |
|-----|----------------|
| `module Foo` | `enum Foo {}` (namespace) |
| `class Bar` in module Foo | `Foo.Bar` struct |
| `Listing<T>?` | `[T]?` |
| `open class` | protocol + `*Impl` struct |
| `typealias` union | `enum: String, CaseIterable` |
| `Number?` | `Double?` |

## Enum Bridging

Generated enums use PKL raw values converted to Swift case names by the pkl-swift codegen:
- `"snake_case"` → `.snake_case` (underscore preserved)
- `"kebab-case"` → `.kebabCase` (hyphen converted to camelCase)
- `"SCREAMING_SNAKE_CASE"` → `.sCREAMING_SNAKE_CASE`

**Gotcha:** After regenerating, check bridging switch statements in `Sources/ExFig-*/Config/*Entry.swift` — case names may change.

Bridge to ExFigCore enums via rawValue:
```swift
entry.coreNameStyle   // Common.NameStyle → ExFigCore.NameStyle
entry.coreRenderMode  // iOS.XcodeRenderMode → ExFigCore.XcodeRenderMode
```

Convenience properties live in `Sources/ExFig-*/Config/*Entry.swift` extensions.

## URL Bridging

Generated types use `String?` for paths. Convenience URL properties:
- `entry.colorSwiftURL`, `entry.imageSwiftURL`, `entry.swiftUIImageSwiftURL`
- `platform.outputURL`, `platform.templatesPathURL`, `platform.mainResURL`

URL bridging lives in `Sources/ExFigCLI/Input/PKLConfigCompat.swift` and platform entry files.

## PKL Package Versioning

Consumer configs reference published package URIs:
`package://github.com/DesignPipe/exfig/releases/download/v2.0.0-beta.5/exfig@2.0.0-beta.5#/ExFig.pkl`
Schema changes (defaults, constraints, new fields) only take effect after publishing a new release.
Don't remove fields from consumer configs until the package version with those defaults is published.

## SwiftLint

`Sources/ExFigConfig/Generated/` is excluded in `.swiftlint.yml` — generated code triggers false positives.

## Test Fixtures

PKL test fixtures in `Tests/ExFigTests/Fixtures/PKL/`. Entry fields are always arrays (`Listing`), never single objects.

JSON test fixtures (FileIdProviderTests) must use array format for entries:
```json
"colors": [{ "tokensFileId": "..." }]   // correct
"colors": { "tokensFileId": "..." }     // wrong — was legacy single-entry format
```
