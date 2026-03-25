# Change: Add Windows Platform Support

## Why

Swift officially supports Windows since version 5.3, but ExFig currently only builds on macOS and Linux. Windows is a
major development platform, and supporting it would significantly expand the tool's reach for teams using Android Studio
or Flutter on Windows.

## What Changes

- **BREAKING**: Replace FoundationXML usage with cross-platform XML parser (XMLDocument crashes on Windows)
- Add Windows-specific conditional compilation for POSIX APIs (`isatty`, `STDOUT_FILENO`)
- Make XcodeProj dependency optional (not needed on Windows)
- Add Windows CI pipeline for build and test validation
- Verify/fix libwebp and libpng native library compatibility on Windows
- Handle Windows path conventions (backslashes, drive letters)

## Impact

- Affected specs: `platform-support` (new capability)
- Affected code:
  - `Sources/SVGKit/SVGParser.swift` - XMLDocument/XMLElement usage
  - `Sources/ExFig/TerminalUI/TTYDetector.swift` - POSIX TTY detection
  - `Sources/FigmaAPI/*.swift` - FoundationNetworking imports
  - `Sources/ExFig/Output/*.swift` - File path handling
  - `Package.swift` - Conditional dependencies
  - `.github/workflows/` - CI configuration

## Risks

- FoundationXML replacement may require significant refactoring of SVGParser
- Native libraries (libwebp, libpng) may not have Windows binaries readily available
- XcodeProj is deeply integrated; making it optional requires careful feature gating
