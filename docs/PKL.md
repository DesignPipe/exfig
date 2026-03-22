# PKL Configuration Guide

PKL (Programmable, Scalable, Safe) is ExFig's configuration language, replacing YAML in v2.0. PKL provides native configuration inheritance via `amends`, type safety, and IDE support.

## Installation

PKL CLI is required to run ExFig. Install via mise:

```bash
mise use pkl
```

Or manually from [pkl.dev](https://pkl.dev):

```bash
# macOS (Apple Silicon)
curl -L https://github.com/apple/pkl/releases/download/0.30.2/pkl-macos-aarch64.gz | gunzip > /usr/local/bin/pkl
chmod +x /usr/local/bin/pkl

# macOS (Intel)
curl -L https://github.com/apple/pkl/releases/download/0.30.2/pkl-macos-amd64.gz | gunzip > /usr/local/bin/pkl
chmod +x /usr/local/bin/pkl

# Linux
curl -L https://github.com/apple/pkl/releases/download/0.30.2/pkl-linux-amd64.gz | gunzip > /usr/local/bin/pkl
chmod +x /usr/local/bin/pkl
```

Verify installation:

```bash
pkl --version
```

## Basic Configuration

Create `exfig.pkl` in your project root:

```pkl
amends "package://github.com/DesignPipe/exfig@2.0.0#/ExFig.pkl"

import "package://github.com/DesignPipe/exfig@2.0.0#/Common.pkl"
import "package://github.com/DesignPipe/exfig@2.0.0#/iOS.pkl"

common = new Common.CommonConfig {
  variablesColors = new Common.VariablesColors {
    tokensFileId = "YOUR_FIGMA_FILE_ID"
    tokensCollectionName = "Design Tokens"
    lightModeName = "Light"
    darkModeName = "Dark"
  }
}

ios = new iOS.iOSConfig {
  xcodeprojPath = "MyApp.xcodeproj"
  target = "MyApp"
  xcassetsPath = "MyApp/Resources/Assets.xcassets"
  xcassetsInMainBundle = true

  colors = new iOS.ColorsEntry {
    useColorAssets = true
    assetsFolder = "Colors"
    nameStyle = "camelCase"
    colorSwift = "MyApp/Generated/UIColor+Generated.swift"
    swiftuiColorSwift = "MyApp/Generated/Color+Generated.swift"
  }
}
```

Run ExFig:

```bash
exfig colors -i exfig.pkl
```

## Configuration Inheritance

PKL's `amends` keyword enables configuration inheritance. Create a base config that can be shared across projects:

### Base Configuration (base.pkl)

```pkl
amends "package://github.com/DesignPipe/exfig@2.0.0#/ExFig.pkl"

import "package://github.com/DesignPipe/exfig@2.0.0#/Common.pkl"
import "package://github.com/DesignPipe/exfig@2.0.0#/Figma.pkl"

figma = new Figma.FigmaConfig {
  lightFileId = "YOUR_DESIGN_SYSTEM_FILE"
  darkFileId = "YOUR_DESIGN_SYSTEM_DARK_FILE"
  timeout = 60
}

common = new Common.CommonConfig {
  cache = new Common.Cache {
    enabled = true
  }
  variablesColors = new Common.VariablesColors {
    tokensFileId = "YOUR_TOKENS_FILE"
    tokensCollectionName = "Design System"
    lightModeName = "Light"
    darkModeName = "Dark"
    lightHCModeName = "Light HC"
    darkHCModeName = "Dark HC"
  }
  icons = new Common.Icons {
    figmaFrameName = "Icons/24"
  }
  images = new Common.Images {
    figmaFrameName = "Illustrations"
  }
}
```

### Project Configuration (project-ios.pkl)

```pkl
amends "base.pkl"

import "package://github.com/DesignPipe/exfig@2.0.0#/iOS.pkl"

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
    swiftuiColorSwift = "ProjectA/Generated/Color+Colors.swift"
  }

  icons = new iOS.IconsEntry {
    // figmaFrameName comes from common.icons (inherited from base.pkl)
    format = "pdf"
    assetsFolder = "Icons"
    nameStyle = "camelCase"
    renderMode = "template"
  }
}
```

## Platform Configurations

### iOS

```pkl
ios = new iOS.iOSConfig {
  // Required
  xcodeprojPath = "MyApp.xcodeproj"    // Path to Xcode project
  target = "MyApp"                      // Xcode target name
  xcassetsPath = "MyApp/Assets.xcassets"
  xcassetsInMainBundle = true           // true if assets in main bundle

  // Optional
  xcassetsInSwiftPackage = false        // true if assets in SPM package
  resourceBundleNames = new Listing { "MyAppResources" }
  addObjcAttribute = false              // Add @objc to extensions
  templatesPath = "Templates/"          // Custom Stencil templates

  // Colors
  colors = new iOS.ColorsEntry {
    useColorAssets = true
    assetsFolder = "Colors"
    nameStyle = "camelCase"
    groupUsingNamespace = false
    colorSwift = "Generated/UIColor+Colors.swift"
    swiftuiColorSwift = "Generated/Color+Colors.swift"
    syncCodeSyntax = true
    codeSyntaxTemplate = "Color.{name}"
  }

  // Icons
  icons = new iOS.IconsEntry {
    figmaFrameName = "Icons"
    format = "pdf"                       // "pdf" | "svg"
    assetsFolder = "Icons"
    nameStyle = "camelCase"
    imageSwift = "Generated/UIImage+Icons.swift"
    swiftUIImageSwift = "Generated/Image+Icons.swift"
    codeConnectSwift = "Generated/Icons.figma.swift"
    renderMode = "template"              // "default" | "original" | "template"
    preservesVectorRepresentation = new Listing { "icon-chevron" }
  }

  // Images
  images = new iOS.ImagesEntry {
    figmaFrameName = "Illustrations"
    assetsFolder = "Images"
    nameStyle = "camelCase"
    scales = new Listing { 1; 2; 3 }
    sourceFormat = "svg"                 // "png" | "svg"
    outputFormat = "heic"                // "png" | "heic"
    heicOptions = new iOS.HeicOptions {
      encoding = "lossy"                 // "lossy" | "lossless"
      quality = 90
    }
    imageSwift = "Generated/UIImage+Images.swift"
    swiftUIImageSwift = "Generated/Image+Images.swift"
  }

  // Typography
  typography = new iOS.Typography {
    fontSwift = "Generated/UIFont+Styles.swift"
    swiftUIFontSwift = "Generated/Font+Styles.swift"
    labelStyleSwift = "Generated/LabelStyle.swift"
    nameStyle = "camelCase"
    generateLabels = true
    labelsDirectory = "Generated/Labels/"
  }
}
```

### Android

```pkl
android = new Android.AndroidConfig {
  // Required
  mainRes = "app/src/main/res"

  // Optional
  resourcePackage = "com.example.app"
  mainSrc = "app/src/main/kotlin"
  templatesPath = "Templates/"

  // Colors
  colors = new Android.ColorsEntry {
    xmlOutputFileName = "figma_colors.xml"
    xmlDisabled = false                  // Skip XML for Compose-only
    composePackageName = "com.example.app.ui.theme"
    colorKotlin = "app/src/main/kotlin/ui/theme/Colors.kt"
    themeAttributes = new Android.ThemeAttributes {
      enabled = true
      themeName = "Theme.MyApp"
      attrsFile = "values/attrs.xml"
      stylesFile = "values/styles.xml"
      stylesNightFile = "values-night/styles.xml"
      nameTransform = new Android.NameTransform {
        style = "PascalCase"
        prefix = "color"
        stripPrefixes = new Listing { "bg"; "text" }
      }
    }
  }

  // Icons
  icons = new Android.IconsEntry {
    figmaFrameName = "Icons"
    output = "app/src/main/res/drawable"
    composePackageName = "com.example.app.ui.icons"
    composeFormat = "imageVector"        // "resourceReference" | "imageVector"
    composeExtensionTarget = "AppIcons"
    nameStyle = "snake_case"
    pathPrecision = 4                    // 1-6, default 4
    strictPathValidation = true
  }

  // Images
  images = new Android.ImagesEntry {
    figmaFrameName = "Illustrations"
    output = "app/src/main/res/drawable"
    format = "webp"                      // "svg" | "png" | "webp"
    scales = new Listing { 1; 1.5; 2; 3; 4 }
    sourceFormat = "svg"
    webpOptions = new Android.WebpOptions {
      encoding = "lossy"
      quality = 85
    }
  }

  // Typography
  typography = new Android.Typography {
    nameStyle = "camelCase"
    composePackageName = "com.example.app.ui.theme"
  }
}
```

### Flutter

```pkl
flutter = new Flutter.FlutterConfig {
  // Required
  output = "lib/generated"

  // Optional
  templatesPath = "Templates/"

  // Colors
  colors = new Flutter.ColorsEntry {
    output = "lib/generated/colors.dart"
    className = "AppColors"
  }

  // Icons
  icons = new Flutter.IconsEntry {
    figmaFrameName = "Icons"
    output = "assets/icons"
    dartFile = "lib/generated/icons.dart"
    className = "AppIcons"
    nameStyle = "camelCase"
  }

  // Images
  images = new Flutter.ImagesEntry {
    figmaFrameName = "Illustrations"
    output = "assets/images"
    dartFile = "lib/generated/images.dart"
    className = "AppImages"
    scales = new Listing { 1; 2; 3 }
    format = "webp"                      // "svg" | "png" | "webp"
    sourceFormat = "svg"
    nameStyle = "camelCase"
  }
}
```

### Web

```pkl
web = new Web.WebConfig {
  // Required
  output = "src/generated"

  // Optional
  templatesPath = "Templates/"

  // Colors
  colors = new Web.ColorsEntry {
    outputDirectory = "src/generated/colors"
    cssFileName = "colors.css"
    tsFileName = "colors.ts"
    jsonFileName = "colors.json"
  }

  // Icons
  icons = new Web.IconsEntry {
    figmaFrameName = "Icons"
    outputDirectory = "src/generated/icons"
    svgDirectory = "public/icons"
    generateReactComponents = true
    iconSize = 24
    nameStyle = "PascalCase"
  }

  // Images
  images = new Web.ImagesEntry {
    figmaFrameName = "Illustrations"
    outputDirectory = "src/generated/images"
    assetsDirectory = "public/images"
    generateReactComponents = true
  }
}
```

## Multiple Entries

Each asset type supports multiple configurations for different sources or outputs:

```pkl
ios = new iOS.iOSConfig {
  xcodeprojPath = "MyApp.xcodeproj"
  target = "MyApp"
  xcassetsPath = "MyApp/Assets.xcassets"
  xcassetsInMainBundle = true

  // Multiple color sources
  colors = new Listing {
    new iOS.ColorsEntry {
      tokensFileId = "file1"
      tokensCollectionName = "Brand Colors"
      lightModeName = "Light"
      useColorAssets = true
      assetsFolder = "BrandColors"
      nameStyle = "camelCase"
      colorSwift = "Generated/UIColor+Brand.swift"
    }
    new iOS.ColorsEntry {
      tokensFileId = "file2"
      tokensCollectionName = "System Colors"
      lightModeName = "Light"
      useColorAssets = true
      assetsFolder = "SystemColors"
      nameStyle = "camelCase"
      colorSwift = "Generated/UIColor+System.swift"
    }
  }

  // Multiple icon frames
  icons = new Listing {
    new iOS.IconsEntry {
      figmaFrameName = "Icons/16"
      format = "pdf"
      assetsFolder = "Icons/Small"
      nameStyle = "camelCase"
    }
    new iOS.IconsEntry {
      figmaFrameName = "Icons/24"
      format = "pdf"
      assetsFolder = "Icons/Medium"
      nameStyle = "camelCase"
    }
  }
}
```

## Entry-Level Overrides

Each entry can override platform-level paths and even use a different Figma file. This is useful when different icon sets or image groups come from separate Figma files or need different output locations.

Available override fields per platform:

| Platform | Override Fields                                         |
| -------- | ------------------------------------------------------- |
| iOS      | `figmaFileId`, `xcassetsPath`, `templatesPath`          |
| Android  | `figmaFileId`, `mainRes`, `mainSrc`, `templatesPath`    |
| Flutter  | `figmaFileId`, `templatesPath`                          |
| Web      | `figmaFileId`, `templatesPath`                          |

When an override is set on an entry, it takes priority over the platform-level value. When not set, the platform config value is used as fallback.

```pkl
ios = new iOS.iOSConfig {
  xcodeprojPath = "MyApp.xcodeproj"
  target = "MyApp"
  xcassetsPath = "MyApp/Assets.xcassets"       // Platform default
  xcassetsInMainBundle = true

  icons = new Listing {
    // Uses platform xcassetsPath ("MyApp/Assets.xcassets")
    new iOS.IconsEntry {
      format = "pdf"
      assetsFolder = "Icons"
      nameStyle = "camelCase"
    }
    // Overrides xcassetsPath and uses a separate Figma file
    new iOS.IconsEntry {
      figmaFileId = "brand-icons-figma-file"
      figmaFrameName = "BrandIcons"
      format = "svg"
      assetsFolder = "BrandIcons"
      nameStyle = "camelCase"
      xcassetsPath = "BrandKit/Assets.xcassets"
      templatesPath = "BrandKit/Templates"
    }
  }
}
```

## Common Settings

Share settings across platforms using `common`:

```pkl
common = new Common.CommonConfig {
  // Version tracking cache
  cache = new Common.Cache {
    enabled = true
    path = ".exfig-cache.json"
  }

  // Shared color source for all platforms
  variablesColors = new Common.VariablesColors {
    tokensFileId = "YOUR_FILE_ID"
    tokensCollectionName = "Design Tokens"
    lightModeName = "Light"
    darkModeName = "Dark"
    lightHCModeName = "Light HC"
    darkHCModeName = "Dark HC"
    primitivesModeName = "Primitives"
  }

  // Shared icons settings
  icons = new Common.Icons {
    figmaFrameName = "Icons/24"
    useSingleFile = false
    darkModeSuffix = "-dark"
    strictPathValidation = true
  }

  // Shared images settings
  images = new Common.Images {
    figmaFrameName = "Illustrations"
    useSingleFile = false
    darkModeSuffix = "-dark"
  }

  // Name processing (applies to all)
  colors = new Common.Colors {
    nameValidateRegexp = "^[a-z][a-zA-Z0-9]*$"
    nameReplaceRegexp = "color-"
  }
}
```

## Figma Settings

Configure Figma API access:

```pkl
figma = new Figma.FigmaConfig {
  lightFileId = "ABC123"           // Light mode file
  darkFileId = "DEF456"            // Dark mode file (optional)
  lightHighContrastFileId = "GHI789"
  darkHighContrastFileId = "JKL012"
  timeout = 60                     // Request timeout in seconds
}
```

## Name Processing

Control how Figma names are transformed:

```pkl
colors = new iOS.ColorsEntry {
  // Validate names match pattern
  nameValidateRegexp = "^(bg|text|border)-.*$"

  // Replace parts of names
  nameReplaceRegexp = "^(bg|text|border)-"  // Strips prefix
}
```

### Name Styles

- `camelCase`: backgroundPrimary
- `PascalCase`: BackgroundPrimary
- `snake_case`: background_primary
- `SCREAMING_SNAKE_CASE`: BACKGROUND_PRIMARY
- `flatCase`: backgroundprimary

## Validation

Validate your config without running export:

```bash
pkl eval exfig.pkl
```

Check for type errors:

```bash
pkl eval --format json exfig.pkl | jq .
```

## IDE Support

### VS Code

Install the [PKL extension](https://marketplace.visualstudio.com/items?itemName=apple.pkl-vscode) for:

- Syntax highlighting
- Type checking
- Auto-completion
- Go to definition

### IntelliJ IDEA

Install the PKL plugin from JetBrains Marketplace.

## Environment Variables

Use PKL's read function for environment variables:

```pkl
common = new Common.CommonConfig {
  variablesColors = new Common.VariablesColors {
    tokensFileId = read("env:FIGMA_TOKENS_FILE_ID")
    // ...
  }
}
```

**Note:** `FIGMA_PERSONAL_TOKEN` is read from environment by ExFig CLI, not from PKL config.

## Troubleshooting

### "pkl: command not found"

Install PKL via mise:

```bash
mise use pkl
```

### "Cannot find module"

Ensure the package URL is correct and accessible:

```pkl
// Correct
amends "package://github.com/DesignPipe/exfig@2.0.0#/ExFig.pkl"

// Wrong (missing package://)
amends "github.com/DesignPipe/exfig@2.0.0#/ExFig.pkl"
```

### Type errors

Check field names and types match the schema. Use IDE with PKL extension for real-time validation.

## Resources

- [PKL Documentation](https://pkl-lang.org/main/current/index.html)
- [PKL Language Reference](https://pkl-lang.org/main/current/language-reference/index.html)
- [ExFig Schema Reference](https://github.com/DesignPipe/exfig/tree/main/Sources/ExFigCLI/Resources/Schemas)
