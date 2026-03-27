# Android Images Export

Export raster images from Figma to Android drawable resources in PNG or WebP format.

@Metadata {
    @PageImage(purpose: icon, source: "images-icon", alt: "Android images export")
    @PageColor(green)
    @TitleHeading("Platform Guide")
}

## Overview

ExFig exports images as:

- **PNG or WebP** files with multiple density variants
- **VectorDrawable** for SVG-compatible images
- **Multiple densities**: mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi

## Configuration

```pkl
import ".exfig/schemas/Android.pkl"

android = new Android.AndroidConfig {
  mainRes = "./app/src/main/res"

  images = new Android.ImagesEntry {
    // Output directory (relative to mainRes)
    output = "exfig-images"

    // Image format: png or webp
    format = "webp"

    // Density scales (default: [1, 1.5, 2, 3, 4])
    scales = new Listing { 1; 1.5; 2; 3; 4 }

    // WebP options (for webp format only)
    webpOptions = new Common.WebpOptions {
      encoding = "lossy"
      quality = 90
    }
  }
}
```

**Important:** Add to `build.gradle`:

```gradle
android {
    sourceSets {
        main {
            res.srcDirs += "src/main/res/exfig-images"
        }
    }
}
```

## Export Process

### 1. Design in Figma

Create image components in a frame:

```
Images frame
├── img-hero           (component)
├── img-splash         (component)
├── img-background     (component)
└── img-onboarding     (component)
```

### 2. Run Export Command

```bash
exfig images
```

### 3. Generated Output

```
exfig-images/
├── drawable/
│   └── img_logo.xml                # Vector (if applicable)
├── drawable-night/
│   └── img_logo.xml                # Dark vector
├── drawable-mdpi/
│   ├── img_splash.webp             # @1x (160 dpi)
│   └── img_background.webp
├── drawable-hdpi/
│   ├── img_splash.webp             # @1.5x (240 dpi)
│   └── img_background.webp
├── drawable-xhdpi/
│   ├── img_splash.webp             # @2x (320 dpi)
│   └── img_background.webp
├── drawable-xxhdpi/
│   ├── img_splash.webp             # @3x (480 dpi)
│   └── img_background.webp
└── drawable-xxxhdpi/
    ├── img_splash.webp             # @4x (640 dpi)
    └── img_background.webp
```

## Density Mapping

| Scale | Density | DPI | Use Case          |
| ----- | ------- | --- | ----------------- |
| 1     | mdpi    | 160 | Low-res devices   |
| 1.5   | hdpi    | 240 | Medium-res        |
| 2     | xhdpi   | 320 | High-res (common) |
| 3     | xxhdpi  | 480 | Extra high-res    |
| 4     | xxxhdpi | 640 | Highest density   |

Configure scales:

```pkl
android = new Android.AndroidConfig {
  images = new Android.ImagesEntry {
    scales = new Listing { 2; 3; 4 }  // Skip mdpi and hdpi
  }
}
```

## Usage in Code

### XML Views

```xml
<ImageView
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:src="@drawable/img_splash"
    android:scaleType="centerCrop"/>

<ImageView
    android:layout_width="200dp"
    android:layout_height="200dp"
    android:src="@drawable/img_logo"
    android:scaleType="fitCenter"/>
```

### Jetpack Compose

```kotlin
@Composable
fun MyScreen() {
    Image(
        painter = painterResource(id = R.drawable.img_splash),
        contentDescription = "Splash",
        modifier = Modifier.fillMaxWidth(),
        contentScale = ContentScale.Crop
    )

    Image(
        painter = painterResource(id = R.drawable.img_logo),
        contentDescription = "Logo",
        modifier = Modifier.size(200.dp)
    )
}
```

## WebP vs PNG

### WebP (Recommended)

```pkl
android = new Android.AndroidConfig {
  images = new Android.ImagesEntry {
    format = "webp"
    webpOptions = new Common.WebpOptions {
      encoding = "lossy"
      quality = 90
    }
  }
}
```

**Advantages:**

- 25-35% smaller than PNG
- Supported on Android 4.0+
- Lossy and lossless compression

**Encoding options:**

- **Lossy**: Better compression, slight quality loss
- **Lossless**: Perfect quality, larger files

### PNG

```pkl
android = new Android.AndroidConfig {
  images = new Android.ImagesEntry {
    format = "png"
  }
}
```

**Advantages:**

- Universal format
- Lossless compression

## Dark Mode Images

### Separate Files

```pkl
import ".exfig/schemas/Figma.pkl"

figma = new Figma.FigmaConfig {
  lightFileId = "abc123"
  darkFileId = "def456"
}
```

Generated structure:

```
drawable-mdpi/
  img_hero.webp           # Light mode
drawable-night-mdpi/
  img_hero.webp           # Dark mode
```

### Single File Mode

```pkl
import ".exfig/schemas/Common.pkl"

common = new Common.CommonConfig {
  images = new Common.Images {
    suffixDarkMode = new Common.SuffixDarkMode { suffix = "_dark" }
  }
}
```

Figma naming:

```
img-hero
img-hero_dark
```

## Tips

1. **Use WebP** for smaller APK size
2. **Skip low densities**: Use `scales: new Listing { 2; 3; 4 }` for modern devices
3. **Use vectors** for simple graphics instead of rasters
4. **Compress in Figma** before export
5. **Provide dark mode** variants for better UX
6. **Post-export optimization** for PNG format:
   ```bash
   oxipng -o max -Z ./app/src/main/res/exfig-images/**/*.png
   ```

## Troubleshooting

### WebP conversion failed

- Check if source PNG is corrupted
- Verify disk space
- Try PNG format as fallback

### Images are low quality

- Increase WebP quality: `quality = 95`
- Use lossless encoding
- Check source resolution in Figma

### App size too large

- Use lossy WebP with quality 80-90
- Remove unnecessary density variants
- Compress images in Figma

## See Also

- <doc:Android>
- <doc:AndroidIcons>
- <doc:DesignRequirements>
