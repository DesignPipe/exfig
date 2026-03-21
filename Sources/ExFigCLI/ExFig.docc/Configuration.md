# Configuration

Complete reference for exfig.pkl configuration options.

## Overview

ExFig uses a PKL configuration file (typically `exfig.pkl`) to define export settings. PKL (Programmable, Scalable, Safe)
provides type-safe configuration with IDE support. This document covers all available options.

## Configuration File

By default, ExFig looks for `exfig.pkl` in the current directory.

Specify a custom path with the `-i` flag:

```bash
exfig colors -i path/to/config.pkl
```

## Unified Config with Batch

A single `exfig.pkl` can contain all resource types. Use `batch` to export everything at once:

```bash
# Export all resource types from a single config
exfig batch exfig.pkl

# With version tracking
exfig batch exfig.pkl --cache
```

> Note: The `batch` command takes config paths as **positional arguments** (not via `-i` flag).

## Figma Section

```pkl
import ".exfig/schemas/Figma.pkl"

figma = new Figma.FigmaConfig {
  // Figma file ID for light mode assets.
  // Required for icons, images, and typography export.
  // Optional when using only variablesColors (or multi-entry colors) for colors export.
  lightFileId = "ABC123xyz"

  // Optional: Separate file for dark mode assets
  darkFileId = "DEF456abc"

  // Optional: API request timeout in seconds (default: 30)
  timeout = 60
}
```

## Common Section

Shared settings across all platforms.

### Colors

```pkl
import ".exfig/schemas/Common.pkl"

common = new Common.CommonConfig {
  colors = new Common.Colors {
    // Frame name containing color styles (default: null, uses all styles)
    figmaFrameName = "Colors"

    // Regex to validate color names
    nameValidateRegexp = "^[a-z][a-zA-Z0-9]*$"

    // Regex replacement for color names
    nameReplaceRegexp = "$1"

    // Extract light and dark mode colors from a single file
    useSingleFile = false

    // Suffix for dark mode variants (when useSingleFile is true)
    darkModeSuffix = "_dark"
  }
}
```

### Variables Colors

```pkl
import ".exfig/schemas/Common.pkl"

common = new Common.CommonConfig {
  // Use variablesColors instead of colors to export colors from Figma Variables.
  // Cannot be used together with colors.
  variablesColors = new Common.VariablesColors {
    // Identifier of the file containing variables
    tokensFileId = "ABC123xyz"

    // Variables collection name
    tokensCollectionName = "Colors"

    // Name of the column containing light color variables
    lightModeName = "Light"

    // Name of the column containing dark color variables
    darkModeName = "Dark"
  }
}
```

### Penpot Source

Use a Penpot project instead of Figma as the design source. For file preparation guidelines,
see <doc:DesignRequirements>.

**Colors:**

```pkl
import ".exfig/schemas/Common.pkl"
import ".exfig/schemas/iOS.pkl"

ios = new iOS.iOSConfig {
  colors = new iOS.ColorsEntry {
    penpotSource = new Common.PenpotSource {
      fileId = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
      // baseUrl = "https://penpot.mycompany.com/"  // optional: self-hosted
      pathFilter = "Brand"  // optional: filter by path prefix
    }
    assetsFolder = "Colors"
    nameStyle = "camelCase"
  }
}
```

**Typography:**

```pkl
ios = new iOS.iOSConfig {
  typography = new iOS.TypographyEntry {
    penpotSource = new Common.PenpotSource {
      fileId = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
    }
  }
}
```

> When `penpotSource` is set, `sourceKind` auto-detects as `"penpot"`. ExFig reads from
> the Penpot API and does not require `FIGMA_PERSONAL_TOKEN`. Set `PENPOT_ACCESS_TOKEN` instead.
>
> **v1 limitation:** Penpot icons/images are exported as raster thumbnails (the Penpot API has
> no public SVG/PNG render endpoint). SVG reconstruction from the shape tree is planned for a
> future version.

### Tokens File Source

Use a local W3C DTCG `.tokens.json` file instead of the Figma Variables API:

```pkl
import ".exfig/schemas/Common.pkl"
import ".exfig/schemas/iOS.pkl"

ios = new iOS.iOSConfig {
  colors = new iOS.ColorsEntry {
    // Load colors from a local .tokens.json file
    tokensFile = new Common.TokensFile {
      // Path to the .tokens.json file
      path = "./design-tokens/colors.tokens.json"

      // Optional: filter to specific token group
      groupFilter = "Brand.Colors"
    }

    assetsFolder = "Colors"
    nameStyle = "camelCase"
  }
}
```

> When `tokensFile` is set, ExFig reads color tokens from the local file and does not require `FIGMA_PERSONAL_TOKEN` or Figma Variables configuration (`tokensFileId`, `tokensCollectionName`, `lightModeName`).

### Icons

