# iOS Images Export

Export raster images from Figma to Xcode Image Sets as PNG or HEIC files with multiple scales.

@Metadata {
    @PageImage(purpose: icon, source: "images-icon", alt: "iOS images export")
    @PageColor(blue)
    @TitleHeading("Platform Guide")
}

## Overview

ExFig exports images as:

- **PNG files** at multiple scales (@1x, @2x, @3x) - default
- **HEIC files** for ~40-50% smaller file sizes (macOS only)
- **Multi-idiom support** (iPhone, iPad, Mac)
- **Dark Mode variants**
- **Swift extensions** for UIImage (UIKit) and Image (SwiftUI)

## Configuration

```pkl
import ".exfig/schemas/iOS.pkl"

ios = new iOS.iOSConfig {
  xcodeprojPath = "./MyApp.xcodeproj"
  target = "MyApp"
  xcassetsPath = "./Resources/Assets.xcassets"

  images = new iOS.ImagesEntry {
    // Folder name in Assets.xcassets
    assetsFolder = "Illustrations"

    // Naming style: camelCase, snake_case, PascalCase, kebab-case, SCREAMING_SNAKE_CASE
    nameStyle = "camelCase"

    // Image scales to export (optional, defaults to [1, 2, 3])
    scales = new Listing { 1; 2; 3 }

    // Swift file paths (optional)
    imageSwift = "./Sources/Generated/UIImage+Images.swift"
    swiftUIImageSwift = "./Sources/Generated/Image+Images.swift"
  }
}
```

## Export Process

### 1. Design in Figma

Create image components in a frame named "Illustrations":

```
Illustrations frame
├── img-empty-state       (component)
├── img-onboarding-1      (component)
├── img-onboarding-2      (component)
├── img-logo~ipad         (component, iPad-specific)
└── img-background~mac    (component, Mac-specific)
```

**Important:** Images must be components, not plain frames.

### 2. Run Export Command

```bash
# Export all images
exfig images

# Export specific images
exfig images "img-empty-state"

# Export images matching pattern
exfig images "img-onboarding-*"
```

### 3. Generated Output

