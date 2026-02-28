# Migrating from YAML to PKL

This guide walks you through converting an existing `exfig.yaml` (or `figma-export.yaml`) configuration file to the new PKL format (`exfig.pkl`).

## Why PKL?

- **Type safety**: PKL schemas catch configuration errors before runtime. Typos in property names, wrong value types, and missing required fields are caught during evaluation.
- **IDE support**: VS Code and IntelliJ plugins provide completion, validation, and hover documentation for every field.
- **Inheritance**: Share configuration between projects using `amends`. Define a base config with shared Figma tokens, then override only project-specific settings.
- **Programmable**: Computed properties, conditionals, and functions let you build dynamic configurations.
- **Documentation**: Every property has doc comments visible in the schema and in the IDE.

Learn more: <https://pkl-lang.org>

## Prerequisites

1. Install the PKL CLI: <https://pkl-lang.org/main/current/pkl-cli/index.html#installation>

2. Extract PKL schemas locally:
   ```bash
   exfig schemas
   ```
   This creates `.exfig/schemas/` with all type definitions: `ExFig.pkl`, `Figma.pkl`, `Common.pkl`, `iOS.pkl`, `Android.pkl`, `Flutter.pkl`, `Web.pkl`.

3. (Optional) Install the PKL VS Code extension for autocompletion and inline validation.

## Syntax Differences

| Concept          | YAML                 | PKL                                 |
| ---------------- | -------------------- | ----------------------------------- |
| String           | `value: "text"`      | `value = "text"`                    |
| Number           | `value: 42`          | `value = 42`                        |
| Boolean          | `value: true`        | `value = true`                      |
| Null/Optional    | omit the key         | omit the key                        |
| Array            | `- item`             | `new Listing { "item" }`            |
| Nested object    | indentation          | `new TypeName { ... }`              |
| Comment          | `# comment`          | `// comment`                        |
| Schema reference | `---` at top of YAML | `amends ".exfig/schemas/ExFig.pkl"` |
| Assignment       | `:` (colon)          | `=` (equals)                        |
| Module imports   | N/A                  | `import ".exfig/schemas/iOS.pkl"`   |

Key differences to remember:

- PKL uses `=` for assignment, not `:`
- PKL arrays use `new Listing { ... }`, not `- item`
- PKL objects require explicit type names: `new iOS.ColorsEntry { ... }`, not just indentation
- PKL uses `//` for comments, not `#`

## Step-by-Step Migration

### 1. Create the PKL file

The fastest way is to use the init command:

```bash
exfig init -p ios       # iOS-only config
exfig init -p android   # Android-only config
exfig init -p flutter   # Flutter-only config
exfig init -p web       # Web-only config
```

Or create `exfig.pkl` manually. Every PKL config file starts with the schema reference and platform imports:

```pkl
amends ".exfig/schemas/ExFig.pkl"

import ".exfig/schemas/Figma.pkl"
import ".exfig/schemas/Common.pkl"
import ".exfig/schemas/iOS.pkl"        // only if using iOS
import ".exfig/schemas/Android.pkl"    // only if using Android
import ".exfig/schemas/Flutter.pkl"    // only if using Flutter
import ".exfig/schemas/Web.pkl"        // only if using Web
```

### 2. Migrate the Figma section

**YAML:**

```yaml
figma:
  lightFileId: shPilWnVdJfo10YF12345
  darkFileId: KfF6DnJTWHGZzC912345
  lightHighContrastFileId: KfF6DnJTWHGZzC912345
  darkHighContrastFileId: KfF6DnJTWHGZzC912345
  timeout: 60
```

**PKL:**

```pkl
figma = new Figma.FigmaConfig {
  lightFileId = "shPilWnVdJfo10YF12345"
  darkFileId = "KfF6DnJTWHGZzC912345"
  lightHighContrastFileId = "KfF6DnJTWHGZzC912345"
  darkHighContrastFileId = "KfF6DnJTWHGZzC912345"
  timeout = 60
}
```

Note: In PKL, all string values must be quoted. YAML allowed unquoted strings for file IDs.

