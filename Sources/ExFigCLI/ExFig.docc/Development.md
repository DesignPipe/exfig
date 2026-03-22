# Development

Guide for contributing to ExFig development.

## Overview

ExFig is built with Swift Package Manager and supports macOS 13.0+ and Linux (Ubuntu 22.04). This guide covers setting up
your development environment and contributing to the project.

## Requirements

- macOS 13.0 or later, or Linux (Ubuntu 22.04)
- Xcode 16.0 or later (or Swift 6.2+ toolchain)
- [mise](https://mise.jdx.dev/) (optional, for task running)

## Getting Started

### Clone the Repository

```bash
git clone https://github.com/DesignPipe/exfig.git
cd ExFig
```

### Build the Project

```bash
# Using mise
mise run build

# Using Swift directly
swift build
```

### Run Tests

```bash
# Using mise
mise run test

# Using Swift directly
swift test
```

### Run the CLI

```bash
# Debug build
.build/debug/exfig --help

# Release build
swift build -c release
.build/release/exfig --help
```

## Project Structure

```
Sources/
├── ExFigCLI/           # CLI commands and main executable
│   ├── Subcommands/    # CLI command implementations
│   ├── Loaders/        # Figma data loaders
│   ├── Input/          # Configuration parsing
│   ├── Output/         # File writers
│   ├── TerminalUI/     # Progress bars, spinners
│   ├── Cache/          # Version tracking
│   ├── Batch/          # Batch processing
│   ├── Source/         # Design source implementations (Figma, Penpot, TokensFile)
│   └── MCP/            # Model Context Protocol server
├── ExFigCore/          # Domain models and processors
├── ExFigConfig/        # PKL config parsing, evaluation
├── ExFig-iOS/          # iOS platform plugin
├── ExFig-Android/      # Android platform plugin
├── ExFig-Flutter/      # Flutter platform plugin
├── ExFig-Web/          # Web platform plugin
├── XcodeExport/        # iOS export (xcassets, Swift)
├── AndroidExport/      # Android export (XML, Compose, VectorDrawable)
├── FlutterExport/      # Flutter export (Dart, assets)
├── WebExport/          # Web export (CSS, JSX icons)
└── JinjaSupport/       # Shared Jinja2 template rendering

Tests/
├── ExFigTests/
├── ExFigCoreTests/
├── XcodeExportTests/
├── AndroidExportTests/
├── FlutterExportTests/
├── WebExportTests/
├── JinjaSupportTests/
├── ExFig-iOSTests/
├── ExFig-AndroidTests/
├── ExFig-FlutterTests/
└── ExFig-WebTests/
```

## Available Tasks

Using mise:

```bash
# Build
mise run build          # Debug build
mise run build:release  # Release build

# Test
mise run test           # All tests
mise run test:filter NAME  # Specific test target

# Code Quality
mise run format         # Format Swift code
mise run format-md      # Format Markdown
mise run lint           # Run SwiftLint

# Setup
mise run setup          # Install development tools
```

## Code Style

### SwiftLint

The project uses SwiftLint for code style enforcement:

```bash
mise run lint
```

### Formatting

Format code before committing:

```bash
mise run format
mise run format-md
```

### Key Rules

- Use `Data("string".utf8)` instead of `"string".data(using: .utf8)!`
- Add `// swiftlint:disable:next force_try` before `try!` in tests
- Files over 400 lines should have `// swiftlint:disable file_length`

## Adding a New CLI Command

1. Create command file in `Sources/ExFigCLI/Subcommands/`:

```swift
import ArgumentParser

struct NewCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "new",
        abstract: "Description of the command"
    )

    @OptionGroup
    var globalOptions: GlobalOptions

    @OptionGroup
    var cacheOptions: CacheOptions

    func run() async throws {
        // Implementation
    }
}
```

2. Register in `ExFigCommand.swift`:

```swift
static let configuration = CommandConfiguration(
    subcommands: [
        // ... existing commands
        NewCommand.self
    ]
)
```

## Adding a Figma API Endpoint

FigmaAPI is an external package ([swift-figma-api](https://github.com/DesignPipe/swift-figma-api)). See its repository for endpoint patterns and contribution guidelines.

## Modifying Templates

Templates use Jinja2 syntax and are located in `Sources/*/Resources/`:

- `XcodeExport/Resources/` - iOS templates
- `AndroidExport/Resources/` - Android templates
- `FlutterExport/Resources/` - Flutter templates
- `WebExport/Resources/` - Web templates

After modifying templates, update corresponding tests.

## Testing

### Unit Tests

Each module has a corresponding test target:

```bash
# Run all tests
swift test

# Run specific test target
swift test --filter ExFigCoreTests
```

### Test Fixtures

API response fixtures are in `Tests/*/Fixtures/`:

```swift
let fixture = try TestFixture.load("colors.json")
```

### Test Helpers

Create test objects using factory methods:

```swift
extension SomeType {
    static func make(param: String = "default") -> SomeType {
        // Create test instance
    }
}
```

## Commit Guidelines

Format: `<type>(<scope>): <description>`

**Types:**

- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation
- `refactor` - Code refactoring
- `perf` - Performance improvement
- `test` - Tests
- `chore` - Maintenance
- `ci` - CI/CD changes

**Scopes:**

- `colors`, `icons`, `images`, `typography` - Resource types
- `api` - Figma API
- `cli` - CLI commands
- `ios`, `android`, `flutter` - Platform exports

**Examples:**

```bash
feat(cli): add download command for config-free exports
fix(icons): handle SVG with missing viewBox
docs: update naming style documentation
refactor(api): simplify rate limiting logic
```

## Pull Request Process

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and linting
5. Submit a pull request

### PR Checklist

- [ ] Tests pass (`mise run test`)
- [ ] Code is formatted (`mise run format`)
- [ ] Linting passes (`mise run lint`)
- [ ] Documentation updated if needed
- [ ] Commit messages follow conventions

## Troubleshooting

### Build Fails

```bash
swift package clean
swift build
```

### Tests Fail

- Check `FIGMA_PERSONAL_TOKEN` is set for integration tests
- Some tests require network access

### Formatting Issues

```bash
mise run setup  # Install tools
mise run format
```

## See Also

- <doc:Configuration>
- <doc:CustomTemplates>
