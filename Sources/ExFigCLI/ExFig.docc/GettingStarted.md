# Getting Started

Install ExFig and configure your first export.

@Metadata {
    @PageImage(purpose: icon, source: "getting-started-icon", alt: "Getting started with ExFig")
    @PageColor(blue)
    @TitleHeading("Getting Started")
}

## Overview

ExFig is a command-line tool that exports design resources from Figma and Penpot to iOS, Android, Flutter, and Web projects.

## Requirements

- macOS 13.0 or later, Linux (Ubuntu 22.04), or Windows (Swift 6.3+)
- Figma account with file access, **or** Penpot account
- Figma Personal Access Token (for Figma sources) or Penpot Access Token (for Penpot sources)

## Installation

### Using Homebrew (Recommended)

```bash
brew install designpipe/tap/exfig
```

### Using Mint

```bash
mint install DesignPipe/exfig
```

### Using Mise

```bash
mise use -g github:DesignPipe/exfig
```

### From Source

```bash
git clone https://github.com/DesignPipe/exfig.git
cd ExFig
swift build -c release
cp .build/release/exfig /usr/local/bin/
```

### Download Binary

Download the latest release from [GitHub Releases](https://github.com/DesignPipe/exfig/releases).

## Authentication

### Figma Access Token

ExFig requires a Figma Personal Access Token to access the Figma API.

### Create a Token

1. Open [Figma Account Settings](https://www.figma.com/settings)
2. Scroll to **Personal access tokens**
3. Click **Create a new personal access token**
4. Give it a descriptive name (e.g., "ExFig CLI")
5. Copy the generated token

### Set the Token

Set the `FIGMA_PERSONAL_TOKEN` environment variable:

```bash nocopy
# Add to ~/.zshrc or ~/.bashrc
export FIGMA_PERSONAL_TOKEN="your-token-here"
```

Or pass it directly to commands:

```bash nocopy
FIGMA_PERSONAL_TOKEN="your-token" exfig colors
```

### Penpot Access Token

For Penpot sources, set the `PENPOT_ACCESS_TOKEN` environment variable:

1. Open your Penpot instance → Settings → Access Tokens
2. Create a new token
3. Set it:

```bash nocopy
export PENPOT_ACCESS_TOKEN="your-penpot-token-here"
```

> Note: `PENPOT_ACCESS_TOKEN` is only required when using `penpotSource` in config.

### Quick Penpot Icons Export (No Config)

```bash
# Export Penpot icons as SVG
export PENPOT_ACCESS_TOKEN="your-token"
exfig fetch --source penpot -f "file-uuid" -r "Icons" -o ./icons --format svg

# Export as PNG at 3x scale
exfig fetch --source penpot -f "file-uuid" -r "Icons" -o ./icons --format png --scale 3
```

> File UUID is in the Penpot workspace URL: `?file-id=UUID`.
> For shared libraries, use the library's file ID from the Assets panel.

## Quick Start

### 1. Initialize Configuration

Generate a starter configuration file for your platform:

```bash
# For iOS projects
exfig init --platform ios

# For Android projects
exfig init --platform android

# For Flutter projects
exfig init --platform flutter
```

This creates an `exfig.pkl` file in your current directory.

### 2. Get Your Figma File ID

The file ID is in the Figma URL:

```
https://www.figma.com/file/ABC123xyz/My-Design-System
                          ^^^^^^^^^^^
                          This is your file ID
```

### 3. Configure exfig.pkl

Edit the generated `exfig.pkl`:

```pkl
amends ".exfig/schemas/ExFig.pkl"

import ".exfig/schemas/Figma.pkl"
import ".exfig/schemas/iOS.pkl"

figma = new Figma.FigmaConfig {
  lightFileId = "YOUR_FILE_ID_HERE"
}

ios = new iOS.iOSConfig {
  xcodeprojPath = "./MyApp.xcodeproj"
  xcassetsPath = "./Resources/Assets.xcassets"
  // ... other iOS settings
}
```

### 4. Export Resources

```bash
# Export individual resource types
exfig colors
exfig icons
exfig images
exfig typography

# Or export everything at once with batch
exfig batch exfig.pkl
```

> Note: Individual commands use the `-i` flag for custom config paths (`exfig colors -i path.pkl`),
> while `batch` takes paths as positional arguments (`exfig batch path.pkl`).

## What's Next

- <doc:Usage> - Learn about all CLI commands and options
- <doc:Configuration> - Full configuration reference
- <doc:DesignRequirements> - How to structure your Figma files
- <doc:iOS> - iOS-specific export guide
- <doc:Android> - Android-specific export guide
- <doc:Flutter> - Flutter-specific export guide
