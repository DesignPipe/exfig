/// Info about a theme attribute name collision for warning display.
struct ThemeAttributeCollisionInfo: Equatable {
    let attr: String
    let kept: String
    let discarded: String
}

/// Unified warning types for ExFig CLI output with TOON formatting support.
enum ExFigWarning: Equatable {
    // MARK: - Configuration Warnings

    /// Platform/asset type configuration is missing from config file.
    case configMissing(platform: String, assetType: String)

    // MARK: - Asset Discovery Warnings

    /// No assets found in the specified Figma frame.
    case noAssetsFound(assetType: String, frameName: String, pageName: String? = nil)

    // MARK: - Xcode Project Warnings

    /// Failed to add some file references to Xcode project.
    case xcodeProjectUpdateFailed(detail: String)

    // MARK: - Compose Configuration Warnings

    /// Required Compose configuration is missing for ImageVector export.
    case composeRequirementMissing(requirement: String)

    // MARK: - Batch Processing Warnings

    /// No config files found in specified paths.
    case noConfigsFound

    /// Some config files were invalid and skipped.
    case invalidConfigsSkipped(count: Int)

    /// No valid ExFig config files found.
    case noValidConfigs

    /// Checkpoint is expired (older than 24h).
    case checkpointExpired

    /// Checkpoint paths don't match current request.
    case checkpointPathMismatch

    // MARK: - Retry Warnings

    /// Retrying a failed request.
    case retrying(attempt: Int, maxAttempts: Int, error: String, delay: String)

    // MARK: - Pre-fetch Warnings

    /// Pre-fetch failed for some files, falling back to per-config fetch.
    case preFetchPartialFailure(failed: Int, total: Int)

    /// Pre-fetch components failed for some files, falling back to per-config fetch.
    case preFetchComponentsPartialFailure(failed: Int, total: Int)

    /// Pre-fetch nodes failed, falling back to per-config fetch.
    case preFetchNodesPartialFailure(error: String)

    // MARK: - Granular Cache Warnings

    /// Granular cache flag used without --cache enabled.
    case granularCacheWithoutCache

    // MARK: - Theme Attributes Warnings

    /// Target file for theme attributes not found and autoCreateMarkers is disabled.
    case themeAttributesFileNotFound(file: String)

    /// Markers not found in theme attributes target file.
    case themeAttributesMarkerNotFound(file: String, marker: String)

    /// Multiple XML color names map to the same theme attribute name.
    case themeAttributesNameCollision(count: Int, collisions: [ThemeAttributeCollisionInfo])

    // MARK: - Web Export Warnings

    /// Some icons were skipped because SVG data was not found.
    case webIconsMissingSVGData(count: Int, names: [String])

    /// Some icons failed JSX conversion.
    case webIconsConversionFailed(count: Int, names: [String])

    // MARK: - HEIC Export Warnings

    /// HEIC encoding is not available on this platform, falling back to PNG.
    case heicUnavailableFallingBackToPng

    // MARK: - Variables Warnings

    /// A color token references a deleted-but-referenced variable via alias.
    case deletedVariableAlias(tokenName: String, referencedName: String)

    /// A number variable alias could not be resolved.
    case unresolvedNumberAlias(tokenName: String)

    /// A number variable alias chain exceeded maximum depth (likely circular).
    case depthExceededNumberAlias(tokenName: String)

    /// A color variable alias chain exceeded maximum depth (likely circular).
    case circularColorAlias(tokenName: String)

    /// A `download tokens` section was skipped because config is missing.
    case downloadTokensSectionSkipped(section: String)
}
