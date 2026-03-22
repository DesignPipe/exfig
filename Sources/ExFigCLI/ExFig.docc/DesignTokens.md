# Design Tokens

Export design data from Figma as W3C Design Tokens for token pipelines and cross-tool interoperability.

@Metadata {
    @PageImage(purpose: icon, source: "tokens-icon", alt: "Design tokens")
    @PageColor(purple)
    @TitleHeading("Advanced")
}

## Overview

ExFig can export colors, typography, dimensions, and numbers as JSON following the
[W3C Design Tokens Community Group](https://design-tokens.github.io/community-group/format/)
(DTCG) format. This enables integration with tools like Tokens Studio, Style Dictionary, and
custom token pipelines.

## Export from Figma API

Use the `download` command to export tokens directly from Figma:

```bash
# Export colors as W3C Design Tokens
exfig download colors -o tokens/colors.json

# Export icons metadata with SVG URLs
exfig download icons -o tokens/icons.json --asset-format svg

# Export unified design tokens (colors + typography + dimensions + numbers)
exfig download tokens -o tokens/design-tokens.json

# Export all token types to a directory
exfig download all -o ./tokens/
```

### Download Subcommands

| Subcommand   | Description                                                       |
| ------------ | ----------------------------------------------------------------- |
| `colors`     | Export colors as JSON                                             |
| `icons`      | Export icon metadata with URLs                                    |
| `images`     | Export image metadata with URLs                                   |
| `typography` | Export text styles as JSON                                        |
| `tokens`     | Unified export (colors, typography, dimensions, numbers)          |
| `all`        | Export all types to a directory                                   |

### Download Options

| Option           | Short | Description                      | Default |
| ---------------- | ----- | -------------------------------- | ------- |
| `--output`       | `-o`  | Output file path                 | varies  |
| `--format`       | `-f`  | Output format: w3c, raw          | w3c     |
| `--compact`      | -     | Output minified JSON             | false   |
| `--asset-format` | -     | Image format: svg, png, pdf, jpg | svg     |
| `--scale`        | -     | Scale for raster formats         | 3       |
| `--w3c-version`  | -     | W3C format version: v1, v2025   | v2025   |

## W3C Format Versions

ExFig supports two W3C DTCG format versions:

- **v2025** (default) — Current spec. Colors as `{ space, channels, alpha }` objects.
- **v1** — Legacy format. Colors as hex strings (`#RRGGBB`).

```bash
# Default: v2025 format
exfig download colors -o tokens.json

# Legacy hex format
exfig download colors -o tokens.json --w3c-version v1
```

## Local Token Files

ExFig can import from local `.tokens.json` files (e.g., exported from Tokens Studio) without
a Figma API token:

```bash
# Inspect a token file
exfig tokens info ./tokens.json

# Re-export with filtering
exfig tokens convert ./tokens.json -o out.json

# Filter by group and type
exfig tokens convert ./tokens.json --group "Brand" --type color -o brand-colors.json
```

### Using Local Tokens in Config

Colors entries support `tokensFile` to import from a local file instead of fetching from Figma:

```pkl
colors = new Listing {
  new iOS.ColorsEntry {
    tokensFile = "./design-tokens/colors.tokens.json"
    // ... output settings
  }
}
```

This is useful for teams that manage tokens in version control or use Tokens Studio.

## Raw Format

Export the raw Figma API response for debugging or custom processing:

```bash
exfig download colors -o debug/colors.json --format raw
```

## See Also

- <doc:Usage>
- <doc:Configuration>
- <doc:CICDIntegration>