### 3. Migrate the Common section

The `common` section structure maps directly. Each sub-section uses an explicit type.

**YAML:**

```yaml
common:
  cache:
    enabled: true
    path: ".exfig-cache.json"
  colors:
    nameValidateRegexp: '^([a-zA-Z_]+)$'
    nameReplaceRegexp: 'color_$1'
    useSingleFile: true
    darkModeSuffix: '_dark'
  icons:
    figmaFrameName: Icons
    nameValidateRegexp: '^(ic)_(\d\d)_([a-z0-9_]+)$'
    nameReplaceRegexp: 'icon_$2_$1'
  images:
    figmaFrameName: Illustrations
    nameValidateRegexp: '^(img)_([a-z0-9_]+)$'
    nameReplaceRegexp: 'image_$2'
  typography:
    nameValidateRegexp: '^[a-zA-Z0-9_]+$'
    nameReplaceRegexp: 'font_$1'
```

**PKL:**

```pkl
common = new Common.CommonConfig {
  cache = new Common.Cache {
    enabled = true
    path = ".exfig-cache.json"
  }
  colors = new Common.Colors {
    nameValidateRegexp = "^([a-zA-Z_]+)$"
    nameReplaceRegexp = "color_$1"
    useSingleFile = true
    darkModeSuffix = "_dark"
  }
  icons = new Common.Icons {
    figmaFrameName = "Icons"
    nameValidateRegexp = "^(ic)_(\\d\\d)_([a-z0-9_]+)$"
    nameReplaceRegexp = "icon_$2_$1"
  }
  images = new Common.Images {
    figmaFrameName = "Illustrations"
    nameValidateRegexp = "^(img)_([a-z0-9_]+)$"
    nameReplaceRegexp = "image_$2"
  }
  typography = new Common.Typography {
    nameValidateRegexp = "^[a-zA-Z0-9_]+$"
    nameReplaceRegexp = "font_$1"
  }
}
```

Note: In PKL strings, backslashes must be escaped (`\\d` instead of `\d`). YAML single-quoted strings preserved backslashes literally.

#### Variables Colors (Figma Variables API)

If you use `variablesColors` instead of `colors`:

**YAML:**

```yaml
common:
  variablesColors:
    tokensFileId: shPilWnVdJfo10YF12345
    tokensCollectionName: Base collection
    lightModeName: Light
    darkModeName: Dark
    lightHCModeName: Contrast Light
    darkHCModeName: Contrast Dark
    primitivesModeName: Collection_1
```

**PKL:**

```pkl
common = new Common.CommonConfig {
  variablesColors = new Common.VariablesColors {
    tokensFileId = "shPilWnVdJfo10YF12345"
    tokensCollectionName = "Base collection"
    lightModeName = "Light"
    darkModeName = "Dark"
    lightHCModeName = "Contrast Light"
    darkHCModeName = "Contrast Dark"
    primitivesModeName = "Collection_1"
  }
}
```

### 4. Migrate the iOS section

**YAML:**

```yaml
ios:
  xcodeprojPath: "./Example.xcodeproj"
  target: "UIComponents"
  xcassetsPath: "./Resources/Assets.xcassets"
  xcassetsInMainBundle: true
  xcassetsInSwiftPackage: false
  addObjcAttribute: false
  colors:
    useColorAssets: true
    assetsFolder: Colors
    nameStyle: camelCase
    colorSwift: "./Sources/UIColor+extension.swift"
    swiftuiColorSwift: "./Source/Color+extension.swift"
    groupUsingNamespace: true
    syncCodeSyntax: true
    codeSyntaxTemplate: "Color.{name}"
  icons:
    format: pdf
    assetsFolder: Icons
    nameStyle: camelCase
    preservesVectorRepresentation:
      - ic24TabBarMain
      - ic24TabBarEvents
      - ic24TabBarProfile
    swiftUIImageSwift: "./Source/Image+extension_icons.swift"
    imageSwift: "./Example/Source/UIImage+extension_icons.swift"
    renderMode: default
  images:
    assetsFolder: Illustrations
    nameStyle: camelCase
    scales: [1, 2, 3]
    swiftUIImageSwift: "./Source/Image+extension_illustrations.swift"
    imageSwift: "./Example/Source/UIImage+extension_illustrations.swift"
  typography:
    fontSwift: "./Source/UIComponents/UIFont+extension.swift"
    labelStyleSwift: "./Source/UIComponents/LabelStyle+extension.swift"
    swiftUIFontSwift: "./Source/View/Common/Font+extension.swift"
    generateLabels: true
    labelsDirectory: "./Source/UIComponents/"
    nameStyle: camelCase
```

