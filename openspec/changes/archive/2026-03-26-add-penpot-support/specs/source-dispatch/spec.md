## MODIFIED Requirements

### Requirement: Centralized SourceFactory

The system SHALL provide a `SourceFactory` enum in `Sources/ExFigCLI/Source/SourceFactory.swift` with static methods for creating source instances:

```swift
enum SourceFactory {
    static func createColorsSource(for input: ColorsSourceInput, client: Client, ui: TerminalUI, filter: String?) throws -> any ColorsSource
    static func createComponentsSource(for sourceKind: DesignSourceKind, ...) throws -> any ComponentsSource
    static func createTypographySource(for sourceKind: DesignSourceKind, ...) throws -> any TypographySource
}
```

#### Scenario: Factory dispatches by sourceKind

- **WHEN** `SourceFactory.createColorsSource()` is called with `sourceKind == .figma`
- **THEN** it SHALL return a `FigmaColorsSource` instance

#### Scenario: Factory dispatches tokensFile

- **WHEN** `SourceFactory.createColorsSource()` is called with `sourceKind == .tokensFile`
- **THEN** it SHALL return a `TokensFileColorsSource` instance

#### Scenario: Factory dispatches penpot colors

- **WHEN** `SourceFactory.createColorsSource()` is called with `sourceKind == .penpot`
- **THEN** it SHALL return a `PenpotColorsSource` instance

#### Scenario: Factory dispatches penpot components

- **WHEN** `SourceFactory.createComponentsSource()` is called with `sourceKind == .penpot`
- **THEN** it SHALL return a `PenpotComponentsSource` instance

#### Scenario: Factory dispatches penpot typography

- **WHEN** `SourceFactory.createTypographySource()` is called with `sourceKind == .penpot`
- **THEN** it SHALL return a `PenpotTypographySource` instance

#### Scenario: Factory throws for unsupported sourceKind

- **WHEN** `SourceFactory.createColorsSource()` is called with `sourceKind == .tokensStudio`
- **THEN** it SHALL throw `ExFigError.unsupportedSourceKind(.tokensStudio, assetType: "colors")`
