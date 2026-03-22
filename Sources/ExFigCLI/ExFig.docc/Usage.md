# Usage

Command-line interface reference and common usage patterns.

@Metadata {
    @PageImage(purpose: icon, source: "usage-icon", alt: "CLI usage")
    @PageColor(blue)
    @TitleHeading("Getting Started")
}

## Overview

ExFig provides commands for exporting colors, icons, images, and typography from Figma and Penpot to native platform resources.

## Basic Commands

```bash
# Export colors
exfig colors

# Export icons
exfig icons

# Export images
exfig images

# Export typography
exfig typography
```

## Getting Started

Generate a config file with the interactive wizard:

```bash
exfig init
```

The wizard guides you through platform selection, asset types, and Figma file IDs.
For non-interactive use, specify the platform directly:

```bash
exfig init -p ios       # Full iOS template
exfig init -p android   # Full Android template
```

## Configuration File

By default, ExFig looks for `exfig.pkl` in the current directory. Specify a different location:

```bash
exfig colors -i path/to/exfig.pkl
exfig colors --input path/to/exfig.pkl
```

## Filtering Exports

Export specific items by name:

### Single Item

```bash
exfig icons "ic/24/edit"
```

### Multiple Items

Separate names with commas:

```bash
exfig icons "ic/24/edit, ic/16/notification"
```

### Wildcard Patterns

Use `*` to match multiple items:

```bash
# Export all icons starting with "ic/24/videoplayer/"
exfig icons "ic/24/videoplayer/*"

# Export all colors starting with "common/"
exfig colors "common/*"

# Export all typography styles starting with "heading/"
exfig typography "heading/*"
```

> Note: Wildcard patterns don't work on Linux systems.

## Version Tracking

Skip unchanged exports with version tracking:

```bash
# Enable version tracking
exfig colors --cache
exfig icons --cache

# Disable version tracking
exfig icons --no-cache

# Force export and update cache
exfig icons --force

# Custom cache file path
exfig icons --cache-path ./custom-cache.json
```

> Note: The version changes when a Figma library is **published**, not on every auto-save.

For batch mode version tracking and granular cache, see <doc:BatchProcessing>.

## Fault Tolerance

All commands support fault tolerance options:

### Basic Options

```bash
# Custom retry count (default: 4)
exfig colors --max-retries 6

# Custom rate limit (default: 10 req/min)
exfig icons --rate-limit 20
```

### Extended Options

Commands that download many files (`icons`, `images`, `fetch`) support additional options:

```bash
# Stop on first error
exfig icons --fail-fast

# Resume from checkpoint after interruption
exfig images --resume

# Increase concurrent downloads (default: 20)
exfig icons --concurrent-downloads 50
```

| Option                   | Description                            | Commands             |
| ------------------------ | -------------------------------------- | -------------------- |
| `--max-retries`          | Maximum retry attempts (default: 4)    | All                  |
| `--rate-limit`           | API requests per minute (default: 10)  | All                  |
| `--fail-fast`            | Stop immediately on error              | icons, images, fetch |
| `--resume`               | Continue from checkpoint               | icons, images, fetch |
| `--concurrent-downloads` | Concurrent CDN downloads (default: 20) | icons, images, fetch |

### Checkpoint System

Long-running exports create checkpoints for resumption:

```bash
# Resume interrupted export
exfig icons --resume

# Checkpoints stored in: .exfig-checkpoint.json
# Checkpoints expire after 24 hours
# Successful completion deletes the checkpoint
```

## Quick Fetch

Download images without a configuration file. Run `exfig fetch` with no arguments for an
interactive wizard that guides you through file ID, asset type, platform, frame selection,
format, output directory, and more:

```bash
# Interactive wizard — asks platform, format, output step by step
exfig fetch

# Or pass all options directly
exfig fetch --file-id YOUR_FILE_ID --frame "Illustrations" --output ./images

# Using short options
exfig fetch -f YOUR_FILE_ID -r "Icons" -o ./icons
```

The wizard provides smart defaults per platform (e.g., SVG + camelCase for iOS icons,
WebP + snake_case for Android illustrations) and only runs in interactive terminals.

### Format Options

```bash
# SVG (vector)
exfig fetch -f abc123 -r "Icons" -o ./icons --format svg

# PDF (vector)
exfig fetch -f abc123 -r "Icons" -o ./icons --format pdf

# JPG
exfig fetch -f abc123 -r "Photos" -o ./photos --format jpg

# WebP with quality
exfig fetch -f abc123 -r "Images" -o ./images --format webp --webp-quality 90

# WebP lossless
exfig fetch -f abc123 -r "Images" -o ./images --format webp --webp-encoding lossless
```

### Penpot Fetch

```bash
# Fetch icons from Penpot as SVG
exfig fetch --source penpot -f "a1b2c3d4-..." -r "Icons / App" -o ./icons --format svg

# Fetch as PNG at 3x scale (SVG reconstructed, then rasterized via resvg)
exfig fetch --source penpot -f "a1b2c3d4-..." -r "Icons" -o ./icons --format png --scale 3

# From a shared library (use library file ID)
exfig fetch --source penpot -f "library-uuid" -r "Icons / Actions" -o ./icons --format svg

# Self-hosted Penpot instance
exfig fetch --source penpot --penpot-base-url https://penpot.mycompany.com/ \
  -f "uuid" -r "Icons" -o ./icons --format svg
```

> Set `PENPOT_ACCESS_TOKEN` environment variable (generate at Settings → Access Tokens).
> File ID is in the Penpot workspace URL: `?file-id=UUID`.

### Scale Options

```bash
# PNG at 2x scale
exfig fetch -f abc123 -r "Images" -o ./images --scale 2

# Note: Scale is ignored for vector formats (SVG, PDF)
```

### Filtering and Naming

```bash
# Filter specific images
exfig fetch -f abc123 -r "Images" -o ./images --filter "logo/*"

# Convert names to camelCase
exfig fetch -f abc123 -r "Images" -o ./images --name-style camelCase

# Custom regex replacement
exfig fetch -f abc123 -r "Images" -o ./images \
  --name-validate-regexp "^icon/(.*)$" \
  --name-replace-regexp "ic_$1"
```

### All Fetch Options

| Option               | Short | Description                            | Default |
| -------------------- | ----- | -------------------------------------- | ------- |
| `--file-id`          | `-f`  | Figma file ID (required)               | -       |
| `--frame`            | `-r`  | Figma frame name (required)            | -       |
| `--output`           | `-o`  | Output directory (required)            | -       |
| `--format`           | -     | Image format: png, svg, jpg, pdf, webp | png     |
| `--scale`            | -     | Scale factor (0.01-4.0)                | 3       |
| `--filter`           | -     | Filter pattern                         | -       |
| `--name-style`       | -     | Name style                             | -       |
| `--dark-mode-suffix` | -     | Suffix for dark variants               | -       |
| `--webp-encoding`    | -     | WebP encoding: lossy, lossless         | lossy   |
| `--webp-quality`     | -     | WebP quality (0-100)                   | 80      |

## Help and Version

```bash
# Show help
exfig --help
exfig colors --help

# Show version
exfig --version
```

## See Also

- <doc:BatchProcessing>
- <doc:DesignTokens>
- <doc:MCPServer>
- <doc:Configuration>
- <doc:DesignRequirements>
- <doc:iOS>
- <doc:Android>
- <doc:Flutter>
