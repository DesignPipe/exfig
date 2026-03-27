# Design File Structure

How to structure your design files for optimal export with ExFig.

## Overview

ExFig extracts design resources from **Figma** files and **Penpot** projects based on naming conventions
and organizational structures. This guide explains how to set up your design files for seamless export.

- **Figma**: Uses frames, components, color styles, and Variables
- **Penpot**: Uses shared library colors, components, and typographies

## Figma

### Frame Organization

ExFig looks for resources in specific frames. Configure frame names in your `exfig.pkl`:

```pkl
import ".exfig/schemas/Common.pkl"

common = new Common.CommonConfig {
  colors = new Common.Colors {
    figmaFrameName = "Colors"
  }
  icons = new Common.Icons {
    figmaFrameName = "Icons"
  }
  images = new Common.Images {
    figmaFrameName = "Illustrations"
  }
  typography = new Common.Typography {
    figmaFrameName = "Typography"
  }
}
```

### Naming Conventions

Use consistent naming patterns for all resources. ExFig supports regex validation:

```pkl
import ".exfig/schemas/Common.pkl"

common = new Common.CommonConfig {
  icons = new Common.Icons {
    nameValidateRegexp = "^ic/[0-9]+/[a-z_]+$"  // e.g., ic/24/arrow_right
  }
}
```

### Colors

#### Using Color Styles

Create color styles in Figma with descriptive names:

```
Colors frame
├── primary
├── secondary
├── background/primary
├── background/secondary
├── text/primary
├── text/secondary
└── border/default
```

#### Using Figma Variables

For Figma Variables API support:

```pkl
import ".exfig/schemas/Common.pkl"

common = new Common.CommonConfig {
  variablesColors = new Common.VariablesColors {
    tokensFileId = "ABC123xyz"
    tokensCollectionName = "Colors"
    lightModeName = "Light"
    darkModeName = "Dark"
  }
}
```

Variable structure in Figma:

```
Colors collection
├── Mode: Light
│   ├── primary: #007AFF
│   ├── background: #FFFFFF
│   └── text: #000000
└── Mode: Dark
    ├── primary: #0A84FF
    ├── background: #000000
    └── text: #FFFFFF
```

#### Naming Guidelines

- Use lowercase with optional separators: `/`, `-`, `_`
- Group related colors with prefixes: `text/primary`, `background/card`
- Avoid special characters except separators

### Icons

#### Component Structure

Icons must be **components** (not plain frames):

```
Icons frame
├── ic/24/arrow-right     (component)
├── ic/24/arrow-left      (component)
├── ic/16/close           (component)
├── ic/16/check           (component)
└── ic/32/menu            (component)
```

#### Size Conventions

Organize icons by size:

```
Icons frame
├── ic/16/...   (16pt icons)
├── ic/24/...   (24pt icons)
├── ic/32/...   (32pt icons)
└── ic/48/...   (48pt icons)
```

#### Vector Requirements

For optimal vector export:

1. **Use strokes carefully**: Convert strokes to outlines for complex icons
2. **Flatten boolean operations**: Flatten complex boolean operations before export
3. **Remove hidden layers**: Delete unused or hidden elements
4. **Use consistent viewBox**: Keep viewBox dimensions consistent within size groups

#### Dark Mode Icons

Two approaches for dark mode support:

**Separate files:**

```pkl
import ".exfig/schemas/Figma.pkl"

figma = new Figma.FigmaConfig {
  lightFileId = "abc123"
  darkFileId = "def456"
}
```

Create matching component names in both files.

**Single file with suffix:**

```pkl
import ".exfig/schemas/Common.pkl"

common = new Common.CommonConfig {
  icons = new Common.Icons {
    useSingleFile = true
    darkModeSuffix = "_dark"
  }
}
```

```
Icons frame
├── ic/24/arrow-right
├── ic/24/arrow-right_dark
├── ic/24/close
└── ic/24/close_dark
```

**Variable Modes (per-entry, recommended for Figma Variables):**

When icons use Figma Variable bindings for colors (e.g., fill bound to a `DesignTokens` collection
with Light/Dark modes), ExFig can auto-generate dark SVGs by resolving variable values:

```pkl
import ".exfig/schemas/Common.pkl"

// Single-file mode: all variables in the same file as icons
new iOS.IconsEntry {
  figmaFrameName = "Icons"
  variablesDarkMode = new Common.VariablesDarkMode {
    collectionName = "DesignTokens"  // exact collection name (case-sensitive)
    lightModeName = "Light"          // exact mode name
    darkModeName = "Dark"            // exact mode name
  }
}

// Cross-file mode: icon variables reference an external library
new iOS.IconsEntry {
  figmaFrameName = "Icons"
  variablesDarkMode = new Common.VariablesDarkMode {
    collectionName = "DesignTokens"
    lightModeName = "Light"
    darkModeName = "Dark"
    variablesFileId = "LIB_FILE_ID"    // library containing primitive values
    primitivesModeName = "Value"       // mode in primitives collection (optional)
  }
}
```

