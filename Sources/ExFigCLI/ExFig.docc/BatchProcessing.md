# Batch Processing

Export all resource types from one or more configs in a single run.

@Metadata {
    @PageImage(purpose: icon, source: "batch-icon", alt: "Batch processing")
    @PageColor(purple)
    @TitleHeading("Advanced")
}

## Overview

The `batch` command is the primary way to use ExFig in production. It exports colors, icons, images,
and typography from a unified PKL config — or processes multiple configs in parallel with shared rate
limiting.

## Single-Config Batch

Export all resource types defined in one config file:

```bash
# Export everything from a single config
exfig batch exfig.pkl

# With version tracking (skip unchanged files)
exfig batch exfig.pkl --cache

# With rate limiting
exfig batch exfig.pkl --cache --rate-limit 25
```

> Note: The `batch` command takes config paths as **positional arguments**, not via the `-i` flag.

## Multi-Config Batch

Process multiple configuration files in parallel:

```bash
# All configs in a directory
exfig batch ./configs/

# Specific config files
exfig batch ios-app.pkl android-app.pkl flutter-app.pkl

# Custom parallelism (default: 3 concurrent configs)
exfig batch ./configs/ --parallel 5
```

> Note: Directory scanning is non-recursive. Use shell globbing for nested configs: `./configs/*/*.pkl`

## Parallelism and Rate Limiting

Batch mode uses shared rate limiting across all concurrent configs. This prevents hitting Figma API
limits when processing multiple files simultaneously.

| Option          | Description                     | Default |
| --------------- | ------------------------------- | ------- |
| `--parallel`    | Maximum concurrent configs      | 3       |
| `--rate-limit`  | Figma API requests per minute   | 10      |
| `--max-retries` | Maximum retry attempts          | 4       |

## Error Handling

### Fail-Fast Mode

Stop processing immediately when any config fails:

```bash
exfig batch ./configs/ --fail-fast
```

Without `--fail-fast`, batch continues processing remaining configs and reports all failures at the end.

### Checkpoint and Resume

Long-running exports create checkpoints for recovery after interruption:

```bash
# Resume from the last successful config
exfig batch ./configs/ --resume
```

Checkpoints are stored in `.exfig-checkpoint.json`, expire after 24 hours, and are deleted on
successful completion.

## JSON Reports

Generate a machine-readable report for CI/CD integration:

```bash
exfig batch ./configs/ --report results.json
```

The report includes per-config status, export counts, timing, and any errors encountered.

## Version Tracking

Skip unchanged exports using Figma file version tracking:

```bash
# Enable version tracking
exfig batch exfig.pkl --cache

# Force re-export and update cache
exfig batch exfig.pkl --force

# Per-node change detection (experimental)
exfig batch exfig.pkl --cache --experimental-granular-cache
```

> Note: Figma file versions change when a library is **published**, not on every auto-save.

## All Batch Options

| Option                            | Description                              | Default |
| --------------------------------- | ---------------------------------------- | ------- |
| `--parallel`                      | Maximum concurrent configs               | 3       |
| `--fail-fast`                     | Stop processing on first error           | false   |
| `--rate-limit`                    | Figma API requests per minute            | 10      |
| `--max-retries`                   | Maximum retry attempts                   | 4       |
| `--resume`                        | Resume from previous checkpoint          | false   |
| `--report`                        | Path to write JSON report                | -       |
| `--cache`                         | Enable version tracking                  | false   |
| `--force`                         | Force re-export, update cache            | false   |
| `--experimental-granular-cache`   | Per-node change detection                | false   |

## See Also

- <doc:Usage>
- <doc:Configuration>
- <doc:CICDIntegration>