**PKL:**

```pkl
ios = new iOS.iOSConfig {
  xcodeprojPath = "./Example.xcodeproj"
  target = "UIComponents"
  xcassetsPath = "./Resources/Assets.xcassets"
  xcassetsInMainBundle = true
  xcassetsInSwiftPackage = false
  addObjcAttribute = false

  colors = new iOS.ColorsEntry {
    useColorAssets = true
    assetsFolder = "Colors"
    nameStyle = "camelCase"
    colorSwift = "./Sources/UIColor+extension.swift"
    swiftuiColorSwift = "./Source/Color+extension.swift"
    groupUsingNamespace = true
    syncCodeSyntax = true
    codeSyntaxTemplate = "Color.{name}"
  }

  icons = new iOS.IconsEntry {
    format = "pdf"
    assetsFolder = "Icons"
    nameStyle = "camelCase"
    preservesVectorRepresentation = new Listing {
      "ic24TabBarMain"
      "ic24TabBarEvents"
      "ic24TabBarProfile"
    }
    swiftUIImageSwift = "./Source/Image+extension_icons.swift"
    imageSwift = "./Example/Source/UIImage+extension_icons.swift"
    renderMode = "default"
  }

  images = new iOS.ImagesEntry {
    assetsFolder = "Illustrations"
    nameStyle = "camelCase"
    scales = new Listing { 1; 2; 3 }
    swiftUIImageSwift = "./Source/Image+extension_illustrations.swift"
    imageSwift = "./Example/Source/UIImage+extension_illustrations.swift"
  }

  typography = new iOS.Typography {
    fontSwift = "./Source/UIComponents/UIFont+extension.swift"
    labelStyleSwift = "./Source/UIComponents/LabelStyle+extension.swift"
    swiftUIFontSwift = "./Source/View/Common/Font+extension.swift"
    generateLabels = true
    labelsDirectory = "./Source/UIComponents/"
    nameStyle = "camelCase"
  }
}
```

Key changes:

- YAML arrays (`- item`) become `new Listing { "item" }` with quoted strings
- Numeric listings use semicolons: `new Listing { 1; 2; 3 }`
- Boolean values remain the same: `true`, `false`
- YAML `resourceBundleNames: []` becomes `resourceBundleNames = new Listing {}`

### 5. Migrate the Android section

**YAML:**

```yaml
android:
  mainRes: "./main/res"
  resourcePackage: "com.example"
  mainSrc: "./main/src/java"
  colors:
    composePackageName: "com.example"
    xmlOutputFileName: "colors.xml"
    themeAttributes:
      enabled: true
      attrsFile: "../../../values/attrs.xml"
      stylesFile: "../../../values/styles.xml"
      stylesNightFile: "../../../values-night/styles.xml"
      themeName: "Theme.MyApp.Main"
      nameTransform:
        style: PascalCase
        prefix: "color"
        stripPrefixes: ["extensions_", "information_"]
  icons:
    output: "figma-import-icons"
    composePackageName: "com.example"
    composeFormat: resourceReference
  images:
    format: webp
    output: "figma-import-images"
    scales: [1, 2, 3]
    webpOptions:
      encoding: lossy
      quality: 90
  typography:
    nameStyle: camelCase
    composePackageName: "com.example"
```

**PKL:**

