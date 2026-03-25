# CI/CD Integration

Automate design exports in your continuous integration pipeline.

@Metadata {
    @PageImage(purpose: icon, source: "cicd-icon", alt: "CI/CD integration")
    @PageColor(purple)
    @TitleHeading("Advanced")
}

## Overview

ExFig is designed for headless environments. It provides quiet mode, structured JSON reports,
meaningful exit codes, and a ready-made GitHub Action for common workflows.

## GitHub Action

The fastest way to integrate ExFig into CI is [exfig-action](https://github.com/DesignPipe/exfig-action):

```yaml
- uses: DesignPipe/exfig-action@v1
  with:
    figma_token: ${{ secrets.FIGMA_TOKEN }}
    command: batch exfig.pkl
    cache: true
```

The action handles installation, caching of the ExFig binary, and token setup.

### Action Inputs

| Input          | Description                      | Default       |
| -------------- | -------------------------------- | ------------- |
| `figma_token`  | Figma Personal Access Token      | (required)    |
| `command`      | ExFig command to run             | `batch`       |
| `cache`        | Enable version tracking          | `false`       |
| `config`       | Path to config file or directory | `exfig.pkl`   |

## Manual Setup

For non-GitHub CI systems or custom workflows:

```bash
# Install ExFig
brew install designpipe/tap/exfig

# Run with quiet mode and JSON report
exfig batch exfig.pkl --quiet --cache --report results.json
```

## Output Modes

| Flag        | Behavior                                       |
| ----------- | ---------------------------------------------- |
| (default)   | Progress indicators, colors, ETA               |
| `--verbose` | Detailed logging for debugging                 |
| `--quiet`   | Minimal output — errors only, no progress bars |

In CI, use `--quiet` to keep logs clean. Pair with `--report` for structured output.

## Exit Codes

| Code | Meaning                          |
| ---- | -------------------------------- |
| 0    | Success                          |
| 1    | Export error (API failure, etc.) |

## Version Tracking in CI

Enable `--cache` to skip unchanged exports. ExFig compares the Figma file version against a local
cache file and skips the export if nothing changed since the last run.

```yaml
- uses: DesignPipe/exfig-action@v1
  with:
    figma_token: ${{ secrets.FIGMA_TOKEN }}
    command: batch exfig.pkl
    cache: true

# Cache the version tracking file between runs
- uses: actions/cache@v4
  with:
    path: .exfig-versions.json
    key: exfig-versions-${{ github.ref }}
```

## Cross-Platform CI

ExFig CI runs on macOS, Linux (Ubuntu 22.04), and Windows. On Windows:

- Requires Swift 6.3+ (use `compnerd/gha-setup-swift` action)
- MCP server is excluded (swift-nio incompatible)
- XcodeProj integration is excluded
- SPM cache is supported via standard `actions/cache`

```yaml
# Windows CI example
- uses: compnerd/gha-setup-swift@v0.3.0
  with:
    branch: swift-6.3-branch
    tag: DEVELOPMENT-SNAPSHOT-2025-03-09-a

- name: Build
  run: swift build
```

## See Also

- <doc:BatchProcessing>
- <doc:Usage>
