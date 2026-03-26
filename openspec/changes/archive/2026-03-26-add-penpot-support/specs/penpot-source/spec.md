## ADDED Requirements

### Requirement: PenpotColorsSource

The system SHALL provide a `PenpotColorsSource` struct in `ExFigCLI/Source/` conforming to `ColorsSource`. It SHALL:

- Cast `input.sourceConfig` to `PenpotColorsConfig`
- Create `BasePenpotClient` from `PENPOT_ACCESS_TOKEN` env var and `config.baseURL`
- Call `GetFileEndpoint` to retrieve file data
- Filter to solid colors only (skip gradient/image fills where `color` is nil)
- Convert hex color string → RGBA `Color` (0.0-1.0)
- Apply `pathFilter` if set (filter by Penpot color `path` prefix)
- Return `ColorsLoadOutput(light: colors)` — Penpot has no mode-based variants

#### Scenario: Load solid colors from Penpot file

- **WHEN** `PenpotColorsSource.loadColors()` is called with a valid `PenpotColorsConfig`
- **THEN** it SHALL return `ColorsLoadOutput` with `light` array containing `Color` objects
- **AND** `dark`, `lightHC`, `darkHC` arrays SHALL be empty

#### Scenario: Skip gradient colors

- **WHEN** a Penpot file contains gradient colors (no solid hex value)
- **THEN** those colors SHALL be excluded from the output
- **AND** no error SHALL be thrown

#### Scenario: Filter by path

- **WHEN** `PenpotColorsConfig.pathFilter` is `"Brand"`
- **THEN** only colors whose `path` starts with `"Brand"` SHALL be included

#### Scenario: Hex to RGBA conversion

- **WHEN** a Penpot color has `color: "#FF6633"` and `opacity: 0.8`
- **THEN** the resulting `Color` SHALL have `red: 1.0`, `green: 0.4`, `blue: 0.2`, `alpha: 0.8`

#### Scenario: Missing PENPOT_ACCESS_TOKEN

- **WHEN** `PENPOT_ACCESS_TOKEN` env var is not set
- **THEN** `PenpotColorsSource` SHALL throw a descriptive error mentioning the env var

#### Scenario: Wrong config type

- **WHEN** `PenpotColorsSource.loadColors()` receives a `FigmaColorsConfig`
- **THEN** it SHALL throw an error indicating config type mismatch

### Requirement: PenpotComponentsSource

The system SHALL provide a `PenpotComponentsSource` struct in `ExFigCLI/Source/` conforming to `ComponentsSource`. It SHALL:

- Create `BasePenpotClient` from `PENPOT_ACCESS_TOKEN` env var
- Call `GetFileEndpoint` to retrieve components
- Filter components by `input.frameName` used as component path filter
- Call `GetFileObjectThumbnailsEndpoint` to get media IDs for matched components
- Build `ImagePack` entries with thumbnail download URLs (`<baseURL>/assets/by-file-media-id/<id>`)
- Return `IconsLoadOutput(light: packs, dark: [])` or `ImagesLoadOutput(light: packs, dark: [])`

#### Scenario: Load icons from Penpot components

- **WHEN** `PenpotComponentsSource.loadIcons()` is called with `frameName: "Icons"`
- **THEN** it SHALL return `IconsLoadOutput` with `ImagePack` entries for components whose `path` matches `"Icons"`
- **AND** each `ImagePack` SHALL contain a download URL for the component thumbnail

#### Scenario: Load images/illustrations from Penpot components

- **WHEN** `PenpotComponentsSource.loadImages()` is called with `frameName: "Illustrations"`
- **THEN** it SHALL return `ImagesLoadOutput` with `ImagePack` entries for matching components

#### Scenario: Warn when SVG format requested

- **WHEN** `loadIcons()` is called with `input.format == .svg` and `sourceKind == .penpot`
- **THEN** it SHALL emit a warning via `ui.warning()` that Penpot exports thumbnails (raster), not SVG
- **AND** it SHALL still return raster thumbnails (not fail)

