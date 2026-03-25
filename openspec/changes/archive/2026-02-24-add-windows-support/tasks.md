# Tasks: Add Windows Platform Support

## 1. Preparation

- [ ] 1.1 Add Windows to supported platforms in Package.swift
- [ ] 1.2 Create Windows CI workflow in `.github/workflows/windows.yml`
- [ ] 1.3 Document Windows Swift installation in CLAUDE.md

## 2. Conditional Compilation Guards

- [ ] 2.1 Add `#if os(Windows)` to TTYDetector.swift for `_isatty()` usage
- [ ] 2.2 Add `#if os(Windows)` to ANSICodes.swift if Windows Terminal differs
- [ ] 2.3 Add `#if canImport(FoundationNetworking)` guards for Windows (same as Linux)
- [ ] 2.4 Make XcodeProj import conditional in Package.swift
- [ ] 2.5 Gate XcodeProj-dependent code with `#if canImport(XcodeProj)`

## 3. XML Parser Migration

- [ ] 3.1 Add XMLCoder dependency to Package.swift
- [ ] 3.2 Create XMLParserProtocol abstraction in SVGKit
- [ ] 3.3 Implement XMLCoder-based SVGParser
- [ ] 3.4 Update SVGParser.swift to use new abstraction
- [ ] 3.5 Remove FoundationXML import from SVGParser.swift
- [ ] 3.6 Update SVGKit tests for new parser

## 4. Native Library Compatibility

- [ ] 4.1 Test libwebp build on Windows CI
- [ ] 4.2 Test libpng build on Windows CI
- [ ] 4.3 Add graceful fallback if WebP conversion unavailable
- [ ] 4.4 Document native library requirements for Windows

## 5. Path Handling

- [ ] 5.1 Audit FileWriter.swift for hardcoded path separators
- [ ] 5.2 Audit FileDownloader.swift for path issues
- [ ] 5.3 Use URL APIs consistently for path construction
- [ ] 5.4 Add Windows path tests

## 6. Testing and Validation

- [ ] 6.1 Run SVGKit tests on Windows
- [ ] 6.2 Run FigmaAPI tests on Windows
- [ ] 6.3 Run AndroidExport tests on Windows
- [ ] 6.4 Run FlutterExport tests on Windows
- [ ] 6.5 Test CLI commands on Windows manually
- [ ] 6.6 Verify colors/icons/images export works

## 7. Documentation

- [ ] 7.1 Update README.md with Windows support
- [ ] 7.2 Add Windows section to CLAUDE.md
- [ ] 7.3 Document Windows-specific limitations (no Xcode export)
- [ ] 7.4 Add Windows installation instructions
