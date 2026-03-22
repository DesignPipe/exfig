# YAML to PKL Migration Guide

ExFig v2.0 replaces YAML configuration with PKL. This guide helps migrate existing configurations.

## Quick Migration

### 1. Install PKL

```bash
mise use pkl
```

### 2. Rename Config File

```bash
mv exfig.yaml exfig.pkl
```

### 3. Convert Syntax

Replace YAML syntax with PKL syntax (see mapping below).

### 4. Test

```bash
pkl eval exfig.pkl  # Validate config
exfig colors -i exfig.pkl --dry-run  # Test export
```

## Syntax Mapping

### File Header

**YAML:**
```yaml
# ExFig configuration
```

**PKL:**
```pkl
amends "package://github.com/DesignPipe/exfig@2.0.0#/ExFig.pkl"

import "package://github.com/DesignPipe/exfig@2.0.0#/Common.pkl"
import "package://github.com/DesignPipe/exfig@2.0.0#/iOS.pkl"
```

### Objects

**YAML:**
```yaml
figma:
  lightFileId: "abc123"
  timeout: 60
```

**PKL:**
```pkl
figma = new Figma.FigmaConfig {
  lightFileId = "abc123"
  timeout = 60
}
```

### Nested Objects

**YAML:**
```yaml
common:
  cache:
    enabled: true
    path: ".cache.json"
  variablesColors:
    tokensFileId: "file123"
    tokensCollectionName: "Tokens"
```

**PKL:**
```pkl
common = new Common.CommonConfig {
  cache = new Common.Cache {
    enabled = true
    path = ".cache.json"
  }
  variablesColors = new Common.VariablesColors {
    tokensFileId = "file123"
    tokensCollectionName = "Tokens"
  }
}
```

### Arrays/Lists

**YAML:**
```yaml
ios:
  colors:
    - tokensFileId: "file1"
      useColorAssets: true
      assetsFolder: "Colors1"
    - tokensFileId: "file2"
      useColorAssets: true
      assetsFolder: "Colors2"
```

**PKL:**
```pkl
ios = new iOS.iOSConfig {
  colors = new Listing {
    new iOS.ColorsEntry {
      tokensFileId = "file1"
      useColorAssets = true
      assetsFolder = "Colors1"
      nameStyle = "camelCase"
    }
    new iOS.ColorsEntry {
      tokensFileId = "file2"
      useColorAssets = true
      assetsFolder = "Colors2"
      nameStyle = "camelCase"
    }
  }
}
```

### Simple Lists

**YAML:**
```yaml
resourceBundleNames:
  - "ModuleA"
  - "ModuleB"
```

**PKL:**
```pkl
resourceBundleNames = new Listing { "ModuleA"; "ModuleB" }
```

### Number Lists

**YAML:**
```yaml
scales:
  - 1
  - 2
  - 3
```

**PKL:**
```pkl
scales = new Listing { 1; 2; 3 }
```

### Booleans

**YAML:**
```yaml
useColorAssets: true
xmlDisabled: false
```

**PKL:**
```pkl
useColorAssets = true
xmlDisabled = false
```

### Strings

**YAML:**
```yaml
xcodeprojPath: "MyApp.xcodeproj"
nameStyle: camelCase
```

**PKL:**
```pkl
xcodeprojPath = "MyApp.xcodeproj"
nameStyle = "camelCase"
```

**Note:** Enum values must be quoted in PKL.

### Null/Optional Values

**YAML:**
```yaml
darkFileId: ~
darkModeName: null
```

**PKL:**
Simply omit the field (PKL optional fields default to null):
```pkl
// darkFileId is not specified
// darkModeName is not specified
```

### Comments

**YAML:**
```yaml
# This is a comment
ios:
  xcodeprojPath: "App.xcodeproj"  # Inline comment
```

**PKL:**
```pkl
/// Doc comment (shown in IDE)
// Regular comment
ios = new iOS.iOSConfig {
  xcodeprojPath = "App.xcodeproj"  // Inline comment
}
```