```pkl
android = new Android.AndroidConfig {
  mainRes = "./main/res"
  resourcePackage = "com.example"
  mainSrc = "./main/src/java"

  colors = new Android.ColorsEntry {
    composePackageName = "com.example"
    xmlOutputFileName = "colors.xml"
    themeAttributes = new Android.ThemeAttributes {
      enabled = true
      attrsFile = "../../../values/attrs.xml"
      stylesFile = "../../../values/styles.xml"
      stylesNightFile = "../../../values-night/styles.xml"
      themeName = "Theme.MyApp.Main"
      nameTransform = new Android.NameTransform {
        style = "PascalCase"
        prefix = "color"
        stripPrefixes = new Listing {
          "extensions_"
          "information_"
        }
      }
    }
  }

  icons = new Android.IconsEntry {
    output = "figma-import-icons"
    composePackageName = "com.example"
    composeFormat = "resourceReference"
  }

  images = new Android.ImagesEntry {
    format = "webp"
    output = "figma-import-images"
    scales = new Listing { 1; 2; 3 }
    webpOptions = new Common.WebpOptions {
      encoding = "lossy"
      quality = 90
    }
  }

  typography = new Android.Typography {
    nameStyle = "camelCase"
    composePackageName = "com.example"
  }
}
```

Key changes:

- Nested objects like `themeAttributes` and `webpOptions` require explicit type names: `new Android.ThemeAttributes { ... }`, `new Common.WebpOptions { ... }`
- YAML inline arrays `[1, 2, 3]` become `new Listing { 1; 2; 3 }`
- YAML inline arrays of strings `["a", "b"]` become `new Listing { "a"; "b" }` (or one per line)

### 6. Migrate the Flutter section

**YAML:**

```yaml
flutter:
  output: "./lib/generated"
  colors:
    output: "app_colors.dart"
    className: "AppColors"
  icons:
    output: "assets/icons"
    dartFile: "app_icons.dart"
    className: "AppIcons"
  images:
    output: "assets/images"
    dartFile: "app_images.dart"
    className: "AppImages"
    format: png
    scales: [1, 2, 3]
    webpOptions:
      encoding: lossy
      quality: 90
```

**PKL:**

```pkl
flutter = new Flutter.FlutterConfig {
  output = "./lib/generated"

  colors = new Flutter.ColorsEntry {
    output = "app_colors.dart"
    className = "AppColors"
  }

  icons = new Flutter.IconsEntry {
    output = "assets/icons"
    dartFile = "app_icons.dart"
    className = "AppIcons"
  }

  images = new Flutter.ImagesEntry {
    output = "assets/images"
    dartFile = "app_images.dart"
    className = "AppImages"
    format = "png"
    scales = new Listing { 1; 2; 3 }
    // WebP options (uncomment if format = "webp")
    // webpOptions = new Common.WebpOptions {
    //   encoding = "lossy"
    //   quality = 90
    // }
  }
}
```

Note: `webpOptions` uses the `Common.WebpOptions` type, which is already available in all platform schemas.

### 7. Migrate the Web section

**YAML:**

```yaml
web:
  output: "./src/generated"
  colors:
    cssFile: "theme.css"
    tsFile: "variables.ts"
    jsonFile: "tokens.json"
  icons:
    assetsDirectory: "assets/icons"
    generateReactComponents: true
    iconSize: 24
  images:
    assetsDirectory: "assets/images"
    generateReactComponents: true
```

**PKL:**

```pkl
web = new Web.WebConfig {
  output = "./src/generated"

  colors = new Web.ColorsEntry {
    cssFileName = "theme.css"
    tsFileName = "variables.ts"
    jsonFileName = "tokens.json"
  }

  icons = new Web.IconsEntry {
    outputDirectory = "./src/icons"
    svgDirectory = "assets/icons"
    generateReactComponents = true
    iconSize = 24
  }

  images = new Web.ImagesEntry {
    outputDirectory = "./src/images"
    assetsDirectory = "assets/images"
    generateReactComponents = true
  }
}
```

Property name changes for Web:

- `cssFile` is now `cssFileName`
- `tsFile` is now `tsFileName`
- `jsonFile` is now `jsonFileName`
- Icons: `assetsDirectory` is now split into `outputDirectory` (for components) and `svgDirectory` (for raw SVG files)
- Images: requires `outputDirectory` for components, `assetsDirectory` for assets

