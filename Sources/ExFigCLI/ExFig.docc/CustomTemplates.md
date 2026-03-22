# Custom Templates

Customize generated code using Jinja2 templates.

@Metadata {
    @PageImage(purpose: icon, source: "templates-icon", alt: "Custom templates")
    @PageColor(purple)
    @TitleHeading("Advanced")
}

## Overview

ExFig uses [Jinja2](https://github.com/huggingface/swift-jinja) templates to generate platform-specific code. You can customize the
output by providing your own templates.

## Setting Up Custom Templates

### 1. Create Templates Directory

```bash
mkdir -p ./templates
```

### 2. Configure Template Path

```pkl
import ".exfig/schemas/iOS.pkl"
import ".exfig/schemas/Android.pkl"
import ".exfig/schemas/Flutter.pkl"
import ".exfig/schemas/Web.pkl"

ios = new iOS.iOSConfig {
  templatesPath = "./templates"
}

android = new Android.AndroidConfig {
  templatesPath = "./templates"
}

flutter = new Flutter.FlutterConfig {
  templatesPath = "./templates"
}

web = new Web.WebConfig {
  templatesPath = "./templates"
}
```

### 3. Copy Default Templates

Copy the default templates from ExFig source to use as a starting point. Templates are located in:

- `Sources/XcodeExport/Resources/` - iOS templates
- `Sources/AndroidExport/Resources/` - Android templates
- `Sources/FlutterExport/Resources/` - Flutter templates
- `Sources/WebExport/Resources/` - Web templates

## iOS Templates

### Available Templates

| Template                              | Output            | Description               |
| ------------------------------------- | ----------------- | ------------------------- |
| `UIColor+extension.swift.jinja`       | UIColor extension | UIKit color definitions   |
| `Color+extension.swift.jinja`         | Color extension   | SwiftUI color definitions |
| `UIImage+extension.swift.jinja`       | UIImage extension | UIKit image accessors     |
| `Image+extension.swift.jinja`         | Image extension   | SwiftUI image accessors   |
| `UIFont+extension.swift.jinja`        | UIFont extension  | UIKit font definitions    |
| `Font+extension.swift.jinja`          | Font extension    | SwiftUI font definitions  |
| `Label.swift.jinja`                   | Label class       | UIKit label styles        |
| `LabelStyle.swift.jinja`             | LabelStyle enum   | Label style definitions   |
| `LabelStyle+extension.swift.jinja`   | LabelStyle ext.   | LabelStyle factory methods |
| `CodeConnect.figma.swift.jinja`      | Code Connect      | Figma Code Connect (debug) |
| `header.jinja`                        | File header       | Common header comment     |

> Note: Files ending in `.jinja.include` (e.g., `Bundle+extension.swift.jinja.include`) are partial templates — they are pre-rendered into context variables (like `bundleExtension`) and included in the main template output. You typically don't need to customize these.

### Context Variables (Colors)

```swift
// Available in color templates
colors: [
    {
        name: "primaryBlue",           // Formatted name
        originalName: "primary/blue",  // Original Figma name
        red: 0.0,                       // RGB components (0-1)
        green: 0.478,
        blue: 1.0,
        alpha: 1.0,
        hex: "#007AFF"                  // Hex string
    }
]
darkColors: [...]  // Same structure for dark mode
```

### Context Variables (Icons)

```swift
// Available in icon templates
icons: [
    {
        name: "icArrowRight",          // Formatted name
        originalName: "ic/24/arrow-right"
    }
]
```

### Context Variables (Typography)

```swift
// Available in typography templates
textStyles: [
    {
        name: "bodyRegular",
        fontFamily: "Inter",
        fontWeight: "regular",         // regular, medium, semibold, bold
        fontWeightValue: 400,          // Numeric weight
        fontSize: 16.0,
        lineHeight: 24.0,              // nil if not set
        letterSpacing: 0.0
    }
]
```

### Example: Custom UIColor Template

```jinja
{{ header }}

import UIKit

public extension UIColor {
    {% for color in colors %}
    /// {{ color.originalName }}
    static let {{ color.name }} = UIColor(
        red: {{ color.red }},
        green: {{ color.green }},
        blue: {{ color.blue }},
        alpha: {{ color.alpha }}
    )
    {% endfor %}
}
```

## Android Templates

### Available Templates

| Template               | Output         | Description               |
| ---------------------- | -------------- | ------------------------- |
| `colors.xml.jinja`     | colors.xml     | XML color resources       |
| `Colors.kt.jinja`      | Colors.kt      | Compose color definitions |
| `typography.xml.jinja`  | typography.xml | XML text styles           |
| `Typography.kt.jinja`  | Typography.kt  | Compose typography        |
| `Icons.kt.jinja`       | Icons.kt       | Compose icon composables  |
| `CodeConnect.figma.kt.jinja` | Code Connect | Figma Code Connect (debug) |
| `header.jinja`         | File header    | Common header comment     |

### Context Variables (Colors)

```kotlin
// Available in color templates
colors: [
    {
        name: "primary_blue",          // snake_case name
        hex: "#007AFF",                // With alpha: "#FF007AFF"
        hexARGB: "FF007AFF"            // ARGB without #
    }
]
```

### Context Variables (Typography)

```kotlin
// Available in typography templates
textStyles: [
    {
        name: "body_regular",
        fontFamily: "inter",           // Lowercase
        fontWeightName: "Normal",      // FontWeight constant name
        fontSize: 16,                  // In sp
        lineHeight: 24,                // In sp, nil if not set
        letterSpacing: 0.0             // In em
    }
]
```

### Example: Custom Colors.kt Template

```jinja
{{ header }}

package {{ packageName }}

import androidx.compose.ui.graphics.Color

object AppColors {
    {% for color in colors %}
    val {{ color.name }} = Color(0x{{ color.hexARGB }})
    {% endfor %}
}

object AppColorsDark {
    {% for color in darkColors %}
    val {{ color.name }} = Color(0x{{ color.hexARGB }})
    {% endfor %}
}
```

## Flutter Templates

### Available Templates

| Template            | Output      | Description           |
| ------------------- | ----------- | --------------------- |
| `colors.dart.jinja` | colors.dart | Dart color constants  |
| `icons.dart.jinja`  | icons.dart  | Dart icon paths       |
| `images.dart.jinja` | images.dart | Dart image paths      |
| `header.jinja`      | File header | Common header comment |

### Context Variables

```dart
// Available in Flutter templates
colors: [
    {
        name: "primaryBlue",
        hex: "0xFF007AFF"              // Dart Color format
    }
]

icons: [
    {
        name: "icArrowRight",
        path: "assets/icons/ic_arrow_right.svg"
    }
]

images: [
    {
        name: "imgHero",
        path: "assets/images/img_hero.png"
    }
]
```

### Example: Custom colors.dart Template

```jinja
{{ header }}

import 'package:flutter/material.dart';

class {{ className }} {
  {{ className }}._();

  {% for color in colors %}
  /// {{ color.originalName }}
  static const Color {{ color.name }} = Color({{ color.hex }});
  {% endfor %}
}

class {{ className }}Dark {
  {{ className }}Dark._();

  {% for color in darkColors %}
  static const Color {{ color.name }} = Color({{ color.hex }});
  {% endfor %}
}
```

## Web Templates

### Available Templates

| Template              | Output          | Description                        |
| --------------------- | --------------- | ---------------------------------- |
| `theme.css.jinja`     | theme.css       | CSS custom properties (light/dark) |
| `variables.ts.jinja`  | variables.ts    | TypeScript CSS variable references |
| `theme.json.jinja`    | theme.json      | JSON theme tokens                  |
| `Icon.tsx.jinja`      | Icon component  | React SVG icon component           |
| `types.ts.jinja`      | types.ts        | TypeScript type definitions        |
| `IconIndex.ts.jinja`  | index.ts        | Icon barrel exports                |
| `Image.tsx.jinja`     | Image component | React image component              |
| `ImageIndex.ts.jinja` | index.ts        | Image barrel exports               |
| `header.jinja`        | File header     | Common header comment              |

### Context Variables (Colors)

```typescript
// variables.ts context
colors: [{ camelName: "primaryBlue", cssName: "primary-blue" }]

// theme.css / theme.json context
lightColors: [{ cssName: "primary-blue", value: "#007AFF" }]
darkColors: [{ cssName: "primary-blue", value: "#0A84FF" }]
hasDarkColors: true
```

### Context Variables (Icons)

```typescript
// Icon.tsx context (per component)
componentName: "ArrowRight"
viewBox: "0 0 24 24"
svgContent: "<path ...>"

// IconIndex.ts context
icons: [{ componentName: "ArrowRight", fileName: "arrow_right" }]
```

### Context Variables (Images)

```typescript
// Image.tsx context (per component)
componentName: "HeroBanner"
name: "hero_banner"
assetPath: "assets/images/hero_banner.png"

// ImageIndex.ts context
images: [{ componentName: "HeroBanner", fileName: "hero_banner" }]
```

### Example: Custom theme.css Template

```jinja
:root {
  {% for color in lightColors %}
  --{{ color.cssName }}: {{ color.value }};
  {% endfor %}
}

{% if hasDarkColors %}
@media (prefers-color-scheme: dark) {
  :root {
    {% for color in darkColors %}
    --{{ color.cssName }}: {{ color.value }};
    {% endfor %}
  }
}
{% endif %}
```

## Jinja2 Syntax Reference

### Variables

```jinja
{{ variableName }}
{{ object.property }}
```

### Loops

```jinja
{% for item in items %}
{{ item.name }}
{% endfor %}
```

### Loop Variables

```jinja
{% for item in items %}
{{ loop.index }}        {# 1-based index #}
{{ loop.index0 }}       {# 0-based index #}
{{ loop.first }}        {# true on first iteration #}
{{ loop.last }}         {# true on last iteration #}
{% endfor %}
```

### Conditionals

```jinja
{% if condition %}
...
{% elif otherCondition %}
...
{% else %}
...
{% endif %}
```

### Filters

```jinja
{{ name | upper }}
{{ name | lower }}
{{ name | capitalize }}
```

> Note: Name transformation filters (camelCase, snake_case, etc.) are not needed — name formatting is applied before template rendering, so variable values arrive pre-formatted.

### Comments

```jinja
{# This is a comment #}
```

## Best Practices

1. **Start from defaults**: Copy default templates as a starting point
2. **Use context variables**: Common data (like headers) is provided as pre-rendered context variables
3. **Validate output**: Test generated code compiles correctly
4. **Document changes**: Add comments explaining customizations
5. **Version control**: Keep templates in your repository
6. **Pre-formatted names**: Name formatting (camelCase, snake_case, etc.) is done before template rendering — use names as-is

## See Also

- <doc:Configuration>
- <doc:iOS>
- <doc:Android>
- <doc:Flutter>
- [swift-jinja Documentation](https://github.com/huggingface/swift-jinja)
