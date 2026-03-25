# Platform Support

Cross-platform compatibility requirements for ExFig CLI.

## ADDED Requirements

### Requirement: Windows Platform Support

The system SHALL build and run on Windows 10/11 with Swift 6.0 or later.

#### Scenario: Build on Windows

- **WHEN** running `swift build` on Windows with Swift 6.0+
- **THEN** the build completes without errors
- **AND** produces a working `exfig.exe` binary

#### Scenario: Export colors on Windows

- **WHEN** running `exfig colors` on Windows
- **THEN** colors are exported to the configured Android or Flutter destination

#### Scenario: Export icons on Windows

- **WHEN** running `exfig icons` on Windows
- **THEN** icons are exported to the configured Android or Flutter destination

#### Scenario: Export images on Windows

- **WHEN** running `exfig images` on Windows
- **THEN** images are exported to the configured Android or Flutter destination

### Requirement: Graceful Feature Degradation

The system SHALL gracefully disable platform-specific features when running on unsupported platforms.

#### Scenario: Xcode export on Windows

- **WHEN** configuration specifies iOS/Xcode export on Windows
- **THEN** the system displays a warning that Xcode export is not supported on Windows
- **AND** skips Xcode-specific operations without failing

#### Scenario: WebP unavailable

- **WHEN** WebP conversion is requested but libwebp is not available
- **THEN** the system falls back to original image format
- **AND** displays a warning about missing WebP support

### Requirement: Cross-Platform TTY Detection

The system SHALL detect terminal capabilities correctly on all supported platforms.

#### Scenario: TTY detection on Windows

- **WHEN** running in Windows Terminal or PowerShell
- **THEN** `TTYDetector.isTTY` returns true
- **AND** colored output and progress indicators work correctly

#### Scenario: TTY detection in Windows pipe

- **WHEN** output is piped to a file on Windows
- **THEN** `TTYDetector.isTTY` returns false
- **AND** ANSI codes are not emitted

### Requirement: Cross-Platform Path Handling

The system SHALL handle file paths correctly on all supported platforms.

#### Scenario: Windows path with backslashes

- **WHEN** configuration contains Windows-style paths (e.g., `C:\Users\...`)
- **THEN** the system correctly reads and writes files at those paths

#### Scenario: Forward slashes on Windows

- **WHEN** configuration contains forward-slash paths on Windows
- **THEN** the system normalizes paths and operates correctly

### Requirement: Cross-Platform XML Parsing

The system SHALL parse SVG files using a cross-platform XML parser.

#### Scenario: Parse SVG on Windows

- **WHEN** parsing an SVG file on Windows
- **THEN** the SVG is parsed correctly without using FoundationXML

#### Scenario: Parse SVG with gradients on Windows

- **WHEN** parsing an SVG with linear or radial gradients on Windows
- **THEN** gradient definitions are extracted correctly
