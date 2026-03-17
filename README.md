# ExFig

[![CI](https://github.com/DesignPipe/exfig/actions/workflows/ci.yml/badge.svg)](https://github.com/DesignPipe/exfig/actions/workflows/ci.yml)
[![Release](https://github.com/DesignPipe/exfig/actions/workflows/release.yml/badge.svg)](https://github.com/DesignPipe/exfig/actions/workflows/release.yml)
[![Docs](https://github.com/DesignPipe/exfig/actions/workflows/deploy-docc.yml/badge.svg)](https://DesignPipe.github.io/exfig/documentation/exfig)
![Coverage](https://img.shields.io/badge/coverage-50.65%25-yellow)
[![License](https://img.shields.io/github/license/DesignPipe/exfig.svg)](LICENSE)

Command-line utility to export colors, typography, icons, and images from Figma to Xcode, Android Studio, Flutter, and
Web (React/TypeScript) projects.

Automatically sync your design system from Figma to code with support for Dark Mode, SwiftUI, UIKit, Jetpack Compose,
Flutter, and React/TypeScript.

## Why ExFig?

- **Eliminate manual export**: Figma doesn't natively export colors and images to Xcode/Android Studio
- **Keep design and code in sync**: Automate updates to your component library
- **Save time**: No more manual color palette management or icon exports

## Features

### Design Assets

- ✨ Export light & dark color palettes
- 🎨 High contrast color support (iOS)
- 🖼️ Icons and images with Dark Mode variants
- 📄 PDF vector icons (resolution-independent, iOS)
- 🖥️ iPad-specific asset variants
- 📝 Typography with Dynamic Type support (iOS)
- 🔄 RTL (Right-to-Left) layout support
- 🎯 Figma Variables support
- 📁 Local `.tokens.json` file import (no Figma API needed)

### Platform Support

- 📱 SwiftUI and UIKit (iOS/macOS)
- 🔗 Figma Code Connect integration (iOS, Android)
- 🤖 Jetpack Compose and XML resources (Android)
- ⚠️ Android pathData validation (errors on 32,767 bytes AAPT limit)
- 🦋 Flutter / Dart
- 🌐 React / TypeScript (CSS variables, TSX components)
- 🔧 Customizable code templates (Jinja2)

### Export Formats

- 🖼️ PNG, SVG, PDF, JPEG, WebP, HEIC (with quality control)
- 📊 W3C Design Tokens (DTCG v2025 format, unified JSON export)
- ⚡ Quick fetch mode (no config file needed)

### Performance & Reliability

- ⚡ Parallel downloads & writes
- 📦 Batch processing with shared rate limiting
- 🔁 Automatic retries with exponential backoff
- 💾 Checkpoint/resume for interrupted exports
- 🕐 Version tracking (skip unchanged files)
- 🧬 Granular cache (per-node change detection, experimental)

### Developer Experience

- 🤖 CI/CD ready (quiet mode, exit codes, JSON reports)
- 🔄 [GitHub Action](https://github.com/DesignPipe/exfig-action) for automated exports
- 🧠 MCP server for AI assistant integration
- 📊 Rich progress indicators with ETA
- 🔇 Verbose, normal, and quiet output modes
- 🚀 Swift 6 / Strict Concurrency

> **Note:** Exporting icons and images requires a Figma Professional/Organization plan (uses Shareable Team Libraries).

> **Tip:** For optimal PNG sizes, use oxipng (`github:shssoichiro/oxipng` via `mise use -g`) to compress exported PNG
> files after export.

## Quick Start

### 1. Install ExFig

```bash
# Using Homebrew (recommended)
brew install designpipe/tap/exfig

# Using Mint
mint install DesignPipe/exfig

# Using mise
mise use -g github:DesignPipe/exfig
```

### 2. Set Figma Token

```bash
export FIGMA_PERSONAL_TOKEN=your_token_here
```

Get your token from [Figma's developer settings](https://www.figma.com/developers/api#access-tokens). For secure token
storage, consider using [fnox](https://github.com/jdx/fnox) instead of plain `export`.

### 3. Generate Configuration

```bash
exfig init -p ios       # or: android, flutter, web
```

### 4. Configure File IDs

Edit `exfig.pkl` and add your Figma file IDs:

```pkl
figma {
  lightFileId = "YOUR_FIGMA_FILE_ID"
}
```

### 5. Export Resources

```bash
# Export individual resource types
exfig colors             # Export colors
exfig icons              # Export icons
exfig images             # Export images
exfig typography         # Export typography

# Export everything at once with batch
exfig batch exfig.pkl    # All resource types from single config
```

See [Configuration Reference](CONFIG.md) for all available options.

## What Gets Generated

### iOS

```
YourProject/
├── Assets.xcassets/
│   ├── Colors/              # Color sets with Light/Dark variants
│   ├── Icons/               # PDF/SVG vector icons
│   └── Images/              # PNG images with @1x, @2x, @3x
└── Sources/
    ├── UIColor+extension.swift      # Type-safe color access
    ├── Color+extension.swift        # SwiftUI colors
    ├── UIImage+extension.swift      # Image access
    ├── UIFont+extension.swift       # Typography
    └── Labels/                      # Pre-configured UILabel classes
```

### Android

```
app/src/main/
├── res/
│   ├── values/
│   │   ├── colors.xml               # Color definitions
│   │   └── typography.xml           # Text styles
│   ├── values-night/
│   │   └── colors.xml               # Dark mode colors
│   ├── drawable/                    # Vector icons/images
│   └── drawable-xxxhdpi/            # Raster images (multiple DPIs)
└── java/.../ui/exfig/
    ├── Colors.kt                    # Compose colors
    ├── Icons.kt                     # Compose icons
    └── Typography.kt                # Compose text styles
```

### Flutter

```
flutter_project/
├── assets/
│   ├── icons/
│   │   ├── ic_add.svg               # Light icons
│   │   └── ic_add_dark.svg          # Dark icons
│   └── images/
│       ├── logo.png                 # 1x scale
│       ├── 2.0x/logo.png            # 2x scale
│       └── 3.0x/logo.png            # 3x scale
└── lib/
    └── generated/
        ├── colors.dart              # Color constants
        ├── icons.dart               # Icon path constants
        └── images.dart              # Image path constants
```

## Advanced Features

### Batch Processing

Export all resource types (colors, icons, images, typography) from a single unified config:

```bash
exfig batch exfig.pkl                         # All resources from one config
exfig batch exfig.pkl --cache                 # With version tracking
```

Process multiple configuration files in parallel with shared rate limiting:

```bash
exfig batch ./configs/                        # All configs in directory
exfig batch ios.pkl android.pkl flutter.pkl   # Specific files
exfig batch ./configs/ --parallel 5           # Custom parallelism
exfig batch ./configs/ --report results.json  # JSON report
```

Supports `--fail-fast`, `--resume` (checkpoint/resume), and `--cache` (version tracking). See
[documentation](https://DesignPipe.github.io/exfig/documentation/exfig/usage) for all options.

### Quick Fetch (No Config File)

Download assets directly without a configuration file:

```bash
exfig fetch -f FILE_ID -r "Icons" -o ./icons --format svg
exfig fetch -f FILE_ID -r "Images" -o ./images --format webp --webp-quality 90
```

Supports all formats (PNG, SVG, PDF, JPEG, WebP), filtering (`--filter`), name conversion (`--name-style`), and dark
mode variants (`--dark-mode-suffix`). Run `exfig fetch --help` for all options.

### Design Tokens

Export Figma data as [W3C Design Tokens](https://design-tokens.github.io/community-group/format/) (DTCG v2025 format):

```bash
# Export from Figma API
exfig download colors -o tokens/colors.json
exfig download icons -o tokens/icons.json --asset-format svg
exfig download tokens -o tokens/design-tokens.json    # Unified (colors + typography + dimensions + numbers)
exfig download all -o ./tokens/

# Work with local .tokens.json files (no Figma token needed)
exfig tokens info ./tokens.json                        # Inspect token file
exfig tokens convert ./tokens.json -o out.json         # Re-export (filter/transform)
exfig tokens convert ./tokens.json --group "Brand" --type color -o brand-colors.json
```

Use `--w3c-version v1` for the legacy hex-string format. Colors entries also support `tokensFile` to import from a local
`.tokens.json` file (e.g., from Tokens Studio) without a Figma token — see [CONFIG.md](CONFIG.md).

### Version Tracking

Skip unchanged exports using Figma file version tracking:

```bash
exfig colors --cache                                    # Enable version tracking
exfig icons --cache --experimental-granular-cache       # Per-node change detection
```

Configure in `exfig.pkl` via `common.cache` or use CLI flags. See [CONFIG.md](CONFIG.md) for details.

### MCP Server

ExFig includes a [Model Context Protocol](https://modelcontextprotocol.io) server for AI assistant integration:

```bash
exfig mcp   # Start MCP server over stdio
```

Add to your `.mcp.json` (Claude Code, Cursor, etc.):

```json
{
  "mcpServers": {
    "exfig": {
      "command": "exfig",
      "args": ["mcp"],
      "env": {
        "FIGMA_PERSONAL_TOKEN": "figd_..."
      }
    }
  }
}
```

### Fault Tolerance

All commands include automatic retries with exponential backoff, rate limit handling (respects `Retry-After`), and
checkpoint/resume for interrupted exports. Configurable via `--max-retries`, `--rate-limit`, `--fail-fast`, and
`--resume`.

## GitHub Action

Automate design exports in CI/CD with [exfig-action](https://github.com/DesignPipe/exfig-action):

```yaml
- uses: DesignPipe/exfig-action@v1
  with:
    figma_token: ${{ secrets.FIGMA_TOKEN }}
    command: icons
    cache: true
```

## Requirements

- **Swift 6.2+** (for building from source)
- **macOS 13.0+** or **Linux (Ubuntu 22.04)**
- **[PKL](https://pkl-lang.org/)** - Configuration language (install via `brew install pkl` or `mise use -g pkl`)
- **Figma Personal Access Token**

## Documentation

Complete documentation is available at
**[DesignPipe.github.io/exfig](https://DesignPipe.github.io/exfig/documentation/exfig)** - including getting started
guides, platform-specific export details, design requirements, and custom templates.

See [CONFIG.md](CONFIG.md) for the full configuration reference.

## Contributing

We welcome contributions! See the
[Development Guide](https://DesignPipe.github.io/exfig/documentation/exfig/development) for setup, testing, and code
style guidelines.

## License

ExFig is available under the MIT License. See [LICENSE](LICENSE) for details.

---

**[Read the full documentation](https://DesignPipe.github.io/exfig/documentation/exfig)** |
[Report an issue](https://github.com/DesignPipe/exfig/issues) |
[Figma API](https://www.figma.com/developers/api)

---

<sub>Originally inspired by [figma-export](https://github.com/RedMadRobot/figma-export).</sub>
