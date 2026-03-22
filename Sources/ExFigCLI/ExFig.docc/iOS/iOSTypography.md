# iOS Typography Export

Export text styles from Figma to Swift font extensions.

@Metadata {
    @PageImage(purpose: icon, source: "typography-icon", alt: "iOS typography export")
    @PageColor(blue)
    @TitleHeading("Platform Guide")
}

## Overview

ExFig exports typography as:

- **UIFont extensions** for UIKit
- **Font extensions** for SwiftUI
- **Optional label styles** for quick styling

## Configuration

```pkl
import ".exfig/schemas/iOS.pkl"

ios = new iOS.iOSConfig {
  typography = new iOS.Typography {
    // Generate label styling extensions
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

## Export Process

### 1. Design in Figma

Create text styles in a frame or as document styles:

```
Typography
├── heading/h1
├── heading/h2
├── heading/h3
├── body/regular
├── body/bold
├── caption/regular
└── caption/small
```

### 2. Run Export Command

```bash
# Export all typography
exfig typography

# Export specific styles
exfig typography "heading/*"
```

### 3. Generated Output

## Generated Code

### UIFont Extension

```swift
import UIKit

extension UIFont {
    static func headingH1() -> UIFont {
        UIFont.systemFont(ofSize: 32, weight: .bold)
    }

    static func headingH2() -> UIFont {
        UIFont.systemFont(ofSize: 24, weight: .bold)
    }

    static func bodyRegular() -> UIFont {
        UIFont.systemFont(ofSize: 16, weight: .regular)
    }

    static func bodyBold() -> UIFont {
        UIFont.systemFont(ofSize: 16, weight: .bold)
    }

    static func captionRegular() -> UIFont {
        UIFont.systemFont(ofSize: 12, weight: .regular)
    }
}
```

### SwiftUI Font Extension

```swift
import SwiftUI

extension Font {
    static var headingH1: Font {
        .system(size: 32, weight: .bold)
    }

    static var headingH2: Font {
        .system(size: 24, weight: .bold)
    }

    static var bodyRegular: Font {
        .system(size: 16, weight: .regular)
    }

    static var bodyBold: Font {
        .system(size: 16, weight: .bold)
    }

    static var captionRegular: Font {
        .system(size: 12, weight: .regular)
    }
}
```

### Label Style Extension (Optional)

```swift
import UIKit

extension UILabel {
    func applyHeadingH1Style() {
        font = .headingH1()
        // Additional styling from Figma
    }

    func applyBodyRegularStyle() {
        font = .bodyRegular()
    }
}
```

## Usage in Code

### UIKit

```swift
// Direct font usage
titleLabel.font = .headingH1()
bodyLabel.font = .bodyRegular()

// With label styles
titleLabel.applyHeadingH1Style()
bodyLabel.applyBodyRegularStyle()

// Attributed strings
let attributes: [NSAttributedString.Key: Any] = [
    .font: UIFont.headingH2()
]
```

### SwiftUI

```swift
struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome")
                .font(.headingH1)

            Text("This is body text with regular weight.")
                .font(.bodyRegular)

            Text("Small caption")
                .font(.captionRegular)
                .foregroundColor(.secondary)
        }
    }
}
```

## Custom Fonts

### Font Mapping

Map Figma fonts to iOS fonts using custom templates. See <doc:CustomTemplates> for details.

### Custom Font Files

If using custom fonts:

1. Add font files to your Xcode project
2. Register fonts in Info.plist:

```xml
<key>UIAppFonts</key>
<array>
    <string>Inter-Regular.ttf</string>
    <string>Inter-Bold.ttf</string>
</array>
```

### Generated Code with Custom Fonts

```swift
extension UIFont {
    static func headingH1() -> UIFont {
        UIFont(name: "Inter-Bold", size: 32) ?? .systemFont(ofSize: 32, weight: .bold)
    }

    static func bodyRegular() -> UIFont {
        UIFont(name: "Inter-Regular", size: 16) ?? .systemFont(ofSize: 16, weight: .regular)
    }
}
```

## Typography Properties

ExFig extracts the following properties from Figma:

| Property       | Description         | Swift Equivalent         |
| -------------- | ------------------- | ------------------------ |
| Font family    | Font name           | Font name or system font |
| Font weight    | Regular, Bold, etc. | UIFont.Weight            |
| Font size      | Size in points      | CGFloat size             |
| Line height    | Line spacing        | lineHeightMultiple       |
| Letter spacing | Character spacing   | kern attribute           |

## Tips

1. **Use system fonts**: Better accessibility and Dynamic Type support
2. **Define all weights**: Include regular, medium, bold variants
3. **Consider Dynamic Type**: Design for accessibility
4. **Test on devices**: Font rendering varies between devices
5. **Include fallbacks**: Always provide system font fallbacks

## See Also

- <doc:iOS>
- <doc:DesignRequirements>
- <doc:Configuration>