**Assets.xcassets/Illustrations/**

```
Illustrations/
├── imgEmptyState.imageset/
│   ├── imgEmptyState.png       # @1x
│   ├── imgEmptyState@2x.png    # @2x
│   ├── imgEmptyState@3x.png    # @3x
│   ├── imgEmptyState_dark.png  # @1x dark
│   ├── imgEmptyState_dark@2x.png
│   ├── imgEmptyState_dark@3x.png
│   └── Contents.json
├── imgLogo.imageset/
│   ├── imgLogo~iphone.png
│   ├── imgLogo~iphone@2x.png
│   ├── imgLogo~iphone@3x.png
│   ├── imgLogo~ipad.png        # iPad variant
│   ├── imgLogo~ipad@2x.png
│   └── Contents.json
```

## Generated Code

### UIKit Extension

```swift
import UIKit

extension UIImage {
    static var imgEmptyState: UIImage {
        UIImage(named: "imgEmptyState")!
    }
    static var imgOnboarding1: UIImage {
        UIImage(named: "imgOnboarding1")!
    }
    static var imgLogo: UIImage {
        UIImage(named: "imgLogo")!
    }
}
```

### SwiftUI Extension

```swift
import SwiftUI

extension Image {
    static var imgEmptyState: Image {
        Image("imgEmptyState")
    }
    static var imgOnboarding1: Image {
        Image("imgOnboarding1")
    }
    static var imgLogo: Image {
        Image("imgLogo")
    }
}
```

## Usage in Code

### UIKit

```swift
// Simple usage
let imageView = UIImageView(image: .imgEmptyState)

// With content mode
let logoView = UIImageView(image: .imgLogo)
logoView.contentMode = .scaleAspectFit

// Button image
button.setImage(.imgOnboarding1, for: .normal)
```

### SwiftUI

```swift
struct ContentView: View {
    var body: some View {
        VStack {
            // Simple image
            Image.imgEmptyState

            // Resizable image
            Image.imgLogo
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 100)

            // Background
            ZStack {
                Image.imgBackground
                    .resizable()
                    .ignoresSafeArea()

                Text("Content")
            }
        }
    }
}
```

## HEIC Output Format

HEIC (High Efficiency Image Container) offers ~40-50% smaller file sizes compared to PNG while maintaining visual quality.

### Configuration

```pkl
ios = new iOS.iOSConfig {
  images = new iOS.ImagesEntry {
    outputFormat = "heic"
  }
}
```

### Encoding Options

| Encoding   | Quality | File Size | Use Case                          |
| ---------- | ------- | --------- | --------------------------------- |
| `lossy`    | 90      | Smallest  | Photos, complex illustrations     |
| `lossy`    | 100     | Small     | High-quality photos               |
| `lossless` | N/A     | Medium    | Near-lossless quality*            |

\*Apple ImageIO does not support true lossless HEIC. The `lossless` option
uses quality=1.0 (maximum) but is still technically lossy. For pixel-perfect
output, use PNG format instead.

### Platform Availability

HEIC encoding requires macOS 10.13.4 or later. On Linux or older macOS:
- ExFig shows a warning and automatically falls back to PNG
- No configuration changes needed

### With SVG Source

HEIC works with both PNG source (default) and SVG source:

```pkl
ios = new iOS.iOSConfig {
  images = new iOS.ImagesEntry {
    sourceFormat = "svg"    // Fetch SVG, rasterize locally
    outputFormat = "heic"   // Encode as HEIC
  }
}
```

## Image Scales

Configure which scales to export:

```pkl
ios = new iOS.iOSConfig {
  images = new iOS.ImagesEntry {
    scales = new Listing { 1; 2; 3 }  // @1x, @2x, @3x
  }
}
```

**Scale options:**

| Scale | Description     | Use Case                |
| ----- | --------------- | ----------------------- |
| 1     | @1x (base)      | Non-Retina displays     |
| 2     | @2x (Retina)    | iPhone 4-8, most iPads  |
| 3     | @3x (Retina HD) | iPhone 6 Plus and later |

**Recommendations:**

- **All apps**: `[2, 3]` at minimum
- **Supporting non-Retina**: `[1, 2, 3]`
- **App size optimization**: `[2, 3]` only

## Multi-Idiom Support

Export device-specific variants using suffixes:

### iPad-Specific

```
Figma: img-logo~ipad
Swift: UIImage.imgLogo
```

### Mac-Specific

```
Figma: img-sidebar~mac
Swift: UIImage.imgSidebar
```

### iPhone-Specific

```
Figma: img-splash~iphone
Swift: UIImage.imgSplash
```

### Combining Idioms

Create separate components for each idiom:

```
Illustrations frame
├── img-hero~iphone
├── img-hero~ipad
└── img-hero~mac
```

ExFig combines these into a single Image Set with all variants.

## Dark Mode Images

### Separate Files

```pkl
import ".exfig/schemas/Figma.pkl"

figma = new Figma.FigmaConfig {
  lightFileId = "abc123"
  darkFileId = "def456"
}
```

Create matching components in both files.

### Single File Mode

```pkl
import ".exfig/schemas/Common.pkl"

common = new Common.CommonConfig {
  images = new Common.Images {
    useSingleFile = true
    darkModeSuffix = "_dark"
  }
}
```

**Figma naming:**

```
img-empty-state
img-empty-state_dark
```

## Tips and Best Practices

1. **Use consistent naming**: Follow a prefix pattern (e.g., `img-`)
2. **Design at 3x**: Create at highest resolution, ExFig scales down
3. **Provide dark variants**: Better UX in dark mode
4. **Use idiom suffixes**: For device-specific designs
5. **Optimize file sizes**: Use HEIC format for ~40-50% smaller files
6. **Consider vectors**: For simple graphics, use Icons instead
7. **Use HEIC for photos**: Best compression for photographic content
8. **Post-export optimization**: For PNG, use oxipng for further compression:
   ```bash
   oxipng -o max -Z ./Resources/Assets.xcassets/**/*.png
   ```

## See Also

- <doc:iOS>
- <doc:iOSIcons>
- <doc:DesignRequirements>
