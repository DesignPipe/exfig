# Design: Windows Platform Support

## Context

ExFig is a CLI tool that exports design assets from Figma to Xcode, Android Studio, and Flutter projects. While Swift
supports Windows since 5.3, and the tool already has Linux support, Windows compatibility requires addressing several
platform-specific issues:

1. **FoundationXML crash** - XMLDocument causes compiler crash on Windows (Swift issue #77047)
2. **POSIX APIs** - `isatty()`, `STDOUT_FILENO` need Windows equivalents
3. **XcodeProj dependency** - Apple-specific, not needed on Windows
4. **Native libraries** - libwebp/libpng need Windows binaries
5. **Path handling** - Backslashes and drive letters

### Stakeholders

- Developers using Android Studio or Flutter on Windows
- CI/CD pipelines running on Windows

## Goals / Non-Goals

### Goals

- Build and run ExFig on Windows 10/11 with Swift 6.0+
- Support all export targets except Xcode-specific features
- Maintain feature parity with Linux for Android and Flutter exports
- Enable Windows CI testing

### Non-Goals

- Xcode project manipulation on Windows (XcodeProj remains macOS/Linux only)
- Windows GUI or installer (CLI only)
- Windows ARM64 support (x64 only initially)

## Decisions

### Decision 1: XML Parser Replacement

**What**: Replace FoundationXML with a cross-platform alternative for SVG parsing.

**Options considered**:

| Option             | Pros                                       | Cons                             |
| ------------------ | ------------------------------------------ | -------------------------------- |
| XMLCoder           | Pure Swift, well-maintained, Codable-based | Different API, requires rewrite  |
| SwiftyXMLParser    | Lightweight, easy migration                | Less maintained                  |
| Custom SAX parser  | Full control, minimal dependencies         | Significant effort               |
| Wait for Swift fix | No code changes                            | Unknown timeline, blocks Windows |

**Decision**: Use **XMLCoder** for SVG parsing.

- Actively maintained by CoreOffice
- Codable-based approach fits Swift patterns
- Works on all Swift platforms including Windows

### Decision 2: Conditional XcodeProj

**What**: Make XcodeProj dependency optional via conditional compilation.

**Approach**:

```swift
// Package.swift
#if !os(Windows)
.product(name: "XcodeProj", package: "XcodeProj"),
#endif

// Code
#if canImport(XcodeProj)
import XcodeProj
// Xcode-specific functionality
#endif
```

**Rationale**: XcodeProj is only useful for iOS exports. On Windows, users will export for Android/Flutter only.

### Decision 3: TTY Detection

**What**: Replace POSIX TTY detection with cross-platform implementation.

**Approach**:

```swift
#if os(Windows)
import WinSDK

enum TTYDetector {
    static var isTTY: Bool {
        let handle = GetStdHandle(STD_OUTPUT_HANDLE)
        var mode: DWORD = 0
        return GetConsoleMode(handle, &mode)
    }
}
#else
// Existing POSIX implementation
#endif
```

### Decision 4: Native Libraries

**What**: Ensure libwebp and libpng work on Windows.

**Approach**:

1. Check if `the-swift-collective/libwebp` supports Windows (claims cross-platform)
2. If not, use vcpkg or pre-built Windows binaries
3. Add fallback to skip WebP optimization if library unavailable

### Decision 5: Path Handling

**What**: Normalize file paths for Windows compatibility.

**Approach**:

- Use `URL` and `FileManager` APIs instead of string path manipulation
- Use `URL.path(percentEncoded:)` for consistent path representation
- Avoid hardcoded `/` separators

## Risks / Trade-offs

| Risk                         | Impact                     | Mitigation                         |
| ---------------------------- | -------------------------- | ---------------------------------- |
| XMLCoder API differences     | Medium - SVGParser rewrite | Create adapter layer               |
| libwebp Windows issues       | Low - optional feature     | Graceful fallback                  |
| Swift Windows toolchain bugs | Medium - could block       | Pin to stable Swift version        |
| CI cost increase             | Low                        | Use GitHub Actions Windows runners |

## Migration Plan

### Phase 1: Foundation (No Breaking Changes)

1. Add `#if os(Windows)` guards for POSIX APIs
2. Make XcodeProj import conditional
3. Add Windows to CI matrix (expect failures initially)

### Phase 2: XML Parser Migration

1. Create XMLParserProtocol abstraction
2. Implement XMLCoder-based parser
3. Migrate SVGParser to use abstraction
4. Remove FoundationXML dependency

### Phase 3: Native Libraries

1. Test libwebp/libpng on Windows
2. Add vcpkg integration if needed
3. Add fallback paths for missing libraries

### Phase 4: Validation

1. Run full test suite on Windows
2. Document Windows-specific limitations
3. Update README and installation docs

### Rollback

- Each phase is independently revertible
- Feature flags can disable Windows-specific code paths
- No database or state migrations required

## Open Questions

1. Should we support Windows ARM64 in the future?
2. Is there demand for a Windows installer (MSI/MSIX)?
3. Should we provide pre-built Windows binaries on GitHub releases?
