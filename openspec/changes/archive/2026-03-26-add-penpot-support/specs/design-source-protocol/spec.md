## MODIFIED Requirements

### Requirement: ColorsSourceConfig protocol

Source-specific config types SHALL conform to this protocol:

```swift
public protocol ColorsSourceConfig: Sendable {}

public struct FigmaColorsConfig: ColorsSourceConfig {
    public let tokensFileId: String
    public let tokensCollectionName: String
    public let lightModeName: String
    public let darkModeName: String?
    public let lightHCModeName: String?
    public let darkHCModeName: String?
    public let primitivesModeName: String?
}

public struct TokensFileColorsConfig: ColorsSourceConfig {
    public let filePath: String
    public let groupFilter: String?
    public let ignoredModeNames: [String]
}

public struct PenpotColorsConfig: ColorsSourceConfig {
    public let fileId: String
    public let baseURL: String
    public let pathFilter: String?
}
```

#### Scenario: FigmaColorsConfig holds Figma-specific fields

- **WHEN** a `FigmaColorsConfig` is constructed
- **THEN** it SHALL contain all fields previously in `ColorsSourceInput` that are Figma-specific (`tokensFileId`, `tokensCollectionName`, `lightModeName`, `darkModeName`, `lightHCModeName`, `darkHCModeName`, `primitivesModeName`)

#### Scenario: TokensFileColorsConfig holds tokens-file-specific fields

- **WHEN** a `TokensFileColorsConfig` is constructed
- **THEN** it SHALL contain `filePath`, optional `groupFilter`, and `ignoredModeNames`
- **AND** it SHALL NOT contain any Figma-specific fields

#### Scenario: PenpotColorsConfig holds Penpot-specific fields

- **WHEN** a `PenpotColorsConfig` is constructed
- **THEN** it SHALL contain `fileId`, `baseURL` (default `"https://design.penpot.app/"`), and optional `pathFilter`
- **AND** it SHALL NOT contain any Figma-specific or TokensFile-specific fields

#### Scenario: Source implementations cast sourceConfig

- **WHEN** `PenpotColorsSource.loadColors()` receives a `ColorsSourceInput`
- **THEN** it SHALL cast `input.sourceConfig` to `PenpotColorsConfig`
- **AND** it SHALL throw a descriptive error if the cast fails

### Requirement: ColorsSourceInput spinnerLabel

`ColorsSourceInput.spinnerLabel` SHALL return human-readable labels for all supported source kinds:

#### Scenario: Figma spinner label

- **WHEN** `sourceKind == .figma` and `sourceConfig` is `FigmaColorsConfig` with `tokensCollectionName: "Brand Colors"`
- **THEN** `spinnerLabel` SHALL return `"Figma Variables (Brand Colors)"`

#### Scenario: TokensFile spinner label

- **WHEN** `sourceKind == .tokensFile` and `sourceConfig` is `TokensFileColorsConfig` with `filePath: "/path/to/tokens.json"`
- **THEN** `spinnerLabel` SHALL return `"tokens.json"`

#### Scenario: Penpot spinner label

- **WHEN** `sourceKind == .penpot` and `sourceConfig` is `PenpotColorsConfig` with `fileId: "abc12345-def6-7890"`
- **THEN** `spinnerLabel` SHALL return `"Penpot colors (abc12345…)"`

#### Scenario: Unsupported source kind fallback

- **WHEN** `sourceKind` is `.tokensStudio` or `.sketchFile`
- **THEN** `spinnerLabel` SHALL return the raw value of the enum case