```pkl
import ".exfig/schemas/Common.pkl"

common = new Common.CommonConfig {
  icons = new Common.Icons {
    // Default frame name for icon components (can be overridden per-entry)
    figmaFrameName = "Icons"

    // Regex to validate icon names
    nameValidateRegexp = "^ic/.*$"

    // Regex replacement for icon names
    nameReplaceRegexp = "ic_$1"

    // Use single file for light/dark (default: false)
    useSingleFile = false

    // Suffix for dark mode variants (when useSingleFile is true)
    darkModeSuffix = "_dark"
  }
}
```

### Images

```pkl
import ".exfig/schemas/Common.pkl"

common = new Common.CommonConfig {
  images = new Common.Images {
    // Frame name containing image components
    figmaFrameName = "Illustrations"

    // Regex to validate image names
    nameValidateRegexp = "^img_.*$"

    // Regex replacement for image names
    nameReplaceRegexp = "$1"

    // Use single file for light/dark (default: false)
    useSingleFile = false

    // Suffix for dark mode variants (when useSingleFile is true)
    darkModeSuffix = "_dark"
  }
}
```

### Typography

```pkl
import ".exfig/schemas/Common.pkl"

common = new Common.CommonConfig {
  typography = new Common.Typography {
    // Regex to validate style names
    nameValidateRegexp = "^[a-z].*$"
  }
}
```

## iOS Section

```pkl
import ".exfig/schemas/iOS.pkl"

ios = new iOS.iOSConfig {
  // Path to Xcode project
  xcodeprojPath = "./MyApp.xcodeproj"

  // Target name for adding generated files
  target = "MyApp"

  // Path to Assets.xcassets
  xcassetsPath = "./Resources/Assets.xcassets"

  // Colors
  colors = new iOS.ColorsEntry {
    // Use color assets in xcassets
    useColorAssets = true

    // Folder in xcassets for colors
    assetsFolder = "Colors"

    // Naming style: camelCase, snake_case, PascalCase, kebab-case, SCREAMING_SNAKE_CASE
    nameStyle = "camelCase"

    // Group colors in subfolders by prefix
    groupUsingNamespace = true

    // UIKit extension output path
    colorSwift = "./Sources/Generated/UIColor+Colors.swift"

    // SwiftUI extension output path
    swiftuiColorSwift = "./Sources/Generated/Color+Colors.swift"
  }

  // Icons
  icons = new iOS.IconsEntry {
    // Folder in xcassets for icons
    assetsFolder = "Icons"

    // Naming style
    nameStyle = "camelCase"

    // Icon format: pdf or svg
    format = "pdf"

    // Preserve vector data
    preservesVectorRepresentation = new Listing {
      "ic24TabBarMain"
      "ic24TabBarEvents"
    }

    // UIKit extension output path
    imageSwift = "./Sources/Generated/UIImage+Icons.swift"

    // SwiftUI extension output path
    swiftUIImageSwift = "./Sources/Generated/Image+Icons.swift"
  }

  // Images
  images = new iOS.ImagesEntry {
    // Folder in xcassets for images
    assetsFolder = "Images"

    // Naming style
    nameStyle = "camelCase"

    // Scales to export (default: [1, 2, 3])
    scales = new Listing { 1; 2; 3 }

    // UIKit extension output path
    imageSwift = "./Sources/Generated/UIImage+Images.swift"

    // SwiftUI extension output path
    swiftUIImageSwift = "./Sources/Generated/Image+Images.swift"
  }

  // Typography
  typography = new iOS.Typography {
    // Generate labels with predefined styles
    generateLabels = true

    // Font extension output path
    fontSwift = "./Sources/Generated/UIFont+Typography.swift"

    // SwiftUI font extension output path
    swiftUIFontSwift = "./Sources/Generated/Font+Typography.swift"

    // UIKit label extension output path
    labelStyleSwift = "./Sources/Generated/UILabel+Typography.swift"

    // Typography name style
    nameStyle = "camelCase"
  }
}
```

## Android Section

```pkl
import ".exfig/schemas/Android.pkl"

android = new Android.AndroidConfig {
  // Path to main res directory
  mainRes = "./app/src/main/res"

  // Package for R class references
  resourcePackage = "com.example.app"

  // Path to main source directory (for Compose)
  mainSrc = "./app/src/main/java"

  // Colors
  colors = new Android.ColorsEntry {
    // Output filename
    xmlOutputFileName = "colors.xml"

    // Jetpack Compose package name
    composePackageName = "com.example.app.ui.theme"
  }

  // Icons
  icons = new Android.IconsEntry {
    // Output directory (relative to mainRes)
    output = "exfig-icons"

    // Jetpack Compose package name
    composePackageName = "com.example.app.ui.icons"
  }

  // Images
  images = new Android.ImagesEntry {
    // Output directory (relative to mainRes)
    output = "exfig-images"

    // Image format: svg, png, or webp
    format = "webp"

    // WebP encoding options
    webpOptions = new Common.WebpOptions {
      encoding = "lossy"
      quality = 90
    }

    // Density scales (default: [1, 1.5, 2, 3, 4])
    scales = new Listing { 1; 1.5; 2; 3; 4 }
  }

  // Typography
  typography = new Android.Typography {
    // Naming style
    nameStyle = "snake_case"

    // Jetpack Compose package name
    composePackageName = "com.example.app.ui.typography"
  }
}
```

