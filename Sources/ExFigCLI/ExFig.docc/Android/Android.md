# Android Export

Export Figma resources to Android projects with XML resources and Jetpack Compose code.

@Metadata {
    @PageImage(purpose: icon, source: "android-icon", alt: "Android platform")
    @PageColor(green)
    @TitleHeading("Platform Guide")
}

## Overview

ExFig exports design resources from Figma to Android projects:

- **Colors**: XML color resources and Compose Color constants
- **Icons**: VectorDrawable XML files and Compose Icon composables
- **Images**: Multi-density PNG/WebP images
- **Typography**: XML text styles and Compose Typography definitions

## Quick Start

### 1. Generate Configuration

```bash
exfig init --platform android
```

### 2. Configure Your Project

Edit `exfig.pkl`:

```pkl
amends ".exfig/schemas/ExFig.pkl"

import ".exfig/schemas/Figma.pkl"
import ".exfig/schemas/Android.pkl"

figma = new Figma.FigmaConfig {
  lightFileId = "YOUR_FILE_ID"
  darkFileId = "YOUR_DARK_FILE_ID"  // Optional
}

android = new Android.AndroidConfig {
  mainRes = "./app/src/main/res"
  mainSrc = "./app/src/main/java"
  resourcePackage = "com.example.app"

  colors = new Android.ColorsEntry {
    xmlOutputFileName = "colors.xml"
    composePackageName = "com.example.app.ui.theme"
  }

  icons = new Android.IconsEntry {
    output = "exfig-icons"
    composePackageName = "com.example.app.ui.icons"
  }

  images = new Android.ImagesEntry {
    output = "exfig-images"
    format = "webp"
    scales = new Listing { 1; 1.5; 2; 3; 4 }
  }

  typography = new Android.Typography {
    nameStyle = "camelCase"
    composePackageName = "com.example.app.ui.theme"
  }
}
```

### 3. Configure build.gradle

Add generated resource directories:

```gradle
android {
    sourceSets {
        main {
            res.srcDirs += "src/main/res/exfig-icons"
            res.srcDirs += "src/main/res/exfig-images"
        }
    }
}
```

### 4. Export Resources

```bash
exfig colors
exfig icons
exfig images
exfig typography
```

## Generated Output

### Colors

**res/values/colors.xml**

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="primary">#FF007AFF</color>
    <color name="secondary">#FF5856D6</color>
    <color name="background_primary">#FFFFFFFF</color>
    <color name="text_primary">#FF000000</color>
</resources>
```

**res/values-night/colors.xml**

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="primary">#FF0A84FF</color>
    <color name="secondary">#FF5E5CE6</color>
    <color name="background_primary">#FF000000</color>
    <color name="text_primary">#FFFFFFFF</color>
</resources>
```

**Colors.kt (Compose)**

```kotlin
package com.example.app.ui.theme

import androidx.compose.ui.graphics.Color

object AppColors {
    val Primary = Color(0xFF007AFF)
    val Secondary = Color(0xFF5856D6)
    val BackgroundPrimary = Color(0xFFFFFFFF)
    val TextPrimary = Color(0xFF000000)
}

object AppColorsDark {
    val Primary = Color(0xFF0A84FF)
    val Secondary = Color(0xFF5E5CE6)
    val BackgroundPrimary = Color(0xFF000000)
    val TextPrimary = Color(0xFFFFFFFF)
}
```

### Icons

**exfig-icons/drawable/ic_arrow_right.xml**

```xml
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#000000"
        android:pathData="M8,4 L16,12 L8,20"/>
</vector>
```

### Images

```
exfig-images/
├── drawable-mdpi/
│   └── img_hero.webp        # @1x (160 dpi)
├── drawable-hdpi/
│   └── img_hero.webp        # @1.5x (240 dpi)
├── drawable-xhdpi/
│   └── img_hero.webp        # @2x (320 dpi)
├── drawable-xxhdpi/
│   └── img_hero.webp        # @3x (480 dpi)
└── drawable-xxxhdpi/
    └── img_hero.webp        # @4x (640 dpi)
```

## Usage in Code

### XML Views

```xml
<!-- Colors -->
<TextView
    android:textColor="@color/text_primary"
    android:background="@color/background_primary"/>

<!-- Icons -->
<ImageView
    android:src="@drawable/ic_arrow_right"
    android:tint="@color/primary"/>

<!-- Images -->
<ImageView
    android:src="@drawable/img_hero"
    android:scaleType="centerCrop"/>
```

### Jetpack Compose

```kotlin
@Composable
fun MyScreen() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.BackgroundPrimary)
    ) {
        Text(
            text = "Hello",
            color = AppColors.TextPrimary,
            style = AppTypography.HeadingH1
        )

        Icon(
            painter = painterResource(R.drawable.ic_arrow_right),
            contentDescription = null,
            tint = AppColors.Primary
        )

        Image(
            painter = painterResource(R.drawable.img_hero),
            contentDescription = null,
            contentScale = ContentScale.Crop
        )
    }
}
```

## Topics

### Resources

@Links(visualStyle: compactGrid) {
    - <doc:AndroidColors>
    - <doc:AndroidIcons>
    - <doc:AndroidImages>
    - <doc:AndroidTypography>
}

## See Also

- <doc:Configuration>
- <doc:DesignRequirements>
