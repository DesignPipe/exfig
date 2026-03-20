# ExFig

[![CI](https://github.com/DesignPipe/exfig/actions/workflows/ci.yml/badge.svg)](https://github.com/DesignPipe/exfig/actions/workflows/ci.yml)
[![Release](https://github.com/DesignPipe/exfig/actions/workflows/release.yml/badge.svg)](https://github.com/DesignPipe/exfig/actions/workflows/release.yml)
[![Docs](https://github.com/DesignPipe/exfig/actions/workflows/deploy-docc.yml/badge.svg)](https://DesignPipe.github.io/exfig/documentation/exfig)
![Coverage](https://img.shields.io/badge/coverage-50.65%25-yellow)
[![License](https://img.shields.io/github/license/DesignPipe/exfig.svg)](LICENSE)

Export colors, typography, icons, and images from Figma to Xcode, Android Studio, Flutter, and Web projects — automatically.

## The Problem

- Figma has no "Export to Xcode" button. You copy hex codes by hand, one by one.
- Every color change means updating files across 3 platforms manually.
- Dark mode variant? An afternoon spent on light/dark pairs and @1x/@2x/@3x PNGs.
- Android gets XML. iOS gets xcassets. Flutter gets Dart. Someone maintains all three.
- Design and code drift apart because nobody runs the manual export often enough.

## Who Is This For?

**iOS developer** — You have 100+ colors and 200+ icons. ExFig generates Color Sets with light/dark/high-contrast variants, PDF vectors in `.xcassets`, and type-safe SwiftUI + UIKit extensions.

**Android developer** — Your team uses Compose but legacy views need XML. ExFig generates both: `colors.xml` for views, Compose `Color` objects, and `VectorDrawable` icons with pathData validation.

**Flutter developer** — You need dark mode icon variants and `@2x`/`@3x` image scales. ExFig exports SVG icons with dark suffixes, raster images with scale directories, and Dart constants.

**Design Systems lead** — One Figma file feeds four platforms. ExFig's unified PKL config exports everything from a single `exfig batch` run. One CI pipeline, one source of truth.

**CI/CD engineer** — Quiet mode, JSON reports, exit codes, version tracking, and checkpoint/resume. The [GitHub Action](https://github.com/DesignPipe/exfig-action) handles installation and caching.

## Quick Start

```bash
# 1. Install
brew install designpipe/tap/exfig

# 2. Set Figma token
export FIGMA_PERSONAL_TOKEN=your_token_here

# 3a. Quick one-off export (interactive wizard)
exfig fetch

# 3b. Or generate config for full pipeline
exfig init -p ios
exfig batch exfig.pkl
```

See the [Getting Started guide](https://DesignPipe.github.io/exfig/documentation/exfig/gettingstarted) for detailed setup, including Mint, mise, and building from source.

## GitHub Action

```yaml
- uses: DesignPipe/exfig-action@v1
  with:
    figma_token: ${{ secrets.FIGMA_TOKEN }}
    command: batch exfig.pkl
    cache: true
```

## Documentation

Full documentation — platform guides, configuration reference, batch processing, design tokens, custom templates, and MCP server — is available at **[DesignPipe.github.io/exfig](https://DesignPipe.github.io/exfig/documentation/exfig)**.

Configuration reference: [CONFIG.md](CONFIG.md).

## Contributing

See the [Development Guide](https://DesignPipe.github.io/exfig/documentation/exfig/development) for setup, testing, and code style.

## License

MIT. See [LICENSE](LICENSE).

---

<sub>Originally inspired by [figma-export](https://github.com/RedMadRobot/figma-export).</sub>