## Flutter Section

```pkl
import ".exfig/schemas/Flutter.pkl"

flutter = new Flutter.FlutterConfig {
  // Output directory for generated Dart files
  output = "lib/generated"

  // Colors
  colors = new Flutter.ColorsEntry {
    // Output filename
    output = "colors.dart"

    // Class name for colors
    className = "AppColors"
  }

  // Icons
  icons = new Flutter.IconsEntry {
    // Output directory for SVG files
    output = "assets/icons"

    // Dart file output
    dartFile = "icons.dart"

    // Class name for icons
    className = "AppIcons"
  }

  // Images
  images = new Flutter.ImagesEntry {
    // Output directory for images
    output = "assets/images"

    // Dart file output
    dartFile = "images.dart"

    // Class name for images
    className = "AppImages"

    // Image format: svg, png, or webp
    format = "png"

    // Scales to export (default: [1, 2, 3])
    scales = new Listing { 1; 2; 3 }
  }
}
```

## Example Configurations

### iOS Project

```pkl
amends ".exfig/schemas/ExFig.pkl"

import ".exfig/schemas/Figma.pkl"
import ".exfig/schemas/Common.pkl"
import ".exfig/schemas/iOS.pkl"

figma = new Figma.FigmaConfig {
  lightFileId = "ABC123"
  darkFileId = "DEF456"
}

common = new Common.CommonConfig {
  colors = new Common.Colors {
    figmaFrameName = "Colors"
  }
  icons = new Common.Icons {
    figmaFrameName = "Icons"
  }
  images = new Common.Images {
    figmaFrameName = "Illustrations"
  }
}

ios = new iOS.iOSConfig {
  xcodeprojPath = "./MyApp.xcodeproj"
  target = "MyApp"
  xcassetsPath = "./Resources/Assets.xcassets"

  colors = new iOS.ColorsEntry {
    assetsFolder = "Colors"
    colorSwift = "./Sources/UIColor+Colors.swift"
    swiftuiColorSwift = "./Sources/Color+Colors.swift"
  }

  icons = new iOS.IconsEntry {
    assetsFolder = "Icons"
    format = "pdf"
    imageSwift = "./Sources/UIImage+Icons.swift"
  }
}
```

### Android Project

```pkl
amends ".exfig/schemas/ExFig.pkl"

import ".exfig/schemas/Figma.pkl"
import ".exfig/schemas/Common.pkl"
import ".exfig/schemas/Android.pkl"

figma = new Figma.FigmaConfig {
  lightFileId = "ABC123"
}

common = new Common.CommonConfig {
  icons = new Common.Icons {
    figmaFrameName = "Icons"
  }
}

android = new Android.AndroidConfig {
  mainRes = "./app/src/main/res"
  mainSrc = "./app/src/main/java"
  resourcePackage = "com.example.app"

  colors = new Android.ColorsEntry {
    xmlOutputFileName = "colors.xml"
    composePackageName = "com.example.app.ui"
  }

  icons = new Android.IconsEntry {
    output = "exfig-icons"
    composePackageName = "com.example.app.ui"
  }
}
```

### Multi-Platform Project

```pkl
amends ".exfig/schemas/ExFig.pkl"

import ".exfig/schemas/Figma.pkl"
import ".exfig/schemas/Common.pkl"
import ".exfig/schemas/iOS.pkl"
import ".exfig/schemas/Android.pkl"
import ".exfig/schemas/Flutter.pkl"

figma = new Figma.FigmaConfig {
  lightFileId = "ABC123"
  darkFileId = "DEF456"
}

common = new Common.CommonConfig {
  colors = new Common.Colors {
    figmaFrameName = "Colors"
  }
  icons = new Common.Icons {
    figmaFrameName = "Icons"
  }
  images = new Common.Images {
    figmaFrameName = "Images"
  }
}

ios = new iOS.iOSConfig {
  xcodeprojPath = "./ios/MyApp.xcodeproj"
  xcassetsPath = "./ios/Resources/Assets.xcassets"
  colors = new iOS.ColorsEntry {
    assetsFolder = "Colors"
  }
}

android = new Android.AndroidConfig {
  mainRes = "./android/app/src/main/res"
  colors = new Android.ColorsEntry {
    xmlOutputFileName = "colors.xml"
  }
}

flutter = new Flutter.FlutterConfig {
  output = "lib/generated"
  colors = new Flutter.ColorsEntry {
    output = "colors.dart"
  }
}
```

## See Also

- <doc:Usage>
- <doc:DesignRequirements>
