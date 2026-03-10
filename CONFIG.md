# ExFig Configuration

ExFig uses [PKL](https://pkl-lang.org/) (Programmable, Scalable, Safe) as its configuration language. Configuration is
defined in an `exfig.pkl` file that is validated against typed schemas at evaluation time.

## Setting Up Schemas

ExFig ships with PKL schema files that provide type checking, autocompletion, and documentation for your config. Extract
them into your project:

```bash
exfig schemas
```

This creates a `.exfig/schemas/` directory with all schema files (`ExFig.pkl`, `Figma.pkl`, `Common.pkl`, `iOS.pkl`,
`Android.pkl`, `Flutter.pkl`, `Web.pkl`). Your config file references these schemas via `amends` and `import`
statements.

Alternatively, you can reference schemas directly via the published PKL package URI (no local extraction needed):

```pkl
amends "package://github.com/alexey1312/ExFig/releases/download/v2.0.0/exfig@2.0.0#/ExFig.pkl"

import "package://github.com/alexey1312/ExFig/releases/download/v2.0.0/exfig@2.0.0#/iOS.pkl"
import "package://github.com/alexey1312/ExFig/releases/download/v2.0.0/exfig@2.0.0#/Figma.pkl"
import "package://github.com/alexey1312/ExFig/releases/download/v2.0.0/exfig@2.0.0#/Common.pkl"
```

Replace `2.0.0` with your ExFig version. Using local schemas (`exfig schemas`) is recommended for faster evaluation
and offline support.

## Quick Start

Generate a working configuration file for your platform:

```bash
# Generate iOS config
exfig init -p ios

# Generate Android config
exfig init -p android

# Generate Flutter config
exfig init -p flutter

# Generate Web config
exfig init -p web
```

This creates an `exfig.pkl` file with all available options documented as comments. Edit the file to match your project
and run:

```bash
exfig colors -i exfig.pkl
exfig icons -i exfig.pkl
exfig images -i exfig.pkl
exfig typography -i exfig.pkl
```

## Config Discovery

ExFig automatically searches for a config file in the current directory:

1. `exfig.pkl`

Use the `-i` or `--input` flag to specify a custom path:

```bash
exfig colors -i ./configs/my-config.pkl
```

## Unified Config with Batch

A single `exfig.pkl` can contain all resource types (colors, icons, images, typography). Use the `batch` command to
export everything at once:

```bash
# Export all resource types from a single unified config
exfig batch exfig.pkl

# With version tracking
exfig batch exfig.pkl --cache

# With rate limiting and retries
exfig batch exfig.pkl --cache --rate-limit 25 --max-retries 5
```

**Note:** The `batch` command takes config paths as **positional arguments** (not via `-i` flag), unlike individual
commands (`colors`, `icons`, `images`) which use `-i`.

This is the recommended approach for projects with multiple resource types — one config file, one command.

## Config File Structure

Every `exfig.pkl` file starts with an `amends` declaration pointing to the root schema, followed by imports for the
platform modules you need:

```pkl
amends ".exfig/schemas/ExFig.pkl"

import ".exfig/schemas/Figma.pkl"
import ".exfig/schemas/Common.pkl"
import ".exfig/schemas/iOS.pkl"
```

The root schema (`ExFig.pkl`) defines these top-level properties:

| Property  | Type                     | Description                      |
| --------- | ------------------------ | -------------------------------- |
| `figma`   | `Figma.FigmaConfig?`     | Figma file IDs and API settings  |
| `common`  | `Common.CommonConfig?`   | Shared settings across platforms |
| `ios`     | `iOS.iOSConfig?`         | iOS platform configuration       |
| `android` | `Android.AndroidConfig?` | Android platform configuration   |
| `flutter` | `Flutter.FlutterConfig?` | Flutter platform configuration   |
| `web`     | `Web.WebConfig?`         | Web/React platform configuration |

---

## Figma

The `figma` section configures which Figma files to export from. Required for icons, images, and typography. Optional
when using only `common.variablesColors` for colors.

```pkl
figma = new Figma.FigmaConfig {
  // [required] Figma file ID for light mode colors, icons, images, and typography.
  // Find it in the Figma URL: figma.com/file/<FILE_ID>/...
  lightFileId = "shPilWnVdJfo10YF12345"

  // [optional] Figma file ID for dark mode colors and images.
  darkFileId = "KfF6DnJTWHGZzC912345"

  // [optional] Figma file ID for light high contrast colors.
  // lightHighContrastFileId = "KfF6DnJTWHGZzC912345"

  // [optional] Figma file ID for dark high contrast colors.
  // darkHighContrastFileId = "KfF6DnJTWHGZzC912345"

  // [optional] API request timeout in seconds. Default: 30.
  // CLI flag --timeout overrides this value.
  // timeout = 60
}
```

| Field                     | Type      | Required | Description                                  |
| ------------------------- | --------- | -------- | -------------------------------------------- |
| `lightFileId`             | `String?` | Yes*     | File ID for light mode (icons, images, etc.) |
| `darkFileId`              | `String?` | No       | File ID for dark mode                        |
| `lightHighContrastFileId` | `String?` | No       | File ID for light high contrast              |
| `darkHighContrastFileId`  | `String?` | No       | File ID for dark high contrast               |
| `timeout`                 | `Number?` | No       | API timeout in seconds (default: 30)         |

*Required for icons, images, typography. Optional when using only Variables API for colors.

---

## Common

The `common` section defines settings shared across all platforms: name validation, cache, and Figma source
configuration.

```pkl
common = new Common.CommonConfig {
  // [optional] Version tracking cache
  cache = new Common.Cache {
    enabled = true
    path = ".exfig-cache.json"
  }

  // [optional] Colors settings (for Styles API)
  colors = new Common.Colors { ... }

  // [optional] Colors from Figma Variables API (cannot be used together with colors)
  variablesColors = new Common.VariablesColors { ... }

  // [optional] Icons settings
  icons = new Common.Icons { ... }

  // [optional] Images settings
  images = new Common.Images { ... }

  // [optional] Typography settings
  typography = new Common.Typography { ... }
}
```

### Cache

```pkl
cache = new Common.Cache {
  // Enable version tracking. Default: false
  enabled = true
  // Custom path to cache file. Default: .exfig-cache.json
  path = ".exfig-cache.json"
}
```

### Colors (Styles API)

Used when exporting colors from Figma Color Styles (legacy). For Figma Variables, use `variablesColors` instead.

```pkl
colors = new Common.Colors {
  // [optional] RegExp for color name validation. "/" in names is replaced by "_" before matching.
  nameValidateRegexp = "^([a-zA-Z_]+)$"
  // [optional] Replacement pattern using captured groups ($n).
  nameReplaceRegexp = "color_$1"
  // [optional] Extract light/dark from a single file. Default: false
  useSingleFile = false
  // [optional] Suffix for dark mode. Default: "_dark"
  darkModeSuffix = "_dark"
  // [optional] Suffix for light high contrast. Default: "_lightHC"
  // lightHCModeSuffix = "_lightHC"
  // [optional] Suffix for dark high contrast. Default: "_darkHC"
  // darkHCModeSuffix = "_darkHC"
}
```

| Field                | Type       | Description                                 |
| -------------------- | ---------- | ------------------------------------------- |
| `nameValidateRegexp` | `String?`  | RegExp for validating/capturing color names |
| `nameReplaceRegexp`  | `String?`  | Replacement pattern with captured groups    |
| `useSingleFile`      | `Boolean?` | Extract all modes from lightFileId          |
| `darkModeSuffix`     | `String?`  | Dark mode name suffix (default: `_dark`)    |
| `lightHCModeSuffix`  | `String?`  | Light HC suffix (default: `_lightHC`)       |
| `darkHCModeSuffix`   | `String?`  | Dark HC suffix (default: `_darkHC`)         |

### VariablesColors (Variables API)

Used when exporting colors from Figma Variables. Provides a shared source that all platforms reference.

```pkl
variablesColors = new Common.VariablesColors {
  // [required] Figma file ID containing the variables
  tokensFileId = "shPilWnVdJfo10YF12345"
  // [required] Name of the variable collection
  tokensCollectionName = "Design Tokens"
  // [required] Column name for light mode values
  lightModeName = "Light"
  // [optional] Column name for dark mode values
  darkModeName = "Dark"
  // [optional] Column name for light high contrast values
  // lightHCModeName = "Contrast Light"
  // [optional] Column name for dark high contrast values
  // darkHCModeName = "Contrast Dark"
  // [optional] Column name for primitives layer
  // primitivesModeName = "Collection_1"
  // [optional] RegExp for color name validation
  // nameValidateRegexp = "^([a-zA-Z_]+)$"
  // [optional] Replacement pattern
  // nameReplaceRegexp = "color_$1"
}
```

| Field                  | Type      | Required | Description                    |
| ---------------------- | --------- | -------- | ------------------------------ |
| `tokensFileId`         | `String`  | Yes      | Figma file ID with variables   |
| `tokensCollectionName` | `String`  | Yes      | Variable collection name       |
| `lightModeName`        | `String`  | Yes      | Column for light mode          |
| `darkModeName`         | `String?` | No       | Column for dark mode           |
| `lightHCModeName`      | `String?` | No       | Column for light high contrast |
| `darkHCModeName`       | `String?` | No       | Column for dark high contrast  |
| `primitivesModeName`   | `String?` | No       | Column for primitives/aliases  |
| `nameValidateRegexp`   | `String?` | No       | RegExp for name validation     |
| `nameReplaceRegexp`    | `String?` | No       | Replacement pattern            |

### Icons

```pkl
icons = new Common.Icons {
  // [optional] Figma frame name. Default: "Icons"
  figmaFrameName = "Icons"
  // [optional] Figma page name to filter by (useful when multiple pages share the same frame name)
  // figmaPageName = "Outlined"
  // [optional] RegExp for icon name validation
  nameValidateRegexp = "^(ic)_(\\d\\d)_([a-z0-9_]+)$"
  // [optional] Replacement pattern
  nameReplaceRegexp = "icon_$2_$1"
  // [optional] Extract light/dark from a single file. Default: false
  useSingleFile = false
  // [optional] Suffix for dark mode icons. Default: "_dark"
  darkModeSuffix = "_dark"
  // [optional] Exit with error when pathData exceeds 32,767 bytes (AAPT limit). Default: false
  // strictPathValidation = true
}
```

### Images

```pkl
images = new Common.Images {
  // [optional] Figma frame name. Default: "Illustrations"
  figmaFrameName = "Illustrations"
  // [optional] Figma page name to filter by (useful when multiple pages share the same frame name)
  // figmaPageName = "Marketing"
  // [optional] RegExp for image name validation
  nameValidateRegexp = "^(img)_([a-z0-9_]+)$"
  // [optional] Replacement pattern
  nameReplaceRegexp = "image_$2"
  // [optional] Extract light/dark from a single file. Default: false
  useSingleFile = false
  // [optional] Suffix for dark mode images. Default: "_dark"
  darkModeSuffix = "_dark"
}
```

### Typography

```pkl
typography = new Common.Typography {
  // [optional] RegExp for text style name validation
  nameValidateRegexp = "^[a-zA-Z0-9_]+$"
  // [optional] Replacement pattern
  nameReplaceRegexp = "font_$1"
}
```

### FrameSource (Inherited Fields)

All Icons and Images entries across platforms extend `Common.FrameSource`, which provides:

| Field                | Type      | Default | Description                                             |
| -------------------- | --------- | ------- | ------------------------------------------------------- |
| `figmaFrameName`     | `String?` | —       | Override Figma frame name for this entry                |
| `figmaPageName`      | `String?` | —       | Filter by Figma page name for this entry                |
| `figmaFileId`        | `String?` | —       | Override Figma file ID for this entry                   |
| `rtlProperty`        | `String?` | `"RTL"` | Figma component property name for RTL variant detection |
| `nameValidateRegexp` | `String?` | —       | Regex pattern for name validation                       |
| `nameReplaceRegexp`  | `String?` | —       | Replacement pattern using captured groups               |

**RTL Detection:** When `rtlProperty` is set (default `"RTL"`), ExFig detects RTL support via Figma
COMPONENT_SET variant properties. Components with `RTL=On` variant are automatically skipped (iOS/Android
handle mirroring at runtime). Components with `RTL=Off` variant are marked as RTL-supported, and the icon
name is taken from the COMPONENT_SET name instead of the variant name.

Priority: variant property > description-based detection (legacy fallback: if description contains "rtl").

Set `rtlProperty = null` to disable variant-based detection and use only description-based fallback.

---

## iOS

The `ios` section configures export for Xcode projects using `.xcassets` and Swift code generation.

```pkl
import ".exfig/schemas/iOS.pkl"

ios = new iOS.iOSConfig {
  xcodeprojPath = "./Example.xcodeproj"
  target = "UIComponents"
  xcassetsPath = "./Resources/Assets.xcassets"
  xcassetsInMainBundle = true
  // xcassetsInSwiftPackage = false
  // resourceBundleNames = new Listing {}
  // addObjcAttribute = false
  // templatesPath = "./Resources/Templates"

  colors = new iOS.ColorsEntry { ... }
  icons = new iOS.IconsEntry { ... }
  images = new iOS.ImagesEntry { ... }
  typography = new iOS.Typography { ... }
}
```

### iOSConfig (root)

| Field                    | Type               | Required | Description                                            |
| ------------------------ | ------------------ | -------- | ------------------------------------------------------ |
| `xcodeprojPath`          | `String`           | Yes      | Path to `.xcodeproj` file                              |
| `target`                 | `String`           | Yes      | Xcode target for resources and Swift code              |
| `xcassetsPath`           | `String?`          | No*      | Path to `Assets.xcassets` directory                    |
| `xcassetsInMainBundle`   | `Boolean`          | Yes      | Whether assets are in the main bundle                  |
| `xcassetsInSwiftPackage` | `Boolean?`         | No       | Whether assets are in a Swift package (default: false) |
| `resourceBundleNames`    | `Listing<String>?` | No       | Resource bundle names for SPM packages                 |
| `addObjcAttribute`       | `Boolean?`         | No       | Add `@objc` to generated properties (default: false)   |
| `templatesPath`          | `String?`          | No       | Path to custom Jinja2 templates                        |

*Required when exporting colors (with `useColorAssets`), icons, or images. Can be omitted in base configs used only
for inheritance.

### iOS Colors

```pkl
colors = new iOS.ColorsEntry {
  useColorAssets = true
  assetsFolder = "Colors"
  nameStyle = "camelCase"
  colorSwift = "./Sources/UIColor+extension.swift"
  swiftuiColorSwift = "./Source/Color+extension.swift"
  // groupUsingNamespace = false
  // assetsFolderProvidesNamespace = false
  // syncCodeSyntax = true
  // codeSyntaxTemplate = "Color.{name}"
}
```

`iOS.ColorsEntry` extends `Common.VariablesSource`, so it inherits all Variables API source fields
(`tokensFileId`, `tokensCollectionName`, `lightModeName`, etc.) for multi-entry configs where each entry specifies its
own source. When using a single entry, the source comes from `common.variablesColors`.

| Field                           | Type        | Required | Description                                                                 |
| ------------------------------- | ----------- | -------- | --------------------------------------------------------------------------- |
| `useColorAssets`                | `Boolean`   | Yes      | Export to `.xcassets` (true) or code-only (false)                           |
| `assetsFolder`                  | `String?`   | No*      | Folder inside Assets.xcassets for `.colorset` files                         |
| `nameStyle`                     | `NameStyle` | Yes      | Name style: `camelCase`, `snake_case`, `PascalCase`, `SCREAMING_SNAKE_CASE` |
| `colorSwift`                    | `String?`   | No       | Path to generate UIColor extension file                                     |
| `swiftuiColorSwift`             | `String?`   | No       | Path to generate SwiftUI Color extension file                               |
| `groupUsingNamespace`           | `Boolean?`  | No       | Group by "/" using Xcode namespaces (default: false)                        |
| `assetsFolderProvidesNamespace` | `Boolean?`  | No       | Set `provides-namespace` on assetsFolder (default: false)                   |
| `syncCodeSyntax`                | `Boolean?`  | No       | Sync names to Figma codeSyntax.iOS field                                    |
| `codeSyntaxTemplate`            | `String?`   | No       | Template for codeSyntax, e.g. `"Color.{name}"`                              |

*Required when `useColorAssets = true`.

**Inherited from `VariablesSource`:** `tokensFileId`, `tokensCollectionName`, `lightModeName`, `darkModeName`,
`lightHCModeName`, `darkHCModeName`, `primitivesModeName`, `nameValidateRegexp`, `nameReplaceRegexp`.

### iOS Icons

```pkl
icons = new iOS.IconsEntry {
  format = "pdf"
  assetsFolder = "Icons"
  nameStyle = "camelCase"
  preservesVectorRepresentation = new Listing {
    "ic24TabBarMain"
    "ic24TabBarEvents"
    "ic24TabBarProfile"
  }
  imageSwift = "./Example/Source/UIImage+extension_icons.swift"
  swiftUIImageSwift = "./Source/Image+extension_icons.swift"
  // codeConnectSwift = "./CodeConnect/Icons.figma.swift"
  // renderMode = "template"
  // renderModeDefaultSuffix = "_default"
  // renderModeOriginalSuffix = "_original"
  // renderModeTemplateSuffix = "_template"
}
```

`iOS.IconsEntry` extends `Common.FrameSource`, inheriting `figmaFrameName`, `figmaPageName`, `figmaFileId`, `rtlProperty`,
`nameValidateRegexp`, and `nameReplaceRegexp`.

| Field                           | Type               | Required | Description                                                  |
| ------------------------------- | ------------------ | -------- | ------------------------------------------------------------ |
| `format`                        | `VectorFormat`     | Yes      | Icon format: `"pdf"` or `"svg"`                              |
| `assetsFolder`                  | `String`           | Yes      | Folder inside Assets.xcassets for `.imageset` files          |
| `nameStyle`                     | `NameStyle`        | Yes      | Name style for generated names                               |
| `preservesVectorRepresentation` | `Listing<String>?` | No       | Icon names to enable Preserve Vector Data. Use `"*"` for all |
| `imageSwift`                    | `String?`          | No       | Path to generate UIImage extension file                      |
| `swiftUIImageSwift`             | `String?`          | No       | Path to generate SwiftUI Image extension file                |
| `codeConnectSwift`              | `String?`          | No       | Path to generate Figma Code Connect file                     |
| `renderMode`                    | `XcodeRenderMode?` | No       | Default render mode: `"default"`, `"original"`, `"template"` |
| `renderModeDefaultSuffix`       | `String?`          | No       | Suffix for default render mode                               |
| `renderModeOriginalSuffix`      | `String?`          | No       | Suffix for original render mode                              |
| `renderModeTemplateSuffix`      | `String?`          | No       | Suffix for template render mode                              |

**Inherited from `FrameSource`:** `figmaFrameName`, `figmaPageName`, `figmaFileId`, `rtlProperty`, `nameValidateRegexp`, `nameReplaceRegexp`.

### iOS Images

```pkl
images = new iOS.ImagesEntry {
  assetsFolder = "Illustrations"
  nameStyle = "camelCase"
  scales = new Listing { 1; 2; 3 }
  imageSwift = "./Example/Source/UIImage+extension_illustrations.swift"
  swiftUIImageSwift = "./Source/Image+extension_illustrations.swift"
  // codeConnectSwift = "./CodeConnect/Images/Illustrations.figma.swift"
  // sourceFormat = "svg"
  // outputFormat = "heic"
  // heicOptions = new iOS.HeicOptions {
  //   encoding = "lossy"
  //   quality = 90
  // }
  // renderMode = "original"
  // renderModeDefaultSuffix = "_default"
  // renderModeOriginalSuffix = "_original"
  // renderModeTemplateSuffix = "_template"
}
```

| Field                      | Type                 | Required | Description                                                      |
| -------------------------- | -------------------- | -------- | ---------------------------------------------------------------- |
| `assetsFolder`             | `String`             | Yes      | Folder inside Assets.xcassets for `.imageset` files              |
| `nameStyle`                | `NameStyle`          | Yes      | Name style for generated names                                   |
| `scales`                   | `Listing<Number>?`   | No       | Scale factors (default: `[1, 2, 3]`)                             |
| `imageSwift`               | `String?`            | No       | Path to generate UIImage extension file                          |
| `swiftUIImageSwift`        | `String?`            | No       | Path to generate SwiftUI Image extension file                    |
| `codeConnectSwift`         | `String?`            | No       | Path to generate Figma Code Connect file                         |
| `sourceFormat`             | `SourceFormat?`      | No       | Source from Figma: `"png"` (default) or `"svg"` (higher quality) |
| `outputFormat`             | `ImageOutputFormat?` | No       | Output format: `"png"` (default) or `"heic"` (smaller files)     |
| `heicOptions`              | `HeicOptions?`       | No       | HEIC encoding options (when `outputFormat = "heic"`)             |
| `renderMode`               | `XcodeRenderMode?`   | No       | Default render mode for image assets                             |
| `renderModeDefaultSuffix`  | `String?`            | No       | Suffix for default render mode                                   |
| `renderModeOriginalSuffix` | `String?`            | No       | Suffix for original render mode                                  |
| `renderModeTemplateSuffix` | `String?`            | No       | Suffix for template render mode                                  |

**Inherited from `FrameSource`:** `figmaFrameName`, `figmaPageName`, `figmaFileId`, `rtlProperty`, `nameValidateRegexp`, `nameReplaceRegexp`.

**HEIC Options:**

| Field      | Type            | Description                              |
| ---------- | --------------- | ---------------------------------------- |
| `encoding` | `HeicEncoding?` | `"lossy"` (default) or `"lossless"`      |
| `quality`  | `Int(0-100)?`   | Quality for lossy encoding (default: 90) |

Note: HEIC encoding requires macOS (uses ImageIO). On Linux, falls back to PNG.

### iOS Typography

```pkl
typography = new iOS.Typography {
  fontSwift = "./Source/UIComponents/UIFont+extension.swift"
  labelStyleSwift = "./Source/UIComponents/LabelStyle+extension.swift"
  swiftUIFontSwift = "./Source/View/Common/Font+extension.swift"
  generateLabels = true
  labelsDirectory = "./Source/UIComponents/"
  nameStyle = "camelCase"
}
```

| Field              | Type        | Required | Description                                   |
| ------------------ | ----------- | -------- | --------------------------------------------- |
| `fontSwift`        | `String?`   | No       | Path to generate UIFont extension file        |
| `labelStyleSwift`  | `String?`   | No       | Path to generate LabelStyle extension file    |
| `swiftUIFontSwift` | `String?`   | No       | Path to generate SwiftUI Font extension file  |
| `generateLabels`   | `Boolean`   | Yes      | Generate UILabel subclass for each text style |
| `labelsDirectory`  | `String?`   | No*      | Directory for generated UILabel subclasses    |
| `nameStyle`        | `NameStyle` | Yes      | Name style for generated names                |

*Required when `generateLabels = true`.

---

## Android

The `android` section configures export for Android projects with XML resources and Jetpack Compose code generation.

```pkl
import ".exfig/schemas/Android.pkl"

android = new Android.AndroidConfig {
  mainRes = "./main/res"
  resourcePackage = "com.example"
  mainSrc = "./main/src/java"
  // templatesPath = "./Resources/Templates"

  colors = new Android.ColorsEntry { ... }
  icons = new Android.IconsEntry { ... }
  images = new Android.ImagesEntry { ... }
  typography = new Android.Typography { ... }
}
```

### AndroidConfig (root)

| Field             | Type      | Required | Description                                           |
| ----------------- | --------- | -------- | ----------------------------------------------------- |
| `mainRes`         | `String`  | Yes      | Path to `main/res` directory                          |
| `resourcePackage` | `String?` | No       | Package for `R` class (required for Compose code gen) |
| `mainSrc`         | `String?` | No       | Path to source directory (required for Compose)       |
| `templatesPath`   | `String?` | No       | Path to custom Jinja2 templates                       |

### Android Colors

```pkl
colors = new Android.ColorsEntry {
  composePackageName = "com.example"
  xmlOutputFileName = "colors.xml"
  // xmlDisabled = false
  // colorKotlin = "./app/src/main/java/com/example/theme/Colors.kt"
  // themeAttributes = new Android.ThemeAttributes { ... }
}
```

`Android.ColorsEntry` extends `Common.VariablesSource`, inheriting all Variables API source fields for multi-entry
configs.

| Field                | Type               | Required | Description                                           |
| -------------------- | ------------------ | -------- | ----------------------------------------------------- |
| `xmlOutputFileName`  | `String?`          | No       | Filename for XML colors (default: `figma_colors.xml`) |
| `xmlDisabled`        | `Boolean?`         | No       | Skip XML, generate only Kotlin (default: false)       |
| `composePackageName` | `String?`          | No       | Package for Compose color code                        |
| `colorKotlin`        | `String?`          | No       | Custom path for Colors.kt file                        |
| `themeAttributes`    | `ThemeAttributes?` | No       | Theme attributes configuration                        |

**Inherited from `VariablesSource`:** `tokensFileId`, `tokensCollectionName`, `lightModeName`, `darkModeName`,
`lightHCModeName`, `darkHCModeName`, `primitivesModeName`, `nameValidateRegexp`, `nameReplaceRegexp`.

**Theme Attributes:**

```pkl
themeAttributes = new Android.ThemeAttributes {
  enabled = true
  attrsFile = "../../../values/attrs.xml"
  stylesFile = "../../../values/styles.xml"
  // stylesNightFile = "../../../values-night/styles.xml"
  themeName = "Theme.MyApp.Main"
  // markerStart = "FIGMA COLORS MARKER START"
  // markerEnd = "FIGMA COLORS MARKER END"
  // autoCreateMarkers = false
  // nameTransform = new Android.NameTransform {
  //   style = "PascalCase"
  //   prefix = "color"
  //   stripPrefixes = new Listing { "extensions_"; "information_" }
  // }
}
```

| Field               | Type             | Required | Description                                                |
| ------------------- | ---------------- | -------- | ---------------------------------------------------------- |
| `enabled`           | `Boolean?`       | No       | Enable theme attributes (default: false)                   |
| `attrsFile`         | `String?`        | No*      | Path to attrs.xml (relative to mainRes)                    |
| `stylesFile`        | `String?`        | No*      | Path to styles.xml (relative to mainRes)                   |
| `stylesNightFile`   | `String?`        | No       | Path to styles-night.xml for dark mode                     |
| `themeName`         | `String`         | Yes      | Theme name for markers                                     |
| `markerStart`       | `String?`        | No       | Marker start text (default: `"FIGMA COLORS MARKER START"`) |
| `markerEnd`         | `String?`        | No       | Marker end text (default: `"FIGMA COLORS MARKER END"`)     |
| `autoCreateMarkers` | `Boolean?`       | No       | Create files with markers if missing                       |
| `nameTransform`     | `NameTransform?` | No       | Name transformation settings                               |

*Required when `enabled = true`.

**Name Transform:**

| Field           | Type               | Description                                     |
| --------------- | ------------------ | ----------------------------------------------- |
| `style`         | `NameStyle?`       | Target case style (default: PascalCase)         |
| `prefix`        | `String?`          | Prefix for attribute names (default: `"color"`) |
| `stripPrefixes` | `Listing<String>?` | Prefixes to strip before transformation         |

### Android Icons

```pkl
icons = new Android.IconsEntry {
  output = "figma-import-icons"
  composePackageName = "com.example"
  // composeFormat = "resourceReference"
  // composeExtensionTarget = "com.example.app.ui.AppIcons"
  // codeConnectPackageName = "com.example"
  // codeConnectKotlin = "./main/src/java/com/example/Icons.figma.kt"
  // nameStyle = "snake_case"
  // pathPrecision = 4
  // strictPathValidation = false
}
```

| Field                    | Type                 | Required | Description                                                        |
| ------------------------ | -------------------- | -------- | ------------------------------------------------------------------ |
| `output`                 | `String`             | Yes      | Output directory for vector drawables (relative to mainRes)        |
| `composePackageName`     | `String?`            | No       | Package for Compose icon code (also used as Code Connect fallback) |
| `composeFormat`          | `ComposeIconFormat?` | No       | `"resourceReference"` (default) or `"imageVector"`                 |
| `composeExtensionTarget` | `String?`            | No       | Extension target for ImageVector                                   |
| `nameStyle`              | `NameStyle?`         | No       | Name style for generated names                                     |
| `pathPrecision`          | `Int(1-6)?`          | No       | Coordinate precision for pathData (default: 4)                     |
| `strictPathValidation`   | `Boolean?`           | No       | Error on pathData > 32,767 bytes (default: false)                  |
| `codeConnectPackageName` | `String?`            | No       | Package for Code Connect only (overrides `composePackageName`)     |
| `codeConnectKotlin`      | `String?`            | No       | Path to generate Figma Code Connect Kotlin file                    |

**Inherited from `FrameSource`:** `figmaFrameName`, `figmaPageName`, `figmaFileId`, `rtlProperty`, `nameValidateRegexp`, `nameReplaceRegexp`.

### Android Images

```pkl
images = new Android.ImagesEntry {
  format = "webp"
  output = "figma-import-images"
  scales = new Listing { 1; 2; 3 }
  webpOptions = new Common.WebpOptions {
    encoding = "lossy"
    quality = 90
  }
  // sourceFormat = "svg"
  // codeConnectKotlin = "./main/src/java/com/example/Images.figma.kt"
}
```

| Field               | Type               | Required | Description                                                          |
| ------------------- | ------------------ | -------- | -------------------------------------------------------------------- |
| `format`            | `ImageFormat`      | Yes      | Output format: `"svg"`, `"png"`, or `"webp"`                         |
| `output`            | `String`           | Yes      | Output directory for images (relative to mainRes)                    |
| `scales`            | `Listing<Number>?` | No       | Scale factors (valid: 1, 1.5, 2, 3, 4; default: `[1, 1.5, 2, 3, 4]`) |
| `webpOptions`       | `WebpOptions?`     | No       | WebP encoding options (when format is `"webp"`)                      |
| `sourceFormat`      | `SourceFormat?`    | No       | Source from Figma: `"png"` (default) or `"svg"`                      |
| `nameStyle`         | `NameStyle?`       | No       | Name style for generated names                                       |
| `codeConnectKotlin` | `String?`          | No       | Path to generate Figma Code Connect Kotlin file                      |

**Inherited from `FrameSource`:** `figmaFrameName`, `figmaPageName`, `figmaFileId`, `rtlProperty`, `nameValidateRegexp`, `nameReplaceRegexp`.

**WebP Options:**

| Field      | Type           | Required | Description                              |
| ---------- | -------------- | -------- | ---------------------------------------- |
| `encoding` | `WebpEncoding` | Yes      | `"lossy"` or `"lossless"`                |
| `quality`  | `Int(0-100)?`  | No       | Quality for lossy encoding (default: 90) |

### Android Typography

```pkl
typography = new Android.Typography {
  nameStyle = "camelCase"
  composePackageName = "com.example"
}
```

| Field                | Type        | Required | Description                         |
| -------------------- | ----------- | -------- | ----------------------------------- |
| `nameStyle`          | `NameStyle` | Yes      | Name style for generated names      |
| `composePackageName` | `String?`   | No       | Package for Compose typography code |

---

## Flutter

The `flutter` section configures export for Flutter projects with Dart code and asset generation.

```pkl
import ".exfig/schemas/Flutter.pkl"

flutter = new Flutter.FlutterConfig {
  output = "./lib/generated"
  // templatesPath = "./Resources/Templates"

  colors = new Flutter.ColorsEntry { ... }
  icons = new Flutter.IconsEntry { ... }
  images = new Flutter.ImagesEntry { ... }
}
```

### FlutterConfig (root)

| Field           | Type      | Required | Description                          |
| --------------- | --------- | -------- | ------------------------------------ |
| `output`        | `String`  | Yes      | Base output directory for Dart files |
| `templatesPath` | `String?` | No       | Path to custom Jinja2 templates      |

### Flutter Colors

```pkl
colors = new Flutter.ColorsEntry {
  output = "colors.dart"
  className = "AppColors"
}
```

`Flutter.ColorsEntry` extends `Common.VariablesSource`, inheriting all Variables API source fields for multi-entry
configs.

| Field       | Type      | Required | Description                              |
| ----------- | --------- | -------- | ---------------------------------------- |
| `output`    | `String?` | No       | Output filename (default: `colors.dart`) |
| `className` | `String?` | No       | Class name (default: `AppColors`)        |

**Inherited from `VariablesSource`:** `tokensFileId`, `tokensCollectionName`, `lightModeName`, `darkModeName`,
`lightHCModeName`, `darkHCModeName`, `primitivesModeName`, `nameValidateRegexp`, `nameReplaceRegexp`.

### Flutter Icons

```pkl
icons = new Flutter.IconsEntry {
  output = "assets/icons"
  dartFile = "icons.dart"
  className = "AppIcons"
  // nameStyle = "snake_case"
}
```

| Field       | Type         | Required | Description                         |
| ----------- | ------------ | -------- | ----------------------------------- |
| `output`    | `String`     | Yes      | Output directory for SVG icon files |
| `dartFile`  | `String?`    | No       | Dart file for icon constants        |
| `className` | `String?`    | No       | Class name (default: `AppIcons`)    |
| `nameStyle` | `NameStyle?` | No       | Name style for generated names      |

**Inherited from `FrameSource`:** `figmaFrameName`, `figmaPageName`, `figmaFileId`, `rtlProperty`, `nameValidateRegexp`, `nameReplaceRegexp`.

### Flutter Images

```pkl
images = new Flutter.ImagesEntry {
  output = "assets/images"
  dartFile = "images.dart"
  className = "AppImages"
  format = "png"
  scales = new Listing { 1; 2; 3 }
  // nameStyle = "snake_case"
  // sourceFormat = "svg"
  // webpOptions = new Common.WebpOptions {
  //   encoding = "lossy"
  //   quality = 90
  // }
}
```

| Field          | Type                  | Required | Description                               |
| -------------- | --------------------- | -------- | ----------------------------------------- |
| `output`       | `String`              | Yes      | Output directory for image files          |
| `dartFile`     | `String?`             | No       | Dart file for image constants             |
| `className`    | `String?`             | No       | Class name (default: `AppImages`)         |
| `format`       | `ImageFormat?`        | No       | Output format: `"svg"`, `"png"`, `"webp"` |
| `scales`       | `Listing<Number>?`    | No       | Scale factors (default: `[1, 2, 3]`)      |
| `webpOptions`  | `Common.WebpOptions?` | No       | WebP encoding options                     |
| `sourceFormat` | `SourceFormat?`       | No       | Source from Figma: `"png"` or `"svg"`     |
| `nameStyle`    | `NameStyle?`          | No       | Name style for generated names            |

**Inherited from `FrameSource`:** `figmaFrameName`, `figmaPageName`, `figmaFileId`, `rtlProperty`, `nameValidateRegexp`, `nameReplaceRegexp`.

---

## Web

The `web` section configures export for Web/React projects with CSS variables, TypeScript constants, and React
components.

```pkl
import ".exfig/schemas/Web.pkl"

web = new Web.WebConfig {
  output = "./src/tokens"
  // templatesPath = "./Resources/Templates"

  colors = new Web.ColorsEntry { ... }
  icons = new Web.IconsEntry { ... }
  images = new Web.ImagesEntry { ... }
}
```

### WebConfig (root)

| Field           | Type      | Required | Description                         |
| --------------- | --------- | -------- | ----------------------------------- |
| `output`        | `String`  | Yes      | Base output directory for all files |
| `templatesPath` | `String?` | No       | Path to custom Jinja2 templates     |

### Web Colors

```pkl
colors = new Web.ColorsEntry {
  outputDirectory = "."
  cssFileName = "theme.css"
  tsFileName = "variables.ts"
  // jsonFileName = "tokens.json"
}
```

`Web.ColorsEntry` extends `Common.VariablesSource`, inheriting all Variables API source fields for multi-entry configs.

| Field             | Type      | Required | Description                                          |
| ----------------- | --------- | -------- | ---------------------------------------------------- |
| `outputDirectory` | `String?` | No       | Output directory (overrides `web.output`)            |
| `cssFileName`     | `String?` | No       | CSS file for theme variables (default: `colors.css`) |
| `tsFileName`      | `String?` | No       | TypeScript file for constants (default: `colors.ts`) |
| `jsonFileName`    | `String?` | No       | JSON file for design tokens                          |

**Inherited from `VariablesSource`:** `tokensFileId`, `tokensCollectionName`, `lightModeName`, `darkModeName`,
`lightHCModeName`, `darkHCModeName`, `primitivesModeName`, `nameValidateRegexp`, `nameReplaceRegexp`.

### Web Icons

```pkl
icons = new Web.IconsEntry {
  outputDirectory = "./src/icons"
  svgDirectory = "assets/icons"
  generateReactComponents = true
  // iconSize = 24
  // nameStyle = "PascalCase"
}
```

| Field                     | Type         | Required | Description                                   |
| ------------------------- | ------------ | -------- | --------------------------------------------- |
| `outputDirectory`         | `String`     | Yes      | Output directory for React icon components    |
| `svgDirectory`            | `String?`    | No       | Directory for raw SVG files                   |
| `generateReactComponents` | `Boolean?`   | No       | Generate React TSX components (default: true) |
| `iconSize`                | `Int?`       | No       | Icon size in pixels for viewBox (default: 24) |
| `nameStyle`               | `NameStyle?` | No       | Name style for generated names                |

**Inherited from `FrameSource`:** `figmaFrameName`, `figmaPageName`, `figmaFileId`, `rtlProperty`, `nameValidateRegexp`, `nameReplaceRegexp`.

### Web Images

```pkl
images = new Web.ImagesEntry {
  outputDirectory = "./src/images"
  assetsDirectory = "assets/images"
  generateReactComponents = true
}
```

| Field                     | Type       | Required | Description                                   |
| ------------------------- | ---------- | -------- | --------------------------------------------- |
| `outputDirectory`         | `String`   | Yes      | Output directory for React image components   |
| `assetsDirectory`         | `String?`  | No       | Directory for raw image assets                |
| `generateReactComponents` | `Boolean?` | No       | Generate React TSX components (default: true) |

**Inherited from `FrameSource`:** `figmaFrameName`, `figmaPageName`, `figmaFileId`, `rtlProperty`, `nameValidateRegexp`, `nameReplaceRegexp`.

---

## Multi-Entry Configs

ExFig supports exporting from multiple Figma frames or Variable collections in a single config. Use PKL `Listing` to
define arrays for `colors`, `icons`, and `images` on any platform.

### Multiple Colors (from different Variable collections)

```pkl
ios = new iOS.iOSConfig {
  // ...

  colors = new Listing {
    new iOS.ColorsEntry {
      tokensFileId = "file1"
      tokensCollectionName = "Semantic Colors"
      lightModeName = "Light"
      darkModeName = "Dark"
      useColorAssets = true
      assetsFolder = "Colors/Semantic"
      nameStyle = "camelCase"
      colorSwift = "./Generated/SemanticColors.swift"
    }
    new iOS.ColorsEntry {
      tokensFileId = "file2"
      tokensCollectionName = "Primitive Colors"
      lightModeName = "Default"
      useColorAssets = true
      assetsFolder = "Colors/Primitives"
      nameStyle = "camelCase"
      colorSwift = "./Generated/PrimitiveColors.swift"
    }
  }
}
```

Each entry in a multi-entry colors config is self-contained with its own Variables source fields. This differs from
single-entry mode where the source comes from `common.variablesColors`.

### Multiple Icons (from different Figma frames)

```pkl
ios = new iOS.iOSConfig {
  // ...

  icons = new Listing {
    new iOS.IconsEntry {
      figmaFrameName = "Actions"
      format = "svg"
      assetsFolder = "Icons/Actions"
      nameStyle = "camelCase"
      imageSwift = "./Generated/ActionIcons.swift"
      codeConnectSwift = "./CodeConnect/Icons/ActionIcons.figma.swift"
    }
    new iOS.IconsEntry {
      figmaFrameName = "Navigation"
      format = "svg"
      assetsFolder = "Icons/Navigation"
      nameStyle = "camelCase"
      imageSwift = "./Generated/NavigationIcons.swift"
    }
  }
}
```

### Multiple Images (from different Figma frames)

```pkl
android = new Android.AndroidConfig {
  // ...

  images = new Listing {
    new Android.ImagesEntry {
      figmaFrameName = "Illustrations"
      output = "drawable-illustrations"
      format = "svg"
    }
    new Android.ImagesEntry {
      figmaFrameName = "Photos"
      output = "drawable-photos"
      format = "webp"
      scales = new Listing { 1; 1.5; 2; 3; 4 }
      webpOptions = new Common.WebpOptions {
        encoding = "lossy"
        quality = 80
      }
    }
  }
}
```

### Fallback Behavior

For multi-entry icons and images, per-entry fields fall back to `common` settings:

1. Entry-level `figmaFrameName` (if specified)
2. `common.icons.figmaFrameName` or `common.images.figmaFrameName`
3. Default: `"Icons"` for icons, `"Illustrations"` for images

The same fallback applies to `figmaPageName`, `nameValidateRegexp`, `nameReplaceRegexp`, and `nameStyle`.

### Performance

When multiple entries reference the same Figma file, ExFig fetches components once and filters locally. For example, 10
icon entries from the same file result in 1 Components API call, not 10.

---

## Config Inheritance

PKL supports config inheritance via `amends`. Create a base config with shared settings and have project-specific
configs extend it.

**base.pkl** -- shared across teams:

```pkl
amends ".exfig/schemas/ExFig.pkl"

import ".exfig/schemas/Figma.pkl"
import ".exfig/schemas/Common.pkl"

figma = new Figma.FigmaConfig {
  lightFileId = "design-system-light"
  darkFileId = "design-system-dark"
  timeout = 60
}

common = new Common.CommonConfig {
  cache = new Common.Cache {
    enabled = true
  }
  variablesColors = new Common.VariablesColors {
    tokensFileId = "design-tokens-file"
    tokensCollectionName = "Design System"
    lightModeName = "Light"
    darkModeName = "Dark"
    lightHCModeName = "Light HC"
    darkHCModeName = "Dark HC"
  }
  icons = new Common.Icons {
    figmaFrameName = "Icons/24"
  }
}
```

**exfig.pkl** -- project-specific, inherits from base:

```pkl
amends "base.pkl"

import ".exfig/schemas/iOS.pkl"

ios = new iOS.iOSConfig {
  xcodeprojPath = "MyApp.xcodeproj"
  target = "MyApp"
  xcassetsPath = "MyApp/Resources/Assets.xcassets"
  xcassetsInMainBundle = true

  colors = new iOS.ColorsEntry {
    useColorAssets = true
    assetsFolder = "Colors"
    nameStyle = "camelCase"
  }

  icons = new iOS.IconsEntry {
    format = "pdf"
    assetsFolder = "Icons"
    nameStyle = "camelCase"
  }
}
```

The child config inherits all `figma` and `common` settings from `base.pkl` while adding its own iOS-specific
configuration.

---

## Common PKL Patterns

### Union Types: Single vs. Multiple Entries

ExFig schema fields like `colors`, `icons`, and `images` accept either a single entry or a `Listing` (array). PKL
cannot infer the type from `new { ... }` for union types, so you must use the typed constructor when writing multiple
entries.

**Single entry** — type is inferred, no explicit type needed:

```pkl
colors = new iOS.ColorsEntry {
  figmaFrameName = "Colors"
  useColorAssets = true
  assetsFolder = "Colors"
  nameStyle = "camelCase"
}
```

**Multiple entries** — MUST use typed constructor (`new Type { ... }`):

```pkl
colors = new Listing {
  new iOS.ColorsEntry {
    figmaFrameName = "Light Colors"
    useColorAssets = true
    assetsFolder = "Colors/Light"
    nameStyle = "camelCase"
  }
  new iOS.ColorsEntry {
    figmaFrameName = "Dark Colors"
    useColorAssets = true
    assetsFolder = "Colors/Dark"
    nameStyle = "camelCase"
  }
}
```

Without the typed constructor (e.g., `new { ... }` inside a Listing), PKL will report:
`Expected type iOS.ColorsEntry, but got Dynamic`.

This pattern applies to all platforms: `iOS.ColorsEntry`, `iOS.IconsEntry`, `iOS.ImagesEntry`,
`Android.ColorsEntry`, `Android.IconsEntry`, `Android.ImagesEntry`, `Flutter.ColorsEntry`, etc.

### DRY Configs with `for`-Generators

When you have many entries that share the same structure (e.g., 15+ icon categories with identical settings except
`figmaFrameName` and `assetsFolder`), use PKL `local` Mapping and `for`-generators to eliminate duplication.

**Define categories as `local` Mapping** — `local` properties are not included in the output:

```pkl
// figmaFrameName → assetsFolder
local iconCategories: Mapping<String, String> = new {
  ["Actions"] = "Actions"
  ["Chart"] = "Chart"
  ["Communication, Media, Art"] = "CommunicationMediaArt"
  ["Text editor"] = "TextEditor"
  // ... more categories
}
```

**Generate entries with `for`:**

```pkl
icons = new Listing {
  for (frameName, folder in iconCategories) {
    new iOS.IconsEntry {
      figmaFrameName = frameName
      format = "svg"
      xcassetsPath = "./Resources/Icons.xcassets"
      assetsFolder = folder
      imageSwift = "./Generated/\(folder)Icons.generated.swift"
    }
  }
}
```

You can mix manual entries and `for`-generators in the same `Listing`:

```pkl
icons = new Listing {
  // Manual entries for special cases
  new iOS.IconsEntry {
    figmaFrameName = "Colored Icons"
    renderMode = "default"
    // ...
  }

  // Generated entries for categories with identical settings
  for (frameName, folder in iconCategories) {
    new iOS.IconsEntry {
      figmaFrameName = frameName
      assetsFolder = folder
      // ...
    }
  }
}
```

**String interpolation** — use `\(expr)` to build paths from category data:

```pkl
imageSwift = "./Generated/\(folder)Icons.generated.swift"
assetsFolder = "\(folder)Dc"  // e.g., "ActionsDc"
```

**Multiple Mappings** for different groups — define separate Mappings when groups need different settings:

```pkl
local allCategories: Mapping<String, String> = new { /* 17 items */ }
local dcCategories: Mapping<String, String> = new { /* 15 items — all except Logo, Template */ }

icons = new Listing {
  // Template icons from allCategories
  for (frameName, folder in allCategories) {
    new iOS.IconsEntry { /* template settings */ }
  }
  // Double Color icons from dcCategories
  for (frameName, folder in dcCategories) {
    new iOS.IconsEntry { figmaFileId = "other-file"; renderMode = "default"; /* ... */ }
  }
}
```

**Verification** — always verify that the refactored config produces the same output:

```bash
# Save output before refactoring
pkl eval --format json exfig.pkl > before.json

# After refactoring
pkl eval --format json exfig.pkl > after.json

# Compare (order of entries within Listing is preserved)
diff before.json after.json
```

---

## Validation

Validate your config file before running exports:

```bash
pkl eval --format json exfig.pkl
```

This evaluates the PKL file against the schema and outputs JSON. If the config has type errors or missing required
fields, PKL reports them with line numbers.

To check specific sections:

```bash
# Validate and view the full config as JSON
pkl eval --format json exfig.pkl

# Validate and view a specific property
pkl eval --format json -x "ios" exfig.pkl
```

Common validation errors:

| Error                          | Cause                  | Fix                                    |
| ------------------------------ | ---------------------- | -------------------------------------- |
| `Cannot find module`           | Missing schema files   | Run `exfig schemas` to extract schemas |
| `Expected type String, got...` | Wrong value type       | Check field type in schema docs above  |
| `Property not found`           | Typo in property name  | Check spelling against schema          |
| `Missing required property`    | Required field not set | Add the missing field to your config   |