## Complete Examples

### iOS Colors Only

**YAML:**
```yaml
common:
  variablesColors:
    tokensFileId: "abc123"
    tokensCollectionName: "Design Tokens"
    lightModeName: "Light"
    darkModeName: "Dark"

ios:
  xcodeprojPath: "MyApp.xcodeproj"
  target: "MyApp"
  xcassetsPath: "MyApp/Assets.xcassets"
  xcassetsInMainBundle: true
  colors:
    useColorAssets: true
    assetsFolder: "Colors"
    nameStyle: camelCase
    colorSwift: "Generated/UIColor+Colors.swift"
    swiftuiColorSwift: "Generated/Color+Colors.swift"
```

**PKL:**
```pkl
amends "package://github.com/DesignPipe/exfig@2.0.0#/ExFig.pkl"

import "package://github.com/DesignPipe/exfig@2.0.0#/Common.pkl"
import "package://github.com/DesignPipe/exfig@2.0.0#/iOS.pkl"

common = new Common.CommonConfig {
  variablesColors = new Common.VariablesColors {
    tokensFileId = "abc123"
    tokensCollectionName = "Design Tokens"
    lightModeName = "Light"
    darkModeName = "Dark"
  }
}

ios = new iOS.iOSConfig {
  xcodeprojPath = "MyApp.xcodeproj"
  target = "MyApp"
  xcassetsPath = "MyApp/Assets.xcassets"
  xcassetsInMainBundle = true

  colors = new iOS.ColorsEntry {
    useColorAssets = true
    assetsFolder = "Colors"
    nameStyle = "camelCase"
    colorSwift = "Generated/UIColor+Colors.swift"
    swiftuiColorSwift = "Generated/Color+Colors.swift"
  }
}
```

### Multi-Platform

**YAML:**
```yaml
figma:
  lightFileId: "light-file"
  darkFileId: "dark-file"

common:
  variablesColors:
    tokensFileId: "tokens"
    tokensCollectionName: "Colors"
    lightModeName: "Light"
    darkModeName: "Dark"
  icons:
    figmaFrameName: "Icons/24"

ios:
  xcodeprojPath: "iOS/App.xcodeproj"
  target: "App"
  xcassetsPath: "iOS/Assets.xcassets"
  xcassetsInMainBundle: true
  colors:
    useColorAssets: true
    assetsFolder: "Colors"
    nameStyle: camelCase
  icons:
    format: pdf
    assetsFolder: "Icons"
    nameStyle: camelCase

android:
  mainRes: "android/app/src/main/res"
  colors:
    colorKotlin: "android/app/src/main/kotlin/Colors.kt"
    composePackageName: "com.example.app"
  icons:
    output: "android/app/src/main/res/drawable"
    composeFormat: imageVector
```

**PKL:**
```pkl
amends "package://github.com/DesignPipe/exfig@2.0.0#/ExFig.pkl"

import "package://github.com/DesignPipe/exfig@2.0.0#/Figma.pkl"
import "package://github.com/DesignPipe/exfig@2.0.0#/Common.pkl"
import "package://github.com/DesignPipe/exfig@2.0.0#/iOS.pkl"
import "package://github.com/DesignPipe/exfig@2.0.0#/Android.pkl"

figma = new Figma.FigmaConfig {
  lightFileId = "light-file"
  darkFileId = "dark-file"
}

common = new Common.CommonConfig {
  variablesColors = new Common.VariablesColors {
    tokensFileId = "tokens"
    tokensCollectionName = "Colors"
    lightModeName = "Light"
    darkModeName = "Dark"
  }
  icons = new Common.Icons {
    figmaFrameName = "Icons/24"
  }
}

ios = new iOS.iOSConfig {
  xcodeprojPath = "iOS/App.xcodeproj"
  target = "App"
  xcassetsPath = "iOS/Assets.xcassets"
  xcassetsInMainBundle = true

  colors = new iOS.ColorsEntry {
    useColorAssets = true
    assetsFolder = "Colors"
    nameStyle = "camelCase"
  }

  icons = new iOS.IconsEntry {
    format = "pdf"
    assetsFolder = "Icons"
    nameStyle = "camelCase"
  }
}

android = new Android.AndroidConfig {
  mainRes = "android/app/src/main/res"

  colors = new Android.ColorsEntry {
    colorKotlin = "android/app/src/main/kotlin/Colors.kt"
    composePackageName = "com.example.app"
  }

  icons = new Android.IconsEntry {
    output = "android/app/src/main/res/drawable"
    composeFormat = "imageVector"
  }
}
```

