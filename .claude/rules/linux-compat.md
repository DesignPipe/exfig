# Linux & Windows Compatibility

This rule covers Linux- and Windows-specific workarounds and differences from macOS.

The project builds on Linux (Ubuntu 22.04 LTS / Jammy) and Windows (Swift 6.3). Key differences from macOS:

## Required Import for Networking

```swift
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
```

## Foundation API Workarounds

| API                              | Issue on Linux              | Workaround                                    |
| -------------------------------- | --------------------------- | --------------------------------------------- |
| `XMLElement.elements(forName:)`  | Fails with default xmlns    | Use manual iteration with `localName`         |
| `XMLElement.attribute(forName:)` | Returns nil with xmlns      | Iterate `attributes` manually                 |
| `NSPredicate` with LIKE          | Not supported               | Convert wildcard to regex                     |
| `FileManager.replaceItemAt`      | Requires destination exist  | Use `removeItem` + `copyItem`                 |
| `stdout` global                  | Swift 6 concurrency warning | Use `FileHandle.standardOutput.synchronize()` |

## Running Tests on Linux

```bash
# Build tests separately, then run — avoids hangs from concurrent build + test execution
swift build --build-tests
swift test --skip-build --parallel
```

## Skip Tests on Linux

```swift
func testSomePngOperation() throws {
    #if os(Linux)
        throw XCTSkip("Skipped on Linux due to libpng issues")
    #endif
    // ... test code
}
```

## Platform-Specific Features

| Feature      | macOS        | Linux                    | Windows                  |
| ------------ | ------------ | ------------------------ | ------------------------ |
| HEIC encoding| ImageIO      | Falls back to PNG        | Falls back to PNG        |
| libpng tests | Full support | Build tests first        | Not tested               |
| Foundation   | Full         | Some APIs missing/broken | Some APIs missing/broken |
| XcodeProj    | Full         | Full                     | Not available            |
| Swift version| 6.3+         | 6.3+                     | 6.3+                     |

## Windows Support

### Swift Version

Windows requires Swift 6.3 (stable release) due to `swift-resvg` artifactbundle compatibility.
CI uses `compnerd/gha-setup-swift@v0.3.0` with `release: "6.3"`.

### Conditional Dependencies (Package.swift)

`#if` inside array literals does NOT work in SPM Package.swift. Use variable + `#if` append pattern:

```swift
var packageDependencies: [Package.Dependency] = [...]
#if !os(Windows)
    packageDependencies.append(.package(url: "https://github.com/tuist/XcodeProj.git", from: "8.27.0"))
#endif
```

### XcodeProj Exclusion

XcodeProj is Apple-only (depends on PathKit/AEXML). On Windows:
- Dependency excluded via `#if !os(Windows)` in Package.swift
- `XcodeProjectWriter` wrapped in `#if canImport(XcodeProj)` (6 files in Export/)
- Xcode project manipulation silently skipped on Windows

### FoundationNetworking / FoundationXML

Use `#if canImport()` instead of `#if os(Linux)` — covers both Linux and Windows:

```swift
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

#if canImport(FoundationXML)
    import FoundationXML
#endif
```

### MCP SDK Exclusion

MCP swift-sdk depends on swift-nio (no Windows support). On Windows:
- Dependency excluded via `#if !os(Windows)` in Package.swift (same pattern as XcodeProj)
- All `Sources/ExFigCLI/MCP/*.swift` and `Subcommands/MCPServe.swift` wrapped in `#if canImport(MCP)`
- `ExFigCommand.allSubcommands` computed var (not array literal) for conditional subcommand registration
- `MCPToolHandlers.swift` excluded in `.swiftlint.yml` (file_length with `#if` wrapper)

### SPM Artifactbundle on Windows

SPM on Windows has library naming differences:
- Unix linkers auto-prepend `lib` prefix (`-lresvg` finds `libresvg.a`)
- Windows `lld-link` does NOT prepend prefix (`resvg.lib` must exist as-is)
- Swift 6.3 allows `.lib` files without `lib` prefix in artifactbundle info.json