## Multi-Entry Configs

YAML array format maps to PKL `Listing`. Each entry gets an explicit type.

**YAML (multiple colors):**

```yaml
ios:
  colors:
    - tokensFileId: abc123
      tokensCollectionName: Base Palette
      lightModeName: Light
      darkModeName: Dark
      useColorAssets: true
      assetsFolder: BaseColors
      nameStyle: camelCase
      colorSwift: "./Generated/BaseColors.swift"
    - tokensFileId: def456
      tokensCollectionName: Theme Colors
      lightModeName: Light
      useColorAssets: true
      assetsFolder: ThemeColors
      nameStyle: camelCase
      colorSwift: "./Generated/ThemeColors.swift"
```

**PKL:**

```pkl
ios = new iOS.iOSConfig {
  // ... other iOS config ...

  colors = new Listing {
    new iOS.ColorsEntry {
      tokensFileId = "abc123"
      tokensCollectionName = "Base Palette"
      lightModeName = "Light"
      darkModeName = "Dark"
      useColorAssets = true
      assetsFolder = "BaseColors"
      nameStyle = "camelCase"
      colorSwift = "./Generated/BaseColors.swift"
    }
    new iOS.ColorsEntry {
      tokensFileId = "def456"
      tokensCollectionName = "Theme Colors"
      lightModeName = "Light"
      useColorAssets = true
      assetsFolder = "ThemeColors"
      nameStyle = "camelCase"
      colorSwift = "./Generated/ThemeColors.swift"
    }
  }
}
```

The same pattern applies to multiple icons and images entries on any platform.

**YAML (multiple icons):**

```yaml
android:
  icons:
    - figmaFrameName: Actions
      output: "drawable-actions"
      composePackageName: "com.example.icons.actions"
    - figmaFrameName: Navigation
      output: "drawable-nav"
      composeFormat: imageVector
```

**PKL:**

```pkl
android = new Android.AndroidConfig {
  // ... other Android config ...

  icons = new Listing {
    new Android.IconsEntry {
      figmaFrameName = "Actions"
      output = "drawable-actions"
      composePackageName = "com.example.icons.actions"
    }
    new Android.IconsEntry {
      figmaFrameName = "Navigation"
      output = "drawable-nav"
      composeFormat = "imageVector"
    }
  }
}
```

## Config Inheritance with `amends`

PKL lets you create a base config and extend it for different projects. This is new functionality not available in YAML.

**base.pkl** -- shared Figma tokens and common settings:

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
  }
  icons = new Common.Icons {
    figmaFrameName = "Icons/24"
  }
}
```

**project-a.pkl** -- inherits from base, adds iOS-specific config:

```pkl
amends "base.pkl"

import ".exfig/schemas/iOS.pkl"

ios = new iOS.iOSConfig {
  xcodeprojPath = "ProjectA.xcodeproj"
  target = "ProjectA"
  xcassetsPath = "ProjectA/Assets.xcassets"
  xcassetsInMainBundle = true

  colors = new iOS.ColorsEntry {
    // Source comes from common.variablesColors (inherited from base.pkl)
    useColorAssets = true
    assetsFolder = "Colors"
    nameStyle = "camelCase"
    colorSwift = "ProjectA/Generated/UIColor+Colors.swift"
  }

  icons = new iOS.IconsEntry {
    // figmaFrameName comes from common.icons (inherited from base.pkl)
    format = "pdf"
    assetsFolder = "Icons"
    nameStyle = "camelCase"
  }
}
```

Run with: `exfig colors -i project-a.pkl`

## DRY Configs with `for`-Generators

PKL is a programmable language — you can use `for`-generators to eliminate entry duplication. This is especially
useful when you have many icon or image categories with identical settings except for the Figma frame name and output
folder.

**Before** — 34 nearly identical entries (~380 lines):

```pkl
icons = new Listing {
  new iOS.IconsEntry {
    figmaFrameName = "Actions"
    format = "svg"
    xcassetsPath = "./Resources/Icons.xcassets"
    assetsFolder = "Actions"
    imageSwift = "./Generated/ActionsIcons.generated.swift"
  }
  new iOS.IconsEntry {
    figmaFrameName = "Chart"
    format = "svg"
    xcassetsPath = "./Resources/Icons.xcassets"
    assetsFolder = "Chart"
    imageSwift = "./Generated/ChartIcons.generated.swift"
  }
  // ... 32 more identical entries
}
```

**After** — `local` Mapping + `for`-generator (~30 lines):

```pkl
// local properties are NOT included in the output
local iconCategories: Mapping<String, String> = new {
  ["Actions"] = "Actions"
  ["Chart"] = "Chart"
  ["Communication, Media, Art"] = "CommunicationMediaArt"
  ["Text editor"] = "TextEditor"
  // ...
}

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

