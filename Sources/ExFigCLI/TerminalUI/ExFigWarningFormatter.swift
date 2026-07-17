import Noora

/// Formats ExFigWarning for terminal display using TOON format.
///
/// Uses two styles:
/// - **Compact**: Single line `key=value` pairs for simple warnings
/// - **Multiline**: Indented key-value pairs for warnings with multiple fields
struct ExFigWarningFormatter {
    /// Format an ExFigWarning for terminal display.
    /// - Parameter warning: The warning to format.
    /// - Returns: A formatted string suitable for terminal output.
    func format(_ warning: ExFigWarning) -> String {
        switch warning {
        // Compact format warnings
        case .configMissing, .composeRequirementMissing, .noConfigsFound,
             .noValidConfigs, .xcodeProjectUpdateFailed, .checkpointExpired,
             .checkpointPathMismatch, .retrying, .preFetchPartialFailure,
             .preFetchComponentsPartialFailure, .preFetchNodesPartialFailure,
             .granularCacheWithoutCache, .themeAttributesFileNotFound,
             .themeAttributesMarkerNotFound, .themeAttributesNameCollision,
             .heicUnavailableFallingBackToPng, .deletedVariableAlias,
             .unresolvedNumberAlias, .depthExceededNumberAlias,
             .circularColorAlias, .duplicateColorCollection,
             .downloadTokensSectionSkipped,
             .batchSettingsPreloadFailed, .ignoredPerTargetBatchBlock,
             .ignoredPerTargetFigmaRateLimiting, .invalidConfigValue,
             .excessiveDownloadSlots:
            formatCompact(warning)

        // Multiline format warnings
        case let .noAssetsFound(assetType, frameName, pageName):
            formatNoAssetsFound(assetType: assetType, frameName: frameName, pageName: pageName)

        case let .invalidConfigsSkipped(count):
            formatInvalidConfigsSkipped(count: count)

        case let .webIconsMissingSVGData(count, names):
            formatWebIconsMissingSVGData(count: count, names: names)

        case let .webIconsConversionFailed(count, names):
            formatWebIconsConversionFailed(count: count, names: names)
        }
    }

    // MARK: - Compact Formatters

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func formatCompact(_ warning: ExFigWarning) -> String {
        switch warning {
        case let .configMissing(platform, assetType):
            "Config missing: platform=\(platform), assetType=\(assetType)"

        case let .composeRequirementMissing(requirement):
            "Compose export skipped: missing=\(requirement)"

        case .noConfigsFound:
            "No config files found"

        case .noValidConfigs:
            "No valid ExFig config files found"

        case let .xcodeProjectUpdateFailed(detail):
            "Xcode project update incomplete: \(detail)"

        case .checkpointExpired:
            "Checkpoint expired: older than 24h, starting fresh"

        case .checkpointPathMismatch:
            "Checkpoint invalid: paths don't match current request, starting fresh"

        case let .retrying(attempt, maxAttempts, error, delay):
            "Retrying: attempt=\(attempt)/\(maxAttempts), error=\(error), delay=\(delay)"

        case let .preFetchPartialFailure(failed, total):
            "Pre-fetch partial failure: \(failed)/\(total) files failed, using fallback"

        case let .preFetchComponentsPartialFailure(failed, total):
            "Pre-fetch components partial failure: \(failed)/\(total) files failed, using fallback"

        case let .preFetchNodesPartialFailure(error):
            "Pre-fetch nodes failed: \(error), using fallback"

        case .granularCacheWithoutCache:
            "--experimental-granular-cache ignored: requires --cache flag"

        case let .themeAttributesFileNotFound(file):
            "Theme attributes skipped: file not found, path=\(file)"

        case let .themeAttributesMarkerNotFound(file, marker):
            "Theme attributes skipped: marker not found, file=\(file), marker=\(marker)"

        case let .themeAttributesNameCollision(count, collisions):
            formatThemeAttributesCollision(count: count, collisions: collisions)

        case .heicUnavailableFallingBackToPng:
            "HEIC encoding unavailable on this platform, using PNG format instead"

        case let .deletedVariableAlias(tokenName, referencedName):
            "Skipped deleted variable alias: token=\(tokenName), referenced=\(referencedName)"

        case let .unresolvedNumberAlias(tokenName):
            "Could not resolve number variable alias: token=\(tokenName)"

        case let .depthExceededNumberAlias(tokenName):
            "Number alias chain exceeded max depth (likely circular): token=\(tokenName)"

        case let .circularColorAlias(tokenName):
            "Color alias chain exceeded max depth (likely circular): token=\(tokenName)"

        case let .downloadTokensSectionSkipped(section):
            "Token section skipped (not configured): section=\(section)"

        case let .batchSettingsPreloadFailed(file, error):
            "Batch settings pre-load failed: file=\(file), error=\(error). " +
                "CLI flags / built-in defaults will apply."

        case let .ignoredPerTargetBatchBlock(file):
            "Ignoring batch: in \(file) — only the first config's batch settings apply."

        case let .ignoredPerTargetFigmaRateLimiting(file):
            "Ignoring per-target figma rate-limiting fields in \(file) — " +
                "only the first config's figma:* values apply in batch mode."

        case let .invalidConfigValue(key, value, fallback):
            "Invalid config value: key=\(key), value=\(value), fallback=\(fallback)"

        case let .excessiveDownloadSlots(concurrentDownloads, parallel, capped):
            "Excessive download slots: concurrentDownloads=\(concurrentDownloads), " +
                "parallel=\(parallel), product=\(concurrentDownloads * parallel), capped=\(capped). " +
                "Reduce --concurrent-downloads or --parallel to avoid CDN throttling / EMFILE."

        case let .duplicateColorCollection(name, selectedCount, otherCounts):
            formatDuplicateColorCollection(name: name, selectedCount: selectedCount, otherCounts: otherCounts)

        // Multiline cases handled in main format() method
        case .noAssetsFound, .invalidConfigsSkipped, .webIconsMissingSVGData, .webIconsConversionFailed:
            fatalError("Multiline warnings should not reach formatCompact")
        }
    }

