# Android Typography Export

Export text styles from Figma to Android XML resources and Jetpack Compose code.

@Metadata {
    @PageImage(purpose: icon, source: "typography-icon", alt: "Android typography export")
    @PageColor(green)
    @TitleHeading("Platform Guide")
}

## Overview

ExFig exports typography as:

- **XML text styles** in `typography.xml`
- **Kotlin Typography** definitions for Jetpack Compose

## Configuration

```pkl
import ".exfig/schemas/Android.pkl"

android = new Android.AndroidConfig {
  mainRes = "./app/src/main/res"
  mainSrc = "./app/src/main/java"
  resourcePackage = "com.example.app"

  typography = new Android.Typography {
    // Naming style
    nameStyle = "snake_case"

    // Jetpack Compose package name (optional)
    composePackageName = "com.example.app.ui.theme"
  }
}
```

## Export Process

### 1. Design in Figma

Create text styles:

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

**res/values/typography.xml**

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="TextAppearance.HeadingH1">
        <item name="android:fontFamily">sans-serif</item>
        <item name="android:textSize">32sp</item>
        <item name="android:textStyle">bold</item>
        <item name="android:letterSpacing">0</item>
        <item name="android:lineHeight">40sp</item>
    </style>

    <style name="TextAppearance.HeadingH2">
        <item name="android:fontFamily">sans-serif</item>
        <item name="android:textSize">24sp</item>
        <item name="android:textStyle">bold</item>
        <item name="android:letterSpacing">0</item>
        <item name="android:lineHeight">32sp</item>
    </style>

    <style name="TextAppearance.BodyRegular">
        <item name="android:fontFamily">sans-serif</item>
        <item name="android:textSize">16sp</item>
        <item name="android:textStyle">normal</item>
        <item name="android:letterSpacing">0</item>
        <item name="android:lineHeight">24sp</item>
    </style>

    <style name="TextAppearance.CaptionSmall">
        <item name="android:fontFamily">sans-serif</item>
        <item name="android:textSize">12sp</item>
        <item name="android:textStyle">normal</item>
        <item name="android:letterSpacing">0</item>
        <item name="android:lineHeight">16sp</item>
    </style>
</resources>
```

## Generated Compose Code

**Typography.kt**

```kotlin
package com.example.app.ui.theme

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

object AppTypography {
    val HeadingH1 = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.Bold,
        fontSize = 32.sp,
        lineHeight = 40.sp,
        letterSpacing = 0.sp
    )

    val HeadingH2 = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.Bold,
        fontSize = 24.sp,
        lineHeight = 32.sp,
        letterSpacing = 0.sp
    )

    val BodyRegular = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp,
        lineHeight = 24.sp,
        letterSpacing = 0.sp
    )

    val CaptionSmall = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.Normal,
        fontSize = 12.sp,
        lineHeight = 16.sp,
        letterSpacing = 0.sp
    )
}
```

## Usage in Code

### XML Views

```xml
<TextView
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:text="Welcome"
    android:textAppearance="@style/TextAppearance.HeadingH1"/>

<TextView
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:text="Body text"
    android:textAppearance="@style/TextAppearance.BodyRegular"/>

<TextView
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:text="Caption"
    android:textAppearance="@style/TextAppearance.CaptionSmall"/>
```

### Kotlin Views

```kotlin
textView.setTextAppearance(R.style.TextAppearance_HeadingH1)
```

### Jetpack Compose

```kotlin
@Composable
fun MyScreen() {
    Column {
        Text(
            text = "Welcome",
            style = AppTypography.HeadingH1
        )

        Text(
            text = "This is body text with regular styling.",
            style = AppTypography.BodyRegular
        )

        Text(
            text = "Small caption",
            style = AppTypography.CaptionSmall,
            color = AppColors.TextSecondary
        )
    }
}
```

## Custom Fonts

### Font Mapping

Map Figma fonts to Android fonts using custom templates. See <doc:CustomTemplates> for details.

### Using Custom Fonts

1. Add font files to `res/font/`:

```
res/font/
├── inter_regular.ttf
├── inter_medium.ttf
└── inter_bold.ttf
```

2. Create font family XML `res/font/inter.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<font-family xmlns:android="http://schemas.android.com/apk/res/android">
    <font
        android:fontStyle="normal"
        android:fontWeight="400"
        android:font="@font/inter_regular"/>
    <font
        android:fontStyle="normal"
        android:fontWeight="500"
        android:font="@font/inter_medium"/>
    <font
        android:fontStyle="normal"
        android:fontWeight="700"
        android:font="@font/inter_bold"/>
</font-family>
```

### Generated Output with Custom Fonts

**typography.xml:**

```xml
<style name="TextAppearance.HeadingH1">
    <item name="android:fontFamily">@font/inter</item>
    <item name="android:textSize">32sp</item>
    <item name="android:textStyle">bold</item>
</style>
```

**Typography.kt:**

```kotlin
val HeadingH1 = TextStyle(
    fontFamily = InterFontFamily,
    fontWeight = FontWeight.Bold,
    fontSize = 32.sp
)
```

## Typography Properties

ExFig extracts from Figma:

| Property       | XML                     | Compose         |
| -------------- | ----------------------- | --------------- |
| Font family    | `android:fontFamily`    | `fontFamily`    |
| Font size      | `android:textSize`      | `fontSize`      |
| Font weight    | `android:textStyle`     | `fontWeight`    |
| Line height    | `android:lineHeight`    | `lineHeight`    |
| Letter spacing | `android:letterSpacing` | `letterSpacing` |

## See Also

- <doc:Android>
- <doc:DesignRequirements>
- <doc:Configuration>
