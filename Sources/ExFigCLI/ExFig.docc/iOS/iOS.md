# iOS Export

Export Figma resources to Xcode projects with Assets catalogs and Swift extensions.

@Metadata {
    @PageImage(purpose: icon, source: "ios-icon", alt: "iOS platform")
    @PageColor(blue)
    @TitleHeading("Platform Guide")
}

## Overview

ExFig exports design resources from Figma to iOS projects:

- **Colors**: Color Sets in Assets.xcassets with UIColor/Color extensions
- **Icons**: PDF or SVG icons in Image Sets with UIImage/Image extensions
- **Images**: Multi-scale PNG or HEIC images with UIImage/Image extensions
- **Typography**: UIFont/Font extensions with text style configurations

## Quick Start

### 1. Generate Configuration

```bash
exfig init --platform ios
```

### 2. Configure Your Project

Edit `exfig.pkl`:

```pkl
amends ".exfig/schemas/ExFig.pkl"

import ".exfig/schemas/Figma.pkl"
import ".exfig/schemas/iOS.pkl"

figma = new Figma.FigmaConfig {
  lightFileId = "YOUR_FILE_ID"
  darkFileId = "YOUR_DARK_FILE_ID"  // Optional
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
    swiftUIImageSwift = "./Sources/Image+Icons.swift"
  }

  images = new iOS.ImagesEntry {
    assetsFolder = "Images"
    scales = new Listing { 1; 2; 3 }
    imageSwift = "./Sources/UIImage+Images.swift"
  }

  typography = new iOS.Typography {
    fontSwift = "./Sources/UIFont+Typography.swift"
    swiftUIFontSwift = "./Sources/Font+Typography.swift"
  }
}
```

### 3. Export Resources

```bash
exfig colors
exfig icons
exfig images
exfig typography
```

## Generated Output

### Colors

**Assets.xcassets/Colors/**

```
Colors/
├── primary.colorset/
│   └── Contents.json
├── secondary.colorset/
│   └── Contents.json
└── background/
    ├── primary.colorset/
    └── secondary.colorset/
```

**UIColor+Colors.swift**

```swift
import UIKit

extension UIColor {
    static var primary: UIColor {
        UIColor(named: "primary")!
    }
    static var backgroundPrimary: UIColor {
        UIColor(named: "background/primary")!
    }
}
```

**Color+Colors.swift**

```swift
import SwiftUI

extension Color {
    static var primary: Color {
        Color("primary")
    }
    static var backgroundPrimary: Color {
        Color("background/primary")
    }
}
```

### Icons

**Assets.xcassets/Icons/**

```
Icons/
├── icArrowRight.imageset/
│   ├── icArrowRight.pdf
│   └── Contents.json
└── icClose.imageset/
    ├── icClose.pdf
    └── Contents.json
```

### Images

**Assets.xcassets/Images/**

```
Images/
├── imgHero.imageset/
│   ├── imgHero.png       # @1x
│   ├── imgHero@2x.png    # @2x
│   ├── imgHero@3x.png    # @3x
│   └── Contents.json
```

## Usage in Code

### UIKit

```swift
// Colors
view.backgroundColor = .primary
label.textColor = .textPrimary

// Icons
let icon = UIImage.icArrowRight
button.setImage(.icClose, for: .normal)

// Images
imageView.image = .imgHero

// Typography
label.font = .bodyRegular()
titleLabel.font = .headingH1()
```

### SwiftUI

```swift
struct ContentView: View {
    var body: some View {
        VStack {
            // Colors
            Rectangle()
                .fill(Color.primary)

            // Icons
            Image.icArrowRight
                .renderingMode(.template)
                .foregroundColor(.textPrimary)

            // Images
            Image.imgHero
                .resizable()
                .aspectRatio(contentMode: .fit)

            // Typography
            Text("Hello")
                .font(.bodyRegular)
        }
    }
}
```

## Topics

### Resources

@Links(visualStyle: compactGrid) {
    - <doc:iOSColors>
    - <doc:iOSIcons>
    - <doc:iOSImages>
    - <doc:iOSTypography>
}

## See Also

- <doc:Configuration>
- <doc:DesignRequirements>
