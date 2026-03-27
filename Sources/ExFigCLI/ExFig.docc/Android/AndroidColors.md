# Android Colors Export

Export color palettes from Figma to Android XML resources and Jetpack Compose code.

@Metadata {
    @PageImage(purpose: icon, source: "colors-icon", alt: "Android colors export")
    @PageColor(green)
    @TitleHeading("Platform Guide")
}

## Overview

ExFig exports colors as:

- **XML resources** in `colors.xml` with light/dark variants
- **Kotlin constants** for Jetpack Compose

## Configuration

```pkl
import ".exfig/schemas/Android.pkl"

android = new Android.AndroidConfig {
  mainRes = "./app/src/main/res"
  mainSrc = "./app/src/main/java"
  resourcePackage = "com.example.app"

  colors = new Android.ColorsEntry {
    // Output filename
    xmlOutputFileName = "colors.xml"

    // Jetpack Compose package name (optional)
    composePackageName = "com.example.app.ui.theme"

    // Custom output path for Colors.kt file (optional)
    // When set, overrides the automatic path computed from mainSrc + composePackageName
    colorKotlin = "./app/src/main/java/com/example/app/ui/theme/Ds3Colors.kt"
  }
}
```

## Export Process

### 1. Design in Figma

Create color styles in a frame named "Colors":

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

**res/values/colors.xml**

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="primary">#FF007AFF</color>
    <color name="secondary">#FF5856D6</color>
    <color name="text_primary">#FF000000</color>
    <color name="text_secondary">#FF666666</color>
    <color name="background_primary">#FFFFFFFF</color>
    <color name="background_secondary">#FFF5F5F5</color>
</resources>
```

**res/values-night/colors.xml**

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="primary">#FF0A84FF</color>
    <color name="secondary">#FF5E5CE6</color>
    <color name="text_primary">#FFFFFFFF</color>
    <color name="text_secondary">#FF999999</color>
    <color name="background_primary">#FF000000</color>
    <color name="background_secondary">#FF1C1C1E</color>
</resources>
```

## Generated Compose Code

**Colors.kt**

```kotlin
package com.example.app.ui.theme

import androidx.compose.ui.graphics.Color

object AppColors {
    val Primary = Color(0xFF007AFF)
    val Secondary = Color(0xFF5856D6)
    val TextPrimary = Color(0xFF000000)
    val TextSecondary = Color(0xFF666666)
    val BackgroundPrimary = Color(0xFFFFFFFF)
    val BackgroundSecondary = Color(0xFFF5F5F5)
}

object AppColorsDark {
    val Primary = Color(0xFF0A84FF)
    val Secondary = Color(0xFF5E5CE6)
    val TextPrimary = Color(0xFFFFFFFF)
    val TextSecondary = Color(0xFF999999)
    val BackgroundPrimary = Color(0xFF000000)
    val BackgroundSecondary = Color(0xFF1C1C1E)
}
```

## Usage in Code

### XML Views

```xml
<TextView
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:text="Hello"
    android:textColor="@color/text_primary"
    android:background="@color/background_primary"/>

<Button
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:backgroundTint="@color/primary"
    android:textColor="@android:color/white"/>
```

### Kotlin Views

```kotlin
// XML resources
textView.setTextColor(ContextCompat.getColor(context, R.color.text_primary))
view.setBackgroundColor(ContextCompat.getColor(context, R.color.background_primary))
```

### Jetpack Compose

```kotlin
@Composable
fun MyScreen() {
    val colors = if (isSystemInDarkTheme()) AppColorsDark else AppColors

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.BackgroundPrimary)
    ) {
        Text(
            text = "Hello",
            color = colors.TextPrimary
        )

        Button(
            onClick = { },
            colors = ButtonDefaults.buttonColors(
                containerColor = colors.Primary
            )
        ) {
            Text("Action")
        }
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

ExFig creates:

- `res/values/colors.xml` - Light mode colors
- `res/values-night/colors.xml` - Dark mode colors

### Single File Mode

```pkl
import ".exfig/schemas/Common.pkl"

common = new Common.CommonConfig {
  colors = new Common.Colors {
    suffixDarkMode = new Common.SuffixDarkMode { suffix = "_dark" }
  }
}
```

Figma naming:

```
primary
primary_dark
```

## Color Format

Android colors use ARGB format:

- `#AARRGGBB` - Full format with alpha
- `#RRGGBB` - Without alpha (defaults to FF)

ExFig automatically converts Figma colors (RGBA) to Android format (ARGB).

## See Also

- <doc:Android>
- <doc:DesignRequirements>
- <doc:Configuration>
