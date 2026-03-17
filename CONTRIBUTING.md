# Contributing to ExFig

Thank you for your interest in contributing to ExFig!

## Quick Links

- [Development Guide](.github/docs/development.md) - Complete setup and contribution guidelines
- [Code of Conduct](CODE_OF_CONDUCT.md) - Community standards
- [Security Policy](SECURITY.md) - Reporting vulnerabilities

## Getting Started

1. Fork and clone the repository
2. Install dependencies: `./bin/mise install`
3. Build: `./bin/mise run build`
4. Test: `./bin/mise run test`

Git hooks are auto-configured via `mise` when entering the project directory.

## Before Submitting

Ensure all checks pass:

```bash
./bin/mise run format      # Format Swift code
./bin/mise run format-md   # Format markdown
./bin/mise run lint        # Run linter
./bin/mise run test        # Run tests
```

## Code Coverage

Check current test coverage:

```bash
./bin/mise run coverage        # Show coverage report
./bin/mise run coverage:badge  # Update badge in README.md
```

Note: The coverage badge is updated manually, not automatically by CI.

## Commit Message Format

We use [Conventional Commits](https://www.conventionalcommits.org/) to generate changelogs automatically.

### Format

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types

| Type | Description | |------|-------------| | `feat` | New feature | | `fix` | Bug fix | | `docs` | Documentation only
| | `style` | Code style (formatting, no logic change) | | `refactor` | Code refactoring | | `perf` | Performance
improvement | | `test` | Adding or updating tests | | `chore` | Maintenance tasks | | `ci` | CI/CD changes | | `revert`
| Revert a previous commit |

### Examples

```bash
feat: add WebP image export support
fix(icons): handle SVG with missing viewBox
docs: update installation instructions
refactor(api): simplify Figma client error handling
test(colors): add tests for high contrast mode
chore: update dependencies
```

### Scope (optional)

Common scopes: `colors`, `icons`, `images`, `typography`, `api`, `cli`, `mcp`, `ios`, `android`

## Pull Request Process

1. Create a feature branch from `main`
2. Make your changes with clear, focused commits following the commit format above
3. Ensure all tests pass and linting is clean
4. Submit a pull request with a clear description

For detailed guidelines, see the [Development Guide](.github/docs/development.md).