Key points:

- `local` properties exist only during evaluation — they don't appear in the JSON output
- `\(expr)` is PKL string interpolation for building paths from data
- You can mix manual entries and `for`-generators in the same `Listing`
- Use multiple Mappings for groups with different settings (e.g., template vs. colored icons)
- Always verify with `pkl eval --format json` that the output is unchanged after refactoring

## Validation

Validate your PKL config at any time:

```bash
pkl eval --format json exfig.pkl
```

If there are no errors, the config is valid. The JSON output shows the fully resolved configuration with all defaults applied. This is useful for debugging what ExFig will actually receive.

For quick syntax checks without full output:

```bash
pkl eval exfig.pkl > /dev/null
```

## Common Errors

| Error                                           | Cause                           | Fix                                                  |
| ----------------------------------------------- | ------------------------------- | ---------------------------------------------------- |
| `Cannot find module ".exfig/schemas/ExFig.pkl"` | Schema files not extracted      | Run `exfig schemas` to create `.exfig/schemas/`      |
| `Expected type String, got Int`                 | Wrong value type for a property | Check the schema -- string values must be quoted     |
| `Unknown property "xxx"`                        | Typo in property name           | Use IDE completion or check the schema file          |
| `Expected value of type "lossy"\|"lossless"`    | Invalid enum value              | PKL enforces exact enum values defined in the schema |
| `Property "lightFileId" is not set`             | Missing required property       | Add the required property to your config             |
| `Cannot find module "base.pkl"`                 | Relative amends path is wrong   | Verify the path to the base config file              |

## Property Name Changes

A few properties were renamed between YAML and PKL for consistency:

| YAML       | PKL            | Platform |
| ---------- | -------------- | -------- |
| `cssFile`  | `cssFileName`  | Web      |
| `tsFile`   | `tsFileName`   | Web      |
| `jsonFile` | `jsonFileName` | Web      |

All other property names remain the same.

## Breaking Changes in PKL-Native Config (v2)

The following changes apply after the internal migration to pkl-swift generated types:

### 1. Entry fields are always arrays

All platform entries (`colors`, `icons`, `images`) use `Listing` (array) format. Single-entry configs must still wrap the entry in a `Listing`:

```pkl
// Correct — even for a single entry
colors = new Listing {
  new iOS.ColorsEntry { ... }
}

// Also correct — PKL shorthand for single element
colors = new iOS.ColorsEntry { ... }
```

### 2. Colors validation at export time

`tokensFileId`, `tokensCollectionName`, and `lightModeName` are now validated at export time. If these fields are missing and `common.variablesColors` is not set, export will fail with a clear error message instead of silently sending empty strings to the Figma API.

### 3. New naming styles

Two new naming styles are now supported:

- `"flatCase"` — all lowercase with no separator: `myimagename`
- `"kebab-case"` — lowercase with hyphens: `my-image-name`

```pkl
nameStyle = "flatCase"
nameStyle = "kebab-case"
```

### 4. Android/Web Images nameStyle

`nameStyle` is now configurable for Android and Web images entries (previously hardcoded to `snake_case`):

```pkl
// Android
images = new Android.ImagesEntry {
  output = "figma-import-images"
  format = "webp"
  nameStyle = "camelCase"  // optional, defaults to snake_case
}

// Web
images = new Web.ImagesEntry {
  outputDirectory = "./src/images"
  nameStyle = "kebab-case"  // optional, defaults to snake_case
}
```