    // MARK: - Multiline Formatters

    private func formatNoAssetsFound(assetType: String, frameName: String, pageName: String?) -> String {
        var result = """
        No assets found:
          type: \(assetType)
          frame: \(frameName)
        """
        if let pageName {
            result += "\n  page: \(pageName)"
            result += "\n  hint: Check that the page name matches exactly (case-sensitive)"
        }
        return result
    }

    private func formatInvalidConfigsSkipped(count: Int) -> String {
        let noun = count == 1 ? "file" : "files"
        return """
        Invalid configs skipped:
          count: \(count) \(noun)
        """
    }

    private func formatDuplicateColorCollection(name: String, selectedCount: Int, otherCounts: [Int]) -> String {
        "Multiple variable collections named '\(name)' found; " +
            "selected the one with \(selectedCount) variables, ignored \(otherCounts). " +
            "Remove the duplicate collection in Figma to make export deterministic."
    }

    private func formatWebIconsMissingSVGData(count: Int, names: [String]) -> String {
        let preview = formatNamePreview(names)
        return """
        TSX components skipped (missing SVG data):
          count: \(count)
          icons: \(preview)
        """
    }

    private func formatWebIconsConversionFailed(count: Int, names: [String]) -> String {
        let preview = formatNamePreview(names)
        return """
        TSX components skipped (JSX conversion failed):
          count: \(count)
          icons: \(preview)
        """
    }

    /// Formats a list of names as a preview string, truncating if too long.
    private func formatNamePreview(_ names: [String], maxNames: Int = 3) -> String {
        if names.count <= maxNames {
            return names.joined(separator: ", ")
        }
        let preview = names.prefix(maxNames).joined(separator: ", ")
        let remaining = names.count - maxNames
        return "\(preview), +\(remaining) more"
    }

    private func formatThemeAttributesCollision(
        count: Int,
        collisions: [ThemeAttributeCollisionInfo]
    ) -> String {
        let preview = collisions.prefix(3).map { "\($0.discarded)→\($0.attr)" }.joined(separator: ", ")
        let suffix = count > 3 ? ", +\(count - 3) more" : ""
        return "Theme attributes collision: \(count) skipped, \(preview)\(suffix)"
    }

    // MARK: - TerminalText API

    /// Format an ExFigWarning as semantic TerminalText.
    /// - Parameter warning: The warning to format.
    /// - Returns: A TerminalText suitable for NooraUI.format().
    func formatAsTerminalText(_ warning: ExFigWarning) -> TerminalText {
        let message = format(warning)
        let lines = message.split(separator: "\n", omittingEmptySubsequences: false)

        if lines.count == 1 {
            // Single line: icon + accent text
            return "\(.accent("⚠")) \(.accent(message))"
        }

        // Multi-line: build string with indentation, then wrap in single accent
        let formattedLines = lines.enumerated().map { index, line in
            if index == 0 {
                "⚠ \(line)"
            } else {
                "  \(line)"
            }
        }.joined(separator: "\n")

        return "\(.accent(formattedLines))"
    }
}