## Key Differences

| Aspect | YAML | PKL |
|--------|------|-----|
| Assignment | `:` | `=` |
| Objects | Indentation | `new Type { }` |
| Lists | `- item` | `new Listing { item; item }` |
| Strings | Quotes optional | Quotes required for enums |
| Comments | `#` | `//` or `///` |
| Null | `~` or `null` | Omit field |
| Types | Runtime validation | Compile-time validation |
| Inheritance | Not supported | `amends "base.pkl"` |

## Required Fields

PKL schemas may require fields that were optional in YAML:

### iOS Colors

```pkl
// Required in PKL
colors = new iOS.ColorsEntry {
  useColorAssets = true      // Required
  nameStyle = "camelCase"    // Required
  // assetsFolder required if useColorAssets = true
  assetsFolder = "Colors"
}
```

### Android Icons

```pkl
// Required in PKL
icons = new Android.IconsEntry {
  output = "drawable"        // Required
}
```

### Flutter

```pkl
// Required in PKL
flutter = new Flutter.FlutterConfig {
  output = "lib/generated"   // Required
}
```

## Common Migration Errors

### Missing Type Prefix

**Error:**
```
Cannot find member 'ColorsEntry' in module 'ios'
```

**Fix:** Import and use full type path:
```pkl
import "package://github.com/DesignPipe/exfig@2.0.0#/iOS.pkl"

colors = new iOS.ColorsEntry { ... }
```

### Wrong String Syntax

**Error:**
```
Expected string literal
```

**Fix:** Quote enum values:
```pkl
// Wrong
nameStyle = camelCase

// Correct
nameStyle = "camelCase"
```

### Missing Required Field

**Error:**
```
Field 'useColorAssets' is required but missing
```

**Fix:** Add required field:
```pkl
colors = new iOS.ColorsEntry {
  useColorAssets = true  // Add this
  nameStyle = "camelCase"
}
```

### List Syntax Error

**Error:**
```
Expected '}' but found 'new'
```

**Fix:** Use semicolons in Listing:
```pkl
// Wrong
scales = new Listing { 1, 2, 3 }

// Correct
scales = new Listing { 1; 2; 3 }
```

## Batch Migration

For batch configs, rename all `.yaml` files to `.pkl`:

```bash
# Rename all yaml to pkl
for f in configs/*.yaml; do mv "$f" "${f%.yaml}.pkl"; done

# Convert each file
for f in configs/*.pkl; do
  echo "Converting $f..."
  # Manual conversion required
done

# Test batch
exfig batch configs/ --parallel 2 --dry-run
```

## Getting Help

- [PKL Documentation](https://pkl-lang.org/main/current/index.html)
- [ExFig PKL Guide](./PKL.md)
- [ExFig Schema Reference](https://github.com/DesignPipe/exfig/tree/main/Sources/ExFigCLI/Resources/Schemas)

## Validation Checklist

Before committing migrated config:

1. `pkl eval exfig.pkl` - No syntax/type errors
2. `exfig colors -i exfig.pkl --dry-run` - Export works
3. `exfig icons -i exfig.pkl --dry-run` - Icons export works
4. `exfig images -i exfig.pkl --dry-run` - Images export works
5. Compare output with previous YAML-based export
