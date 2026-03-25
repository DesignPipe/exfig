import ExFigConfig
import ExFigCore
import FigmaAPI
import Foundation

/// Result of granular cache setup.
struct GranularCacheSetup {
    /// The granular cache manager, if enabled.
    let manager: GranularCacheManager?
    /// Whether granular cache is enabled.
    let enabled: Bool
}

/// Helper for setting up granular cache in export commands.
enum GranularCacheHelper {
    /// Sets up granular cache based on options and config.
    /// - Parameters:
    ///   - trackingManager: The image tracking manager.
    ///   - cacheOptions: CLI cache options.
    ///   - configCacheEnabled: Whether cache is enabled in config.
    ///   - params: Export parameters (for file IDs).
    ///   - ui: Terminal UI for warnings.
    /// - Returns: Granular cache setup result.
    static func setup(
        trackingManager: ImageTrackingManager,
        cacheOptions: CacheOptions,
        configCacheEnabled: Bool,
        params: ExFig.ModuleImpl,
        ui: TerminalUI
    ) throws -> GranularCacheSetup {
        // Check for granular cache warning
        if let warning = cacheOptions.granularCacheWarning(configEnabled: configCacheEnabled) {
            ui.warning(warning)
        }

        // Determine if granular cache is enabled
        let enabled = cacheOptions.isGranularCacheEnabled(configEnabled: configCacheEnabled)

        // Clear node hashes if --force flag is set
        if cacheOptions.force, enabled {
            let fileIds = (params.figma?.lightFileId.map { [$0] } ?? []) +
                (params.figma?.darkFileId.map { [$0] } ?? [])
            for fileId in fileIds {
                try trackingManager.clearNodeHashes(fileId: fileId)
            }
        }

        // Create granular cache manager if enabled
        let manager: GranularCacheManager? = enabled
            ? trackingManager.createGranularCacheManager()
            : nil

        return GranularCacheSetup(manager: manager, enabled: enabled)
    }
}
