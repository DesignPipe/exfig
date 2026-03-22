# iOS Colors Export

Export color palettes from Figma to Xcode Color Sets with Swift extensions.

@Metadata {
    @PageImage(purpose: icon, source: "colors-icon", alt: "iOS colors export")
    @PageColor(blue)
    @TitleHeading("Platform Guide")
}

## Overview

ExFig exports colors as:

- **Color Sets** in Assets.xcassets with light/dark appearance variants
- **Swift extensions** for UIColor (UIKit) and Color (SwiftUI)

## Configuration

```pkl
import ".exfig/schemas/iOS.pkl"

ios = new iOS.iOSConfig {
  xcodeprojPath = "./MyApp.xcodeproj"
  target = "MyApp"
  xcassetsPath = "./Resources/Assets.xcassets"

  colors = new iOS.ColorsEntry {
    // Folder name in Assets.xcassets
    assetsFolder = "Colors"

    // Naming style: camelCase, snake_case, PascalCase, kebab-case, SCREAMING_SNAKE_CASE
    nameStyle = "camelCase"

    // Group colors in subfolders by prefix (e.g., text/primary -> text/primary.colorset)
    groupUsingNamespace = true

    // Swift file paths (optional)
    colorSwift = "./Sources/Generated/UIColor+Colors.swift"
    swiftuiColorSwift = "./Sources/Generated/Color+Colors.swift"
  }
}
```

## Export Process

### 1. Design in Figma

Create color styles or variables in a frame named "Colors":

```
Colors frame
├── primary
├── secondary
├── text/primary
├── text/secondary
├── background/primary
└── background/secondary
```

### 2. Run Export Command

```bash
# Export all colors
exfig colors

# Export specific colors
exfig colors "primary"

# Export colors matching pattern
exfig colors "text/*"
```

### 3. Generated Output

**Assets.xcassets/Colors/**

```
Colors/
├── primary.colorset/
│   └── Contents.json
├── secondary.colorset/
│   └── Contents.json
└── text/
    ├── primary.colorset/
    │   └── Contents.json
    └── secondary.colorset/
        └── Contents.json
```

**Contents.json example:**

```json
{
  "colors": [
    {
      "color": {
        "color-space": "srgb",
        "components": {
          "red": "0.000",
          "green": "0.478",
          "blue": "1.000",
          "alpha": "1.000"
        }
      },
      "idiom": "universal",
      "appearances": [
        { "appearance": "luminosity", "value": "light" }
      ]
    },
    {
      "color": {
        "color-space": "srgb",
        "components": {
          "red": "0.039",
          "green": "0.518",
          "blue": "1.000",
          "alpha": "1.000"
        }
      },
      "idiom": "universal",
      "appearances": [
        { "appearance": "luminosity", "value": "dark" }
      ]
    }
  ],
  "info": { "version": 1, "author": "xcode" }
}
```

## Generated Code

### UIKit Extension

```swift
import UIKit

extension UIColor {
    static var primary: UIColor {
        UIColor(named: "primary")!
    }
    static var secondary: UIColor {
        UIColor(named: "secondary")!
    }
    static var textPrimary: UIColor {
        UIColor(named: "text/primary")!
    }
    static var backgroundPrimary: UIColor {
        UIColor(named: "background/primary")!
    }
}
```

### SwiftUI Extension

```swift
import SwiftUI

extension Color {
    static var primary: Color {
        Color("primary")
    }
    static var secondary: Color {
        Color("secondary")
    }
    static var textPrimary: Color {
        Color("text/primary")
    }
    static var backgroundPrimary: Color {
        Color("background/primary")
    }
}
```

## Usage in Code

### UIKit

```swift
// View backgrounds
view.backgroundColor = .backgroundPrimary

// Text colors
label.textColor = .textPrimary

// Button colors
button.tintColor = .primary

// Layer colors
layer.borderColor = UIColor.secondary.cgColor
```

### SwiftUI

```swift
struct ContentView: View {
    var body: some View {
        VStack {
            Text("Hello")
                .foregroundColor(.textPrimary)

            Rectangle()
                .fill(Color.primary)

            Button("Action") { }
                .buttonStyle(.borderedProminent)
                .tint(.primary)
        }
        .background(Color.backgroundPrimary)
    }
}
```

## Dark Mode Support

### Separate Files

```pkl
import ".exfig/schemas/Figma.pkl"

figma = new Figma.FigmaConfig {
  lightFileId = "abc123"
  darkFileId = "def456"
}
```

Create matching color styles in both files. ExFig merges them into a single Color Set with light and dark appearances.

### Using Figma Variables

```pkl
import ".exfig/schemas/Common.pkl"

common = new Common.CommonConfig {
  variablesColors = new Common.VariablesColors {
    tokensFileId = "ABC123xyz"
    tokensCollectionName = "Colors"
    lightModeName = "Light"
    darkModeName = "Dark"
  }
}
```

## Color Grouping

When `groupUsingNamespace = true`, colors are organized in folders:

| Figma Name        | Asset Path                        | Swift Name       |
| ----------------- | --------------------------------- | ---------------- |
| `primary`         | `Colors/primary.colorset`         | `primary`        |
| `text/primary`    | `Colors/text/primary.colorset`    | `textPrimary`    |
| `background/card` | `Colors/background/card.colorset` | `backgroundCard` |

## Assets Folder Namespace

When `assetsFolderProvidesNamespace = true`, the assets folder itself gets `provides-namespace` in its
`Contents.json`. Colors are then accessed with the folder prefix:

```pkl
colors = new iOS.ColorsEntry {
  assetsFolder = "MyColors"
  assetsFolderProvidesNamespace = true
  // ...
}
```

| Figma Name | Asset Path                           | Swift Access                          |
| ---------- | ------------------------------------ | ------------------------------------- |
| `primary`  | `MyColors/primary.colorset`         | `UIColor(named: "MyColors/primary")` |
| `accent`   | `MyColors/accent.colorset`          | `Color("MyColors/accent")`           |

This is useful when multiple `.xcassets` share color names — the folder prefix disambiguates them.

> Note: `assetsFolder` is required when `assetsFolderProvidesNamespace = true`.

## See Also

- <doc:iOS>
- <doc:DesignRequirements>
- <doc:Configuration>
