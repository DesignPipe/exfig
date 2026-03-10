# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Module Overview

XcodeExport is the **pure transformation layer** for iOS output. It converts ExFigCore domain models (`Color`, `ImagePack`, `TextStyle`) into Xcode-native file structures: `.xcassets` catalogs (`Contents.json`, colorsets, imagesets), Swift extensions (UIKit + SwiftUI), and Figma Code Connect files. It has **no I/O** — it returns `[FileContents]` for callers to write.

This module is consumed by `ExFig-iOS` exporters, which handle the pipeline orchestration (config, Figma fetch, processing) and pass results here for rendering.

## Build & Test

```bash
./bin/mise run test:filter XcodeExportTests     # This module's tests
./bin/mise run test:filter ExFig_iOSTests       # Consumer integration tests
```

## Architecture

### Class Hierarchy

```
XcodeExporterBase                  # Shared: Jinja template loading, Swift keyword escaping, FileContents creation
├── XcodeColorExporter             # Colors → colorsets + UIColor/Color extensions
├── XcodeImagesExporterBase        # Shared images logic: Swift extensions (UIKit/SwiftUI) + Code Connect
│   ├── XcodeIconsExporter         # Icons → imagesets with preservesVectorRepresentation
│   └── XcodeImagesExporter        # Images → imagesets (PNG/HEIC), also exportSwiftExtensions() for SVG source
└── XcodeTypographyExporter        # TextStyles → UIFont/Font extensions + Label/LabelStyle classes
```

### Output Configuration Types

Each exporter is initialized with an Output struct that declares **what to generate** via optional URLs:

| Output Type             | Controls                                                                                                           |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `XcodeColorsOutput`     | `assetsColorsURL`, `colorSwiftURL`, `swiftuiColorSwiftURL`, `groupUsingNamespace`, `assetsFolderProvidesNamespace` |
| `XcodeImagesOutput`     | `assetsFolderURL`, `uiKitImageExtensionURL`, `swiftUIImageExtensionURL`, `codeConnectSwiftURL`, `renderMode`       |
| `XcodeTypographyOutput` | Font extension URLs, label directory, label style extension URL                                                    |

A `nil` URL means "skip generating that file". This is how callers control which outputs are produced.

### Asset Catalog Structure

Colors generate `.colorset/Contents.json` with sRGB hex components. Dark mode and high-contrast variants use the `appearances` array (`luminosity: dark`, `contrast: high`).

Images generate `.imageset/Contents.json` with scale-qualified filenames. Dark variants get `L`/`D` suffix in filenames. The `Properties` struct controls `template-rendering-intent` and `preserves-vector-representation`.

`XcodeEmptyContents` and `XcodeFolderNamespaceContents` generate folder-level `Contents.json` (with `provides-namespace: true` for grouped colors).

### Jinja2 Templates

**bundleExtension normalization:** `Bundle+extension.swift.jinja.include` renders `"\n"` when conditions are false (Jinja2 preserves newline after `{% endif %}`). `contextWithHeaderAndBundle` strips whitespace-only results to `""` to prevent extra trailing newlines in output.

Templates in `Resources/` generate Swift code. Custom templates are supported via `templatesPath` on Output structs (falls back to bundled defaults).

| Template                           | Generated Output                          |
| ---------------------------------- | ----------------------------------------- |
| `UIColor+extension.swift.jinja`    | UIColor static properties (light/dark)    |
| `Color+extension.swift.jinja`      | SwiftUI Color static properties           |
| `UIImage+extension.swift.jinja`    | UIImage static properties                 |
| `Image+extension.swift.jinja`      | SwiftUI Image static properties           |
| `UIFont+extension.swift.jinja`     | UIFont convenience methods                |
| `Font+extension.swift.jinja`       | SwiftUI Font convenience methods          |
| `Label.swift.jinja`                | Custom UILabel subclasses per text style  |
| `LabelStyle.swift.jinja`           | Base LabelStyle protocol                  |
| `LabelStyle+extension.swift.jinja` | LabelStyle implementations per text style |
| `CodeConnect.figma.swift.jinja`    | Figma Code Connect structs                |
| `header.jinja`                     | Common "do not edit" header comment       |

Templates with `.include` suffix are partial templates used for append mode (inserting into existing files). The loop body in each `.include` file must stay in sync with the corresponding main `.jinja` template (e.g., `UIImage+extension.swift.jinja.include` ↔ `UIImage+extension.swift.jinja`). Do not add Jinja comments (`{# #}`) to `.include` files — even `{#- -#}` alters whitespace and breaks append tests.

### Append Mode

`XcodeImagesExporterBase` supports `append: true` — inserts new image properties into an existing Swift extension file by finding the last `}` and splicing content before it. Custom templates (`templatesPath != nil`) cannot use append mode.

### Granular Cache Support

Icons and images exporters accept optional `allIconNames`/`allAssetNames` and `allAssetMetadata` parameters. When granular cache is active, the main asset list may be a filtered subset (only changed assets), but extensions and Code Connect need the full list. These parameters provide the complete set.

### HEIC Export

`XcodeImagesExporter.exportForHeic()` generates Contents.json referencing `.heic` files while the actual download files are PNG. The caller (ExFig-iOS) handles the PNG→HEIC conversion post-download.

## Key Conventions

- **JSON encoding:** Uses `JSONCodec.encodePrettySorted()` for deterministic Contents.json output
- **Sort stability:** All asset lists are sorted by name before rendering (colors, images, Code Connect structs)
- **Swift keyword escaping:** `normalizeName()` wraps Swift keywords in backticks (e.g., `default` → `` `default` ``)
- **URL construction:** Uses `URL(string:)` for filenames (not `URL(fileURLWithPath:)`) — see `Destination.url` contract in root CLAUDE.md
- **Scale validation:** `Image.isValidForXcode()` filters out invalid scale/idiom combinations (e.g., 3x for iPad)
- **RTL support:** `ImageData.languageDirection` set to `"left-to-right"` when `isRTL: true`

## Modification Checklist

When adding a template context variable:

1. Add to the context dictionary in the exporter method
2. Update the `.jinja` template to use `{{ variableName }}`
3. Update tests — exporter tests verify rendered output strings

When adding a new Output field:

1. Add property to the Output struct with a default value in `init`
2. Wire into the exporter's context dictionary
3. Update `ExFig-iOS` entry extension that constructs the Output (e.g., `iOSImagesEntry.makeXcodeImagesOutput()`)

When modifying `XcodeAssetContents`:

1. Update struct and its nested types
2. Verify JSON output in `XcodeAssetContentsTests`
3. Check that `Properties` failable init still returns `nil` correctly when no properties are set
