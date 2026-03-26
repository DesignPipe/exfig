---
paths:
  - "Sources/ExFigCLI/Cache/**"
---

# Granular Node-Level Cache

This rule covers the experimental granular caching system for per-node change detection.

## Overview

When `--experimental-granular-cache` is used with `--cache`, the system tracks per-node content hashes to skip unchanged
assets even when the file version changes:

```bash
# Enable granular tracking
exfig icons --cache --experimental-granular-cache
exfig images --cache --experimental-granular-cache
exfig batch --cache --experimental-granular-cache

# Force full re-export (clears node hashes)
exfig icons --cache --experimental-granular-cache --force
exfig batch --cache --experimental-granular-cache --force
```

## How It Works

1. Compute FNV-1a 64-bit hash of each node's visual properties (fills, strokes, effects, rotation, children - recursive)
2. Compare hashes with cached values from previous export
3. Export only nodes whose hashes differ
4. Update cache with new hashes after successful export

## Hashed Properties

**Node properties:**
- `name`, `type`, `fills`, `strokes`, `strokeWeight`, `strokeAlign`, `strokeJoin`, `strokeCap`
- `effects`, `opacity`, `blendMode`, `clipsContent`, `rotation`, `children`

**Paint (fills/strokes):**
- `type`, `blendMode`, `color`, `opacity`, `gradientStops`

**Effect:**
- `type`, `radius`, `spread`, `offset`, `color`, `visible`

**Excluded properties:**
- `boundVariables`, `absoluteBoundingBox`, `absoluteRenderBounds`, `constraints`, `interactions`

## Key Files

- `Sources/ExFigCLI/Cache/GranularCacheManager.swift` - Per-node hash tracking
- `Sources/ExFigCLI/Cache/NodeHasher.swift` - FNV-1a hash computation with recursive children
- `Sources/ExFigCLI/Cache/FNV1aHasher.swift` - Pure Swift FNV-1a 64-bit implementation
- `Sources/FigmaAPI/Model/NodeHashableProperties.swift` - Hashable visual properties struct
- `Sources/FigmaAPI/Model/FloatNormalization.swift` - Float normalization for stable hashing
- `Sources/ExFigCLI/Batch/SharedGranularCache.swift` - Shared cache struct for batch mode
- `Sources/ExFigCLI/Batch/BatchContext.swift` - Unified TaskLocal storage for all batch data

## Batch Mode Behavior

When using granular cache in batch mode (`exfig batch --cache --experimental-granular-cache`), the cache is shared
across all parallel config workers to avoid race conditions:

1. Cache is loaded once before batch execution and shared via `@TaskLocal`
2. Workers read from shared cache (no disk I/O during parallel execution)
3. Workers defer cache saves by passing `batchMode: true` to `ImageTrackingManager.updateCache()`
4. Workers return both `fileVersions` and computed hashes in `ExportStats`
5. After batch completes, file versions are merged first, then all hashes are merged and saved once to disk
6. Batch summary shows aggregated granular cache stats: `Granular cache: N nodes skipped, M nodes exported`

This pattern ensures:

- No race conditions from parallel cache writes during execution
- File version updates don't overwrite nodeHashes prematurely
- Multiple configs referencing the same Figma file all benefit from granular cache tracking
- Single atomic save at the end contains both file versions AND nodeHashes

## Known Limitations

- Config changes (output path, format, scale) are not detected - use `--force` when config changes
- First run with granular cache populates hashes, subsequent runs benefit from tracking
- Uses ~25KB per 1000 nodes in cache file
- Output directory is not cleared - only changed files are overwritten, deleted assets remain on disk

## Graceful Degradation

`GranularCacheManager.filterChangedComponents()` catches node fetch errors (Access denied, rate limits)
and returns ALL components with empty hashes — export proceeds without filtering rather than failing.
This matches the pre-fetch fallback behavior in `Batch.preFetchNodesIfNeeded()`.

## Performance

| Scenario                        | Without Granular | With Granular | Savings |
| ------------------------------- | ---------------- | ------------- | ------- |
| 100 illustrations, 0 changed    | 60s full export  | <1s (skip)    | 98%     |
| 100 illustrations, 3 changed    | 60s full export  | ~3s selective | 95%     |
| 500 icons, 5 changed            | 45s full export  | ~5s selective | 89%     |
| All assets changed (worst case) | 45s full export  | 45s + ~55ms   | ~0%     |
