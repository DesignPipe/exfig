---
paths:
  - "Tests/**"
---

# Testing and Workflow

This rule covers testing guidelines, commit guidelines, and configuration reference.

## Testing Guidelines

Test targets mirror source modules:

| Target               | Tests for                      |
| -------------------- | ------------------------------ |
| `ExFigTests`         | CLI commands, loaders, writers |
| `ExFigCoreTests`     | Domain models, processors      |
| `XcodeExportTests`   | iOS export output              |
| `AndroidExportTests` | Android export output          |
| `FlutterExportTests` | Flutter export output          |
| `SVGKitTests`        | SVG parsing, code generation   |

Run specific tests:

```bash
./bin/mise run test:filter ExFigTests              # By test target
./bin/mise run test:filter SVGParserTests          # By test class
./bin/mise run test:file Tests/SVGKitTests/SVGParserTests.swift  # By file
```

## Commit Guidelines

Format: `<type>(<scope>): <description>`

**Types:** `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `chore`, `ci`

**Scopes:** `colors`, `icons`, `images`, `typography`, `api`, `cli`, `ios`, `android`, `flutter`

```bash
feat(cli): add download command for config-free image downloads
fix(icons): handle SVG with missing viewBox
docs: update naming style documentation
```

**Pre-commit requirements:**

```bash
./bin/mise run setup       # Install hk git hooks (one-time)
./bin/mise run format      # Run all formatters (hk fix --all)
./bin/mise run lint        # Must pass (may have issues on Linux)
```

## Configuration Reference

Full config spec: `CONFIG.md`

Generate starter config:

```bash
exfig init -p ios
exfig init -p android
```
