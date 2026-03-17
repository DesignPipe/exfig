# Usage

Command-line interface reference and common usage patterns.

## Overview

ExFig provides commands for exporting colors, icons, images, and typography from Figma to native platform resources.

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

### Enable via CLI

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

## Batch Processing

Export all resource types from a single unified config:

```bash
# Export colors, icons, images, typography from one config
exfig batch exfig.pkl

# With version tracking
exfig batch exfig.pkl --cache

# With rate limiting
exfig batch exfig.pkl --cache --rate-limit 25
```

Process multiple configuration files in parallel:

```bash
# Process all configs in a directory
exfig batch ./configs/

# Process specific config files
exfig batch ios-app.pkl android-app.pkl flutter-app.pkl

# With custom parallelism (default: 3)
exfig batch ./configs/ --parallel 5

# Stop on first error
exfig batch ./configs/ --fail-fast

# Generate JSON report
exfig batch ./configs/ --report batch-results.json

# Resume from checkpoint
exfig batch ./configs/ --resume
```

> Note: The `batch` command takes config paths as **positional arguments**, not via `-i` flag.

| Option          | Description                     | Default |
| --------------- | ------------------------------- | ------- |
| `--parallel`    | Maximum concurrent configs      | 3       |
| `--fail-fast`   | Stop processing on first error  | false   |
| `--rate-limit`  | Figma API requests per minute   | 10      |
| `--max-retries` | Maximum retry attempts          | 4       |
| `--resume`      | Resume from previous checkpoint | false   |
| `--report`      | Path to write JSON report       | -       |

> Note: Directory scanning is non-recursive. Use shell globbing for nested configs: `./configs/*/*.pkl`

## JSON Export (Design Tokens)

Export Figma data as JSON for design token pipelines:

```bash
# Export colors as W3C Design Tokens
exfig download colors -o tokens/colors.json

# Export raw Figma API response
exfig download colors -o debug/colors.json --format raw

# Export icons with SVG URLs
exfig download icons -o tokens/icons.json --asset-format svg

# Export unified design tokens (colors + typography + dimensions + numbers)
exfig download tokens -o tokens/design-tokens.json

# Export all token types
exfig download all -o ./tokens/
```

### Download Subcommands

| Subcommand   | Description                     |
| ------------ | ------------------------------- |
| `colors`     | Export colors as JSON                                              |
| `icons`      | Export icon metadata with URLs                                     |
| `images`     | Export image metadata with URLs                                    |
| `typography` | Export text styles as JSON                                         |
| `tokens`     | Export unified design tokens (colors, typography, dimensions, numbers) |
| `all`        | Export all types to a directory                                    |

### Download Options

| Option           | Short | Description                      | Default |
| ---------------- | ----- | -------------------------------- | ------- |
| `--output`       | `-o`  | Output file path                 | varies  |
| `--format`       | `-f`  | Output format: w3c, raw          | w3c     |
| `--compact`      | -     | Output minified JSON             | false   |
| `--asset-format` | -     | Image format: svg, png, pdf, jpg | svg     |
| `--scale`        | -     | Scale for raster formats         | 3       |
| `--w3c-version`  | -     | W3C format version: v1, v2025   | v2025   |

## Quick Fetch

Download images without a configuration file:

```bash
# Download PNG images at 3x scale
exfig fetch --file-id YOUR_FILE_ID --frame "Illustrations" --output ./images

# Using short options
exfig fetch -f YOUR_FILE_ID -r "Icons" -o ./icons
```

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

## MCP Server (AI Agent Integration)

Start an MCP (Model Context Protocol) server for AI agents like Claude Code, Cursor, or Codex:

```bash
exfig mcp
```

The server runs over stdin/stdout using JSON-RPC. All CLI output goes to stderr.

### Available Tools

| Tool | Description | Requires Token |
| ---- | ----------- | -------------- |
| `exfig_validate` | Validate PKL config | No |
| `exfig_tokens_info` | Inspect .tokens.json | No |
| `exfig_inspect` | List Figma resources | Yes |

### Client Configuration

Add to your `.mcp.json` or MCP client config:

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

### Resources

The server exposes PKL schemas (`exfig://schemas/*.pkl`) and starter config templates
(`exfig://templates/{ios,android,flutter,web}`).

### Prompts

| Prompt | Description |
| ------ | ----------- |
| `setup-config` | Guide AI through creating exfig.pkl |
| `troubleshoot-export` | Diagnose export errors |

## Help and Version

```bash
# Show help
exfig --help
exfig colors --help

# Show version
exfig --version
```

## See Also

- <doc:Configuration>
- <doc:DesignRequirements>
- <doc:iOS>
- <doc:Android>
- <doc:Flutter>