No naming conventions required — ExFig reads variable bindings directly from Figma nodes.
Supports alpha/opacity in color replacements.

### Images

#### Component Structure

Images must be **components**:

```
Illustrations frame
├── img-empty-state       (component)
├── img-onboarding-1      (component)
├── img-onboarding-2      (component)
└── img-hero-banner       (component)
```

#### Size Recommendations

Design at the largest needed scale:

- **iOS**: Design at @3x, ExFig generates @1x, @2x, @3x
- **Android**: Design at xxxhdpi (4x), ExFig generates all densities
- **Flutter**: Design at 3x, ExFig generates 1x, 2x, 3x

#### Multi-Idiom Support (iOS)

Use suffixes for device-specific variants:

```
Illustrations frame
├── img-hero~iphone       (iPhone variant)
├── img-hero~ipad         (iPad variant)
├── img-hero~mac          (Mac variant)
└── img-sidebar~ipad
```

#### Dark Mode Images

Same approaches as icons:

**Separate files** or **suffix-based**:

```
Illustrations frame
├── img-empty-state
├── img-empty-state_dark
├── img-hero
└── img-hero_dark
```

### Typography

#### Text Style Structure

Create text styles with hierarchical names:

```
Typography frame
├── heading/h1
├── heading/h2
├── heading/h3
├── body/regular
├── body/bold
├── caption/regular
└── caption/small
```

#### Required Properties

Each text style should define:

- **Font family**: e.g., "SF Pro Text"
- **Font weight**: e.g., Regular, Bold, Semibold
- **Font size**: in pixels
- **Line height**: in pixels or percentage
- **Letter spacing**: in pixels or percentage

#### Font Mapping

Map Figma fonts to platform fonts in your config:

```pkl
import ".exfig/schemas/iOS.pkl"
import ".exfig/schemas/Android.pkl"

ios = new iOS.iOSConfig {
  typography = new iOS.Typography {
    // fontMapping configured via custom templates
  }
}

android = new Android.AndroidConfig {
  typography = new Android.Typography {
    // fontMapping configured via custom templates
  }
}
```

### Validation Regex Patterns

#### Common Patterns

```pkl
import ".exfig/schemas/Common.pkl"

common = new Common.CommonConfig {
  colors = new Common.Colors {
    // Allow: primary, text/primary, background_card
    nameValidateRegexp = "^[a-z][a-z0-9_/]*$"
  }

  icons = new Common.Icons {
    // Require: ic/SIZE/name format
    nameValidateRegexp = "^ic/[0-9]+/[a-z][a-z0-9_-]*$"
  }

  images = new Common.Images {
    // Require: img- prefix
    nameValidateRegexp = "^img-[a-z][a-z0-9_-]*$"
  }
}
```

#### Transform Patterns

Transform names during export:

```pkl
import ".exfig/schemas/Common.pkl"

common = new Common.CommonConfig {
  icons = new Common.Icons {
    nameValidateRegexp = "^ic/([0-9]+)/(.+)$"
    nameReplaceRegexp = "ic$1_$2"  // ic/24/arrow -> ic24_arrow
  }
}
```

### Recommended Figma Structure

```
Design System
├── Colors
│   ├── Primary palette
│   ├── Secondary palette
│   ├── Semantic colors
│   └── Dark mode colors
├── Icons
│   ├── 16pt icons
│   ├── 24pt icons
│   └── 32pt icons
├── Illustrations
│   ├── Empty states
│   ├── Onboarding
│   └── Marketing
└── Typography
    ├── Headings
    ├── Body text
    └── Captions
```

### Light and Dark Mode Files

For complex theming, use separate files:

- `Design-System-Light.fig`: Light mode resources
- `Design-System-Dark.fig`: Dark mode resources

Ensure component names match exactly between files.

### Figma Troubleshooting

#### Resources Not Found

- Verify frame names match `figmaFrameName` in config
- Check that resources are **components**, not plain frames
- Ensure names pass validation regex

#### Missing Dark Mode

- Verify `darkFileId` is set correctly
- Check component names match between light and dark files
- For single-file mode, verify suffix is correct

#### Export Quality Issues

- Design at highest needed resolution
- Use vector graphics when possible
- Avoid raster effects in vector icons
- Flatten complex boolean operations

## Penpot

ExFig reads Penpot library assets — colors, components, and typographies — from the shared library
of a Penpot file. All assets must be added to the **shared library** (Assets panel), not just placed
on the canvas.

### Authentication

Set the `PENPOT_ACCESS_TOKEN` environment variable:

1. Open Penpot → Settings → Access Tokens
2. Create a new token (no expiration recommended for CI)
3. Export:

