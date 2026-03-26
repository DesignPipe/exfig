## 1. PenpotAPI Module — Package Setup

- [x] 1.1 Add `PenpotAPI` target and `PenpotAPITests` test target to `Package.swift`; add `"PenpotAPI"` to ExFigCLI dependencies
- [x] 1.2 Create `Sources/PenpotAPI/CLAUDE.md` with module overview

## 2. PenpotAPI Module — Client

- [x] 2.1 Define `PenpotEndpoint` protocol and `PenpotClient` protocol in `Sources/PenpotAPI/Client/`
- [x] 2.2 Implement `BasePenpotClient` (URLSession, auth header, base URL, retry logic)
- [x] 2.3 Implement `PenpotAPIError` with LocalizedError conformance and recovery suggestions

## 3. PenpotAPI Module — Endpoints

- [x] 3.1 Implement `GetFileEndpoint` (command: `get-file`, body: `{id}`, response: `PenpotFileResponse`)
- [x] 3.2 Implement `GetProfileEndpoint` (command: `get-profile`, no body, response: `PenpotProfile`)
- [x] 3.3 Implement `GetFileObjectThumbnailsEndpoint` (command: `get-file-object-thumbnails`, response: thumbnail map)
- [x] 3.4 Implement asset download method (`GET /assets/by-file-media-id/<id>`)

## 4. PenpotAPI Module — Models

- [x] 4.1 Define `PenpotFileResponse` and `PenpotFileData` with selective decoding (colors, typographies, components)
- [x] 4.2 Define `PenpotColor` (id, name, path, color hex, opacity) — standard Codable, no CodingKeys (JSON uses camelCase)
- [x] 4.3 Define `PenpotComponent` (id, name, path, mainInstanceId, mainInstancePage) — standard Codable, no CodingKeys
- [x] 4.4 Define `PenpotTypography` with dual String/Double decoding via custom `init(from:)` — handles both `"24"` and `24`
- [x] 4.5 Define `PenpotProfile` (id, fullname, email)

## 5. PenpotAPI Module — Unit Tests

- [x] 5.1 Create JSON fixtures in `Tests/PenpotAPITests/Fixtures/` (file response, colors, components, typographies)
- [x] 5.2 Write `PenpotColorDecodingTests` — solid, gradient (nil hex), path grouping
- [x] 5.3 Write `PenpotTypographyDecodingTests` — string→Double, number→Double, unparseable values, camelCase keys
- [x] 5.4 Write `PenpotComponentDecodingTests` — camelCase keys, optional fields
- [x] 5.5 Write `PenpotEndpointTests` — URL construction (`/api/main/methods/`), body serialization for RPC endpoints
- [x] 5.6 Write `PenpotAPIErrorTests` — recovery suggestions for 401, 404, 429

## 6. ExFigCore — Config Types

- [x] 6.1 Add `PenpotColorsConfig: ColorsSourceConfig` to `DesignSource.swift` (fileId, baseURL, pathFilter)
- [x] 6.2 Update `ColorsSourceInput.spinnerLabel` in `ExportContext.swift` for `.penpot` case

## 7. Integration Sources

- [x] 7.1 Implement `PenpotColorsSource` in `ExFigCLI/Source/` — hex→RGBA, path filter, light-only output
- [x] 7.2 Implement `PenpotComponentsSource` in `ExFigCLI/Source/` — component filter, thumbnails, SVG warning
- [x] 7.3 Implement `PenpotTypographySource` in `ExFigCLI/Source/` — string→Double, textCase mapping
- [x] 7.4 Update `SourceFactory.swift` — replace `throw unsupportedSourceKind(.penpot)` with real Penpot sources

## 8. PKL Schema + Codegen

- [x] 8.1 Add `PenpotSource` class to `Common.pkl` (fileId, baseUrl, pathFilter)
- [x] 8.2 Add `penpotSource: PenpotSource?` to `VariablesSource` and `FrameSource` in `Common.pkl`
- [x] 8.3 Add sourceKind auto-detection logic in PKL (penpotSource → "penpot")
- [x] 8.4 Run `./bin/mise run codegen:pkl` and verify generated types
- [x] 8.5 Update entry bridge methods in `Sources/ExFig-*/Config/*Entry.swift` — map `penpotSource` → `PenpotColorsConfig` / SourceInput fields

## 9. E2E Tests

- [ ] 9.1 Create test Penpot project on design.penpot.app (5+ colors, 3+ components, 3+ typographies)
- [ ] 9.2 Document file UUID and test data in `Tests/PenpotAPITests/README.md`
- [ ] 9.3 Write `PenpotE2ETests` — getProfile, getFileColors, getFileComponents, getFileTypographies, getThumbnails, downloadAsset
- [ ] 9.4 Write `PenpotSourceIntegrationTests` — PenpotColorsSource → ColorsLoadOutput, PenpotComponentsSource → IconsLoadOutput

## 10. Verification

- [x] 10.1 `./bin/mise run build` — all modules compile
- [x] 10.2 `./bin/mise run test` — unit tests pass
- [x] 10.3 `./bin/mise run lint` — no SwiftLint violations
- [x] 10.4 `./bin/mise run format-check` — formatting correct
- [ ] 10.5 E2E tests pass with `PENPOT_ACCESS_TOKEN` and `PENPOT_TEST_FILE_ID`
