# iOS Icons Export

Export vector icons from Figma to Xcode Image Sets as PDF or SVG with Swift extensions.

@Metadata {
    @PageImage(purpose: icon, source: "icons-icon", alt: "iOS icons export")
    @PageColor(blue)
    @TitleHeading("Platform Guide")
}

## Overview

ExFig exports icons as:

- **PDF or SVG** files in Image Sets with vector preservation
- **Swift extensions** for UIImage (UIKit) and Image (SwiftUI)

## Configuration

```pkl
import ".exfig/schemas/iOS.pkl"

ios = new iOS.iOSConfig {
  xcodeprojPath = "./MyApp.xcodeproj"
  target = "MyApp"
  xcassetsPath = "./Resources/Assets.xcassets"

  icons = new iOS.IconsEntry {
    // Folder name in Assets.xcassets
    assetsFolder = "Icons"

    // Naming style: camelCase, snake_case, PascalCase, kebab-case, SCREAMING_SNAKE_CASE
    nameStyle = "camelCase"

    // Icon format: pdf or svg
    format = "pdf"

    // Preserve vector data for scaling
    preservesVectorRepresentation = new Listing {
      "ic24TabBarMain"
      "ic24TabBarEvents"
    }

    // Swift file paths (optional)
    imageSwift = "./Sources/Generated/UIImage+Icons.swift"
    swiftUIImageSwift = "./Sources/Generated/Image+Icons.swift"
  }
}
```

## Export Process

### 1. Design in Figma

Create icon components in a frame named "Icons":

```
Icons frame
├── ic/24/arrow-right     (component)
├── ic/24/arrow-left      (component)
├── ic/16/close           (component)
├── ic/16/check           (component)
└── ic/32/menu            (component)
```

**Important:** Icons must be components, not plain frames.

### 2. Run Export Command

```bash
# Export all icons
exfig icons

# Export specific icons
exfig icons "ic/24/arrow-right"

# Export icons matching pattern
exfig icons "ic/24/*"
```

### 3. Generated Output

**Assets.xcassets/Icons/**

```
Icons/
├── ic24ArrowRight.imageset/
│   ├── ic24ArrowRight.pdf
│   └── Contents.json
├── ic24ArrowLeft.imageset/
│   ├── ic24ArrowLeft.pdf
│   └── Contents.json
└── ic16Close.imageset/
    ├── ic16Close.pdf
    └── Contents.json
```

**Contents.json example:**

```json
{
  "images": [
    {
      "filename": "ic24ArrowRight.pdf",
      "idiom": "universal"
    }
  ],
  "info": {
    "version": 1,
    "author": "xcode"
  },
  "properties": {
    "preserves-vector-representation": true,
    "template-rendering-intent": "template"
  }
}
```

## Generated Code

### UIKit Extension

```swift
import UIKit

extension UIImage {
    static var ic24ArrowRight: UIImage {
        UIImage(named: "ic24ArrowRight")!
    }
    static var ic24ArrowLeft: UIImage {
        UIImage(named: "ic24ArrowLeft")!
    }
    static var ic16Close: UIImage {
        UIImage(named: "ic16Close")!
    }
}
```

### SwiftUI Extension

```swift
import SwiftUI

extension Image {
    static var ic24ArrowRight: Image {
        Image("ic24ArrowRight")
    }
    static var ic24ArrowLeft: Image {
        Image("ic24ArrowLeft")
    }
    static var ic16Close: Image {
        Image("ic16Close")
    }
}
```

## Usage in Code

### UIKit

```swift
// Navigation bar
navigationItem.rightBarButtonItem = UIBarButtonItem(
    image: .ic24ArrowRight,
    style: .plain,
    target: self,
    action: #selector(nextTapped)
)

// Buttons
button.setImage(.ic16Close, for: .normal)
button.tintColor = .textPrimary

// Tab bar
tabBarItem.image = .ic24Home
tabBarItem.selectedImage = .ic24HomeFilled

// Table cells
cell.accessoryView = UIImageView(image: .ic24ArrowRight)
```

### SwiftUI

```swift
struct ContentView: View {
    var body: some View {
        NavigationView {
            List {
                Label {
                    Text("Settings")
                } icon: {
                    Image.ic24Settings
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { }) {
                        Image.ic24ArrowRight
                    }
                }
            }
        }
    }
}

// With template rendering
Image.ic24Close
    .renderingMode(.template)
    .foregroundColor(.primary)
```

## PDF vs SVG Format

### PDF (Recommended)

```pkl
ios = new iOS.iOSConfig {
  icons = new iOS.IconsEntry {
    format = "pdf"
  }
}
```

**Advantages:**

- Native Xcode support
- Better compatibility with older iOS versions
- Consistent rendering across devices

### SVG

```pkl
ios = new iOS.iOSConfig {
  icons = new iOS.IconsEntry {
    format = "svg"
  }
}
```

**Advantages:**

- Smaller file size
- Native SVG support (iOS 13+)
- Easier to edit

## Rendering Mode

### Template

```pkl
ios = new iOS.iOSConfig {
  icons = new iOS.IconsEntry {
    renderMode = "template"
  }
}
```

Icons are tinted with the current tint color. Best for monochrome UI icons.

### Original

```pkl
ios = new iOS.iOSConfig {
  icons = new iOS.IconsEntry {
    renderMode = "original"
  }
}
```

Icons preserve their original colors. Use for colored icons or logos.

## Dark Mode Icons

### Separate Files

```pkl
import ".exfig/schemas/Figma.pkl"

figma = new Figma.FigmaConfig {
  lightFileId = "abc123"
  darkFileId = "def456"
}
```

Create matching icon components in both files.

### Single File Mode

```pkl
import ".exfig/schemas/Common.pkl"

common = new Common.CommonConfig {
  icons = new Common.Icons {
    suffixDarkMode = new Common.SuffixDarkMode { suffix = "_dark" }
  }
}
```

Name dark variants with suffix:

```
Icons frame
├── ic/24/logo
└── ic/24/logo_dark
```

## See Also

- <doc:iOS>
- <doc:DesignRequirements>
- <doc:Configuration>