```bash
export PENPOT_ACCESS_TOKEN="your-token-here"
```

No `FIGMA_PERSONAL_TOKEN` needed when using only Penpot sources.

### Library Colors

Colors must be in the shared **Library** (Assets panel → Local library → Colors):

```
Library Colors
├── Brand/Primary      (#3B82F6)
├── Brand/Secondary    (#8B5CF6)
├── Semantic/Success   (#22C55E)
├── Semantic/Warning   (#F59E0B)
├── Semantic/Error     (#EF4444)
├── Neutral/Background (#1E1E2E)
├── Neutral/Text       (#F8F8F2)
└── Neutral/Overlay    (#000000, 50% opacity)
```

Key points:

- Only **solid hex colors** are exported. Gradients and image fills are skipped in v1.
- The `path` field organizes colors into groups: `path: "Brand"`, `name: "Primary"` → `Brand/Primary`
- Use `pathFilter` in your config to select a specific group: `pathFilter = "Brand"` exports only Brand colors
- **Opacity** is preserved (0.0–1.0)

Config example:

```pkl
penpotSource = new Common.PenpotSource {
  fileId = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
  pathFilter = "Brand"  // optional: export only Brand/* colors
}
```

### Library Components (Icons and Images)

Components must be in the shared **Library** (Assets panel → Local library → Components).
ExFig filters by the component `path` prefix (equivalent to Figma's frame name):

```
Library Components
├── Icons/Navigation/arrow-left
├── Icons/Navigation/arrow-right
├── Icons/Actions/close
├── Icons/Actions/check
├── Illustrations/Empty States/no-data
└── Illustrations/Onboarding/welcome
```

Config example:

```pkl
penpotSource = new Common.PenpotSource {
  fileId = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
}
// Use path prefix as the frame filter
figmaFrameName = "Icons/Navigation"  // exports arrow-left, arrow-right
```

ExFig reconstructs SVG directly from Penpot's shape tree — no headless Chrome or CDN needed.
Supported output formats: **SVG** (native vector), **PNG** (via resvg at any scale), **PDF**, **WebP**.

### Library Typography

Typography styles must be in the shared **Library** (Assets panel → Local library → Typography):

```
Library Typography
├── Heading/H1     (Roboto Bold 32px)
├── Heading/H2     (Roboto Bold 24px)
├── Body/Regular   (Roboto Regular 16px)
├── Body/Bold      (Roboto Bold 16px)
└── Caption/Small  (Roboto Regular 12px)
```

Required fields:

- **fontFamily** — e.g., "Roboto", "DM Mono"
- **fontSize** — must be set (styles without a parseable font size are skipped)

Supported fields: `fontWeight`, `lineHeight`, `letterSpacing`, `textTransform` (uppercase/lowercase).

> Penpot may serialize numeric fields as strings (e.g., `"24"` instead of `24`). ExFig handles both formats automatically.

### Recommended Penpot Structure

```
Design System (Penpot file)
├── Library Colors
│   ├── Brand/* (primary, secondary, accent)
│   ├── Semantic/* (success, warning, error, info)
│   └── Neutral/* (background, text, border, overlay)
├── Library Components
│   ├── Icons/Navigation/* (arrow, chevron, menu)
│   ├── Icons/Actions/* (close, check, edit, delete)
│   └── Illustrations/* (empty states, onboarding)
└── Library Typography
    ├── Heading/* (H1, H2, H3)
    ├── Body/* (regular, bold, italic)
    └── Caption/* (regular, small)
```

### Known Limitations

- **No dark mode support** — Penpot has no Variables/modes equivalent; colors export as light-only
- **No `exfig_inspect` for Penpot** — the MCP inspect tool works with Figma API only
- **Gradients skipped** — only solid hex colors are supported
- **No page filtering** — all library assets are global to the file, not page-scoped
- **SVG reconstruction scope** — supports path, rect, circle, bool, group shapes; complex effects (blur, shadow, gradients on shapes) are not yet rendered

### Penpot Troubleshooting

#### No Colors Exported

- Verify colors are in the **shared library**, not just swatches on the canvas
- Check `pathFilter` — a too-specific prefix returns no results
- Gradient colors are skipped; use solid fills

#### No Components Exported

- Verify components are in the **shared library** (right-click shape → "Create component")
- Check the path prefix in `figmaFrameName` matches the component `path`
- Thumbnails may not be generated for programmatically created components

#### Typography Styles Skipped

- Ensure `fontSize` is set on the typography style
- Styles with unparseable font size values are silently skipped

#### Authentication Errors

- `PENPOT_ACCESS_TOKEN environment variable is required` — set the token
- Penpot 401 — token expired or invalid; regenerate in Settings → Access Tokens
- Self-hosted instances: set `baseUrl` in `penpotSource`

## See Also

- <doc:Configuration>
- <doc:iOS>
- <doc:Android>
- <doc:Flutter>
