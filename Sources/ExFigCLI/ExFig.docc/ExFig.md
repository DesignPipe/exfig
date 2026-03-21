# ``ExFigCLI``

Export colors, typography, icons, and images from Figma and Penpot to iOS, Android, Flutter, and Web projects.

## Overview

ExFig is a command-line tool that automates design-to-code handoff. Point it at a Figma file
or a Penpot project, and it generates platform-native resources: Color Sets for Xcode, XML
resources for Android, Dart constants for Flutter, and CSS variables for React — all from one
source of truth.

ExFig handles the details that make manual export painful: light/dark mode variants, @1x/@2x/@3x
image scales, high contrast colors, RTL icon mirroring, and Dynamic Type mappings. A single
`exfig batch` command replaces hours of copy-paste work across platforms.

It's built for teams that maintain a Figma or Penpot-based design system and need a reliable,
automated pipeline to keep code in sync with design. ExFig works locally for quick exports and
in CI/CD for fully automated workflows.

> Tip: ExFig also works with local `.tokens.json` files and Penpot projects — no Figma API access needed.

### Supported Platforms

- **iOS / macOS** — SwiftUI, UIKit, `.xcassets`, PDF/SVG vectors, Figma Code Connect
- **Android** — Jetpack Compose, XML resources, VectorDrawable, Figma Code Connect
- **Flutter** — Dart constants, SVG/PNG assets with scale directories
- **Web** — React/TypeScript, CSS variables, TSX icon components

### Key Capabilities

**Design Assets**
Colors with light/dark/high-contrast variants, vector icons (PDF, SVG, VectorDrawable),
raster images with multi-scale support, typography with Dynamic Type, RTL layout support,
Figma Variables integration, and Penpot library colors/components/typography.

**Export Formats**
PNG, SVG, PDF, JPEG, WebP, HEIC output formats with quality control.
W3C Design Tokens (DTCG v2025) for token pipelines.
Quick fetch mode with interactive wizard for one-off downloads without a config file.
Interactive `exfig init` wizard for guided config setup with file IDs and asset selection.

**Performance and Reliability**
Parallel downloads and writes, batch processing with shared rate limiting,
automatic retries with exponential backoff, checkpoint/resume for interrupted exports,
file version tracking, and experimental per-node granular cache.

**Developer Experience**
CI/CD ready (quiet mode, exit codes, JSON reports), GitHub Action for automated exports,
MCP server for AI assistant integration,
[Claude Code plugins](https://github.com/DesignPipe/exfig-plugins) for setup wizards and slash commands,
customizable Jinja2 code templates, and rich progress indicators with ETA.

**Code Generation**
Type-safe Swift/Kotlin/Dart/TypeScript extensions, pre-configured UILabel subclasses,
Compose color and icon objects, and Flutter path constants.

> Important: Exporting icons and images from Figma requires a Professional or Organization plan
> (uses Shareable Team Libraries). Penpot has no plan restrictions for API access.

## Topics

### Getting Started

- <doc:WhyExFig>
- <doc:GettingStarted>
- <doc:Usage>
- <doc:Configuration>
- <doc:DesignRequirements>

### Platform Guides

- <doc:iOS>
- <doc:iOSColors>
- <doc:iOSIcons>
- <doc:iOSImages>
- <doc:iOSTypography>
- <doc:Android>
- <doc:AndroidColors>
- <doc:AndroidIcons>
- <doc:AndroidImages>
- <doc:AndroidTypography>
- <doc:Flutter>

### Advanced

- <doc:BatchProcessing>
- <doc:DesignTokens>
- <doc:CustomTemplates>
- <doc:MCPServer>
- <doc:CICDIntegration>

### Contributing

- <doc:Development>