### 5. Typography per-entry fileId and regex

iOS and Android typography now support per-entry `fileId`, `nameValidateRegexp`, and `nameReplaceRegexp`. This allows using a different Figma file for typography than the main file:

```pkl
typography = new iOS.Typography {
  fileId = "typography-specific-file-id"  // overrides figma.lightFileId
  nameValidateRegexp = "^[a-zA-Z0-9/]+$"
  nameReplaceRegexp = "$1"
  nameStyle = "camelCase"
  fontSwift = "./Generated/UIFont+Typography.swift"
  generateLabels = false
}
```

## Breaking Changes in PKL v2

### HEIC Quality Format

The `heicOptions.quality` field is now `Int (0-100)` instead of `Double (0.0-1.0)`.

**Before (YAML):**

```yaml
ios:
  images:
    heicOptions:
      quality: 0.8
```

**After (PKL):**

```pkl
images = new iOS.ImagesEntry {
  outputFormat = "heic"
  heicOptions = new iOS.HeicOptions {
    encoding = "lossy"
    quality = 80
  }
}
```

### HEIC Encoding Field

The `heicOptions.encoding` field is now supported and bridged to the converter. Previously it was ignored. Valid values: `"lossy"` (default) and `"lossless"`.

### Entry-Level Path and File Overrides

Each entry can now override platform-level paths (`xcassetsPath`, `mainRes`, `templatesPath`) and use a separate Figma file (`figmaFileId`). When set, the entry value takes priority; when omitted, the platform config value is used.

| Platform | Available Entry Overrides                            |
| -------- | ---------------------------------------------------- |
| iOS      | `figmaFileId`, `xcassetsPath`, `templatesPath`       |
| Android  | `figmaFileId`, `mainRes`, `mainSrc`, `templatesPath` |
| Flutter  | `figmaFileId`, `templatesPath`                       |
| Web      | `figmaFileId`, `templatesPath`                       |

```pkl
ios = new iOS.iOSConfig {
  xcassetsPath = "MyApp/Assets.xcassets"  // platform default

  icons = new Listing {
    // Uses platform xcassetsPath
    new iOS.IconsEntry {
      format = "pdf"
      assetsFolder = "Icons"
      nameStyle = "camelCase"
    }
    // Overrides xcassetsPath + uses separate Figma file
    new iOS.IconsEntry {
      figmaFileId = "brand-icons-file"
      format = "svg"
      assetsFolder = "BrandIcons"
      nameStyle = "camelCase"
      xcassetsPath = "BrandKit/Assets.xcassets"
    }
  }
}
```

### PKL Schema Constraints

PKL schemas now include validation constraints that catch errors during `pkl eval`:

- **String constraints**: Required fields like `xcodeprojPath`, `target`, `mainRes`, `output`, `themeName` reject empty strings
- **Numeric constraints**: `timeout` must be between 1 and 600

```bash
# This will fail with a clear error
pkl eval --format json exfig-with-empty-target.pkl
# Error: expected value to not be empty
```

### Default Values in Schemas

Many fields now have PKL-level defaults. You can omit them from your config:

| Field                    | Default               |
| ------------------------ | --------------------- |
| `Cache.enabled`          | `false`               |
| `Cache.path`             | `".exfig-cache.json"` |
| `FigmaConfig.timeout`    | `30`                  |
| iOS `nameStyle`          | `"camelCase"`         |
| iOS `IconsEntry.format`  | `"pdf"`               |
| iOS `ImagesEntry.scales` | `[1, 2, 3]`           |
| Android `scales`         | `[1, 1.5, 2, 3, 4]`   |
| Flutter `scales`         | `[1, 2, 3]`           |

See the PKL schema files for the complete list of defaults.

## Consolidating Multiple Configs

If you have separate config files for different resource types (e.g., `colors.pkl`, `icons.pkl`, `images.pkl`), you can
consolidate them into a single unified `exfig.pkl`. This simplifies maintenance and allows using `exfig batch` for
one-command exports.

