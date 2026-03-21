## 1. PenpotAPI Module — Package Setup

- [ ] 1.1 Add `PenpotAPI` target and `PenpotAPITests` test target to `Package.swift`; add `"PenpotAPI"` to ExFigCLI dependencies
- [ ] 1.2 Create `Sources/PenpotAPI/CLAUDE.md` with module overview

## 2. PenpotAPI Module — Client

- [ ] 2.1 Define `PenpotEndpoint` protocol and `PenpotClient` protocol in `Sources/PenpotAPI/Client/`
- [ ] 2.2 Implement `BasePenpotClient` (URLSession, auth header, base URL, retry logic)
- [ ] 2.3 Implement `PenpotAPIError` with LocalizedError conformance and recovery suggestions

## 3. PenpotAPI Module — Endpoints

- [ ] 3.1 Implement `GetFileEndpoint` (command: `get-file`, body: `{id}`, response: `PenpotFileResponse`)
- [ ] 3.2 Implement `GetProfileEndpoint` (command: `get-profile`, no body, response: `PenpotProfile`)
- [ ] 3.3 Implement `GetFileObjectThumbnailsEndpoint` (command: `get-file-object-thumbnails`, response: thumbnail map)
- [ ] 3.4 Implement asset download method (`GET /assets/by-file-media-id/<id>`)

## 4. PenpotAPI Module — Models

- [ ] 4.1 Define `PenpotFileResponse` and `PenpotFileData` with selective decoding (colors, typographies, components)
- [ ] 4.2 Define `PenpotColor` with kebab-case CodingKeys (id, name, path, color hex, opacity)
- [ ] 4.3 Define `PenpotComponent` with kebab-case CodingKeys (id, name, path, main-instance-id, main-instance-page)
- [ ] 4.4 Define `PenpotTypography` with string→Double computed properties and kebab-case CodingKeys
- [ ] 4.5 Define `PenpotProfile` (id, fullname, email)

## 5. PenpotAPI Module — Unit Tests

- [ ] 5.1 Create JSON fixtures in `Tests/PenpotAPITests/Fixtures/` (file response, colors, components, typographies)
- [ ] 5.2 Write `PenpotColorDecodingTests` — solid, gradient (nil hex), path grouping
- [ ] 5.3 Write `PenpotTypographyDecodingTests` — string→Double, unparseable values, all kebab-case keys
- [ ] 5.4 Write `PenpotComponentDecodingTests` — kebab-case keys, optional fields
- [ ] 5.5 Write `PenpotEndpointTests` — URL construction, body serialization for RPC endpoints
- [ ] 5.6 Write `PenpotAPIErrorTests` — recovery suggestions for 401, 404, 429

## 6. ExFigCore — Config Types

- [ ] 6.1 Add `PenpotColorsConfig: ColorsSourceConfig` to `DesignSource.swift` (fileId, baseURL, pathFilter)
- [ ] 6.2 Update `ColorsSourceInput.spinnerLabel` in `ExportContext.swift` for `.penpot` case

## 7. Integration Sources

- [ ] 7.1 Implement `PenpotColorsSource` in `ExFigCLI/Source/` — hex→RGBA, path filter, light-only output
- [ ] 7.2 Implement `PenpotComponentsSource` in `ExFigCLI/Source/` — component filter, thumbnails, SVG warning
- [ ] 7.3 Implement `PenpotTypographySource` in `ExFigCLI/Source/` — string→Double, textCase mapping
- [ ] 7.4 Update `SourceFactory.swift` — replace `throw unsupportedSourceKind(.penpot)` with real Penpot sources

## 8. PKL Schema + Codegen

- [ ] 8.1 Add `PenpotSource` class to `Common.pkl` (fileId, baseUrl, pathFilter)
- [ ] 8.2 Add `penpotSource: PenpotSource?` to `VariablesSource` and `FrameSource` in `Common.pkl`
- [ ] 8.3 Add sourceKind auto-detection logic in PKL (penpotSource → "penpot")
- [ ] 8.4 Run `./bin/mise run codegen:pkl` and verify generated types
- [ ] 8.5 Update entry bridge methods in `Sources/ExFig-*/Config/*Entry.swift` — map `penpotSource` → `PenpotColorsConfig` / SourceInput fields

## 9. E2E Tests

- [ ] 9.1 Create test Penpot project on design.penpot.app (5+ colors, 3+ components, 3+ typographies)
- [ ] 9.2 Document file UUID and test data in `Tests/PenpotAPITests/README.md`
- [ ] 9.3 Write `PenpotE2ETests` — getProfile, getFileColors, getFileComponents, getFileTypographies, getThumbnails, downloadAsset
- [ ] 9.4 Write `PenpotSourceIntegrationTests` — PenpotColorsSource → ColorsLoadOutput, PenpotComponentsSource → IconsLoadOutput

## 10. Verification

- [ ] 10.1 `./bin/mise run build` — all modules compile
- [ ] 10.2 `./bin/mise run test` — unit tests pass
- [ ] 10.3 `./bin/mise run lint` — no SwiftLint violations
- [ ] 10.4 `./bin/mise run format-check` — formatting correct
- [ ] 10.5 E2E tests pass with `PENPOT_ACCESS_TOKEN` and `PENPOT_TEST_FILE_ID`