#### Scenario: No matching components

- **WHEN** `frameName` filter matches zero components
- **THEN** it SHALL return empty `IconsLoadOutput(light: [], dark: [])`

#### Scenario: Component without thumbnail

- **WHEN** a matched component has no thumbnail available
- **THEN** it SHALL be excluded from the output with a warning

### Requirement: PenpotTypographySource

The system SHALL provide a `PenpotTypographySource` struct in `ExFigCLI/Source/` conforming to `TypographySource`. It SHALL:

- Create `BasePenpotClient` from `PENPOT_ACCESS_TOKEN` env var
- Call `GetFileEndpoint` to retrieve typographies
- Convert `PenpotTypography` → ExFigCore `TextStyle`
- Skip typographies with unparseable font-size (emit warning)
- Return `TypographyLoadOutput` with converted text styles

#### Scenario: Load typography from Penpot file

- **WHEN** `PenpotTypographySource.loadTypography()` is called
- **THEN** it SHALL return `TypographyLoadOutput` with `TextStyle` entries

#### Scenario: String-to-Double conversion

- **WHEN** a Penpot typography has `fontSize: "16"` (string) or `fontSize: 16` (number) and `lineHeight: "1.5"`
- **THEN** the resulting `TextStyle` SHALL have `fontSize: 16.0` and `lineHeight: 1.5`

#### Scenario: Unparseable font-size skipped

- **WHEN** a typography has `fontSize: "auto"` (unparseable)
- **THEN** it SHALL be excluded from output
- **AND** a warning SHALL be emitted

#### Scenario: Text transform mapping

- **WHEN** a typography has `textTransform: "uppercase"`
- **THEN** the resulting `TextStyle.textCase` SHALL be `.uppercased`

### Requirement: PKL PenpotSource configuration

The system SHALL define a `PenpotSource` class in `Common.pkl`:

```pkl
class PenpotSource {
    fileId: String(isNotEmpty)
    baseUrl: String = "https://design.penpot.app/"
    pathFilter: String?
}
```

`VariablesSource` and `FrameSource` SHALL gain an optional `penpotSource: PenpotSource?` field. Auto-detection logic for `sourceKind`:

- If `penpotSource` is set → `"penpot"`
- If `tokensFile` is set → `"tokens-file"`
- Otherwise → `"figma"`

#### Scenario: PKL config with Penpot source

- **WHEN** a PKL config contains `penpotSource = new PenpotSource { fileId = "abc-123" }`
- **THEN** `sourceKind` SHALL auto-detect as `"penpot"`

#### Scenario: PKL config with explicit sourceKind override

- **WHEN** a PKL config contains both `penpotSource` and `sourceKind = "figma"`
- **THEN** explicit `sourceKind` SHALL take precedence

#### Scenario: Empty fileId rejected

- **WHEN** a PKL config contains `penpotSource = new PenpotSource { fileId = "" }`
- **THEN** PKL validation SHALL fail with constraint violation

### Requirement: PENPOT_ACCESS_TOKEN environment variable

The system SHALL accept Penpot authentication via `PENPOT_ACCESS_TOKEN` environment variable. This variable SHALL only be required when `sourceKind == .penpot`. When not set and Penpot source is requested, a descriptive error SHALL be thrown.

#### Scenario: Token present

- **WHEN** `PENPOT_ACCESS_TOKEN` is set and `sourceKind == .penpot`
- **THEN** sources SHALL authenticate successfully

#### Scenario: Token absent with Figma source

- **WHEN** `PENPOT_ACCESS_TOKEN` is not set and `sourceKind == .figma`
- **THEN** no error SHALL be thrown related to Penpot token

#### Scenario: Token absent with Penpot source

- **WHEN** `PENPOT_ACCESS_TOKEN` is not set and `sourceKind == .penpot`
- **THEN** a descriptive error SHALL be thrown: "PENPOT_ACCESS_TOKEN environment variable is required for Penpot source"