### Before: Multiple Files

```
configs/
├── colors.pkl           # Colors only
├── icons.pkl            # Icons only
└── images.pkl           # Images only
```

```bash
# Required 3 separate commands
exfig colors -i configs/colors.pkl
exfig icons -i configs/icons.pkl
exfig images -i configs/images.pkl
```

### After: Single Unified Config

```
exfig.pkl                # All resource types in one file
```

```bash
# One command exports everything
exfig batch exfig.pkl
```

### Migration Steps

1. Create a new unified `exfig.pkl` with all sections (`figma`, `common`, `ios`/`android`/`flutter`/`web`)
2. Copy each entry from separate configs into the appropriate `Listing` in the unified config
3. Use per-entry overrides (`xcassetsPath`, `templatesPath`, `figmaFileId`) to preserve unique paths
4. Validate with `pkl eval --format json exfig.pkl`
5. Test with `exfig batch exfig.pkl --dry-run` (if supported) or run actual export
6. Delete old config files

### Per-Entry Overrides

Each entry can override platform-level settings. This is essential when consolidating configs that had different paths:

```pkl
ios = new iOS.iOSConfig {
  xcassetsPath = "./Resources/Assets.xcassets"  // default

  icons = new Listing {
    // Entry 1: Uses default xcassetsPath
    new iOS.IconsEntry {
      figmaFrameName = "Actions"
      assetsFolder = "Icons/Actions"
      // ...
    }
    // Entry 2: Overrides xcassetsPath
    new iOS.IconsEntry {
      figmaFrameName = "Brand Icons"
      xcassetsPath = "./BrandKit/Assets.xcassets"  // override!
      assetsFolder = "BrandIcons"
      // ...
    }
    // Entry 3: Uses different Figma file
    new iOS.IconsEntry {
      figmaFileId = "separate-icons-file-id"       // override!
      figmaFrameName = "Special Icons"
      assetsFolder = "SpecialIcons"
      // ...
    }
  }
}
```

Available per-entry overrides:

| Platform | Entry Overrides                                      |
| -------- | ---------------------------------------------------- |
| iOS      | `figmaFileId`, `xcassetsPath`, `templatesPath`       |
| Android  | `figmaFileId`, `mainRes`, `mainSrc`, `templatesPath` |
| Flutter  | `figmaFileId`, `templatesPath`                       |
| Web      | `figmaFileId`, `templatesPath`                       |

## Breaking: Pkl 0.31+ Required (v2.7.0)

ExFig now requires **Pkl 0.31+** (previously 0.30.x). The PKL schemas use `isNotEmpty` / `isNotBlank` constraint builtins introduced in Pkl 0.31 — older versions will fail with a parse error during config evaluation.

**How to upgrade:**

- **mise (recommended):** Automatic — `mise.toml` pins `pkl = "0.31.0"`, no action needed
- **Homebrew:** `brew upgrade pkl`
- **Manual:** Download from [pkl-lang.org/main/current/pkl-cli/index.html](https://pkl-lang.org/main/current/pkl-cli/index.html#installation)

Verify: `pkl --version` should show `0.31.0` or higher.

**What changed internally:**

- pkl-swift upgraded from 0.7.2 to 0.8.0 (new `registerPklTypes` API for faster type resolution)
- Codegen switched from removed `pkl-gen-swift` binary to `pkl run @pkl.swift/gen.pkl`
- PKL schemas use `isNotEmpty` instead of `!isEmpty` for constraint validation

**Impact on consumer configs:** None — `.pkl` config files are fully compatible. Only the Pkl CLI version requirement changed.

## Cleanup

After successful migration:

1. Delete the old YAML config: `rm exfig.yaml` (or `figma-export.yaml`)
2. Add `.exfig/` to `.gitignore` (schemas are extracted locally by `exfig schemas`)
3. Commit `exfig.pkl`

```bash
echo ".exfig/" >> .gitignore
git add exfig.pkl .gitignore
git rm exfig.yaml
git commit -m "chore: migrate config from YAML to PKL"
```
