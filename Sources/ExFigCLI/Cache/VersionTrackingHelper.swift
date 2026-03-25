import ExFigConfig
import FigmaAPI
import Foundation
import Logging

/// Result of version tracking check for export commands.
enum VersionTrackingCheckResult {
    /// Export should be skipped - no changes detected.
    case skipExport

    /// Export should proceed with the given manager and file versions.
    case proceed(manager: ImageTrackingManager, versions: [FileVersionInfo])
}

/// Configuration for version tracking check.
struct VersionTrackingConfig {
    let client: Client
    let params: ExFig.ModuleImpl
    let cacheOptions: CacheOptions
    let configCacheEnabled: Bool
    let configCachePath: String?
    let assetType: String
    let ui: TerminalUI
    let logger: Logger
    /// Whether running in batch mode (defers cache saves, uses shared granular cache).
    let batchMode: Bool

    init(
        client: Client,
        params: ExFig.ModuleImpl,
        cacheOptions: CacheOptions,
        configCacheEnabled: Bool,
        configCachePath: String?,
        assetType: String,
        ui: TerminalUI,
        logger: Logger,
        batchMode: Bool = false
    ) {
        self.client = client
        self.params = params
        self.cacheOptions = cacheOptions
        self.configCacheEnabled = configCacheEnabled
        self.configCachePath = configCachePath
        self.assetType = assetType
        self.ui = ui
        self.logger = logger
        self.batchMode = batchMode
    }
}

/// Helper for version tracking in export commands.
/// Encapsulates the common pattern of checking file versions and reporting status.
enum VersionTrackingHelper {
    /// Checks for file version changes and reports status to the UI.
    ///
    /// - Parameter config: Version tracking configuration.
    /// - Returns: Check result indicating whether to skip or proceed with export.
    static func checkForChanges(config: VersionTrackingConfig) async throws -> VersionTrackingCheckResult {
        let cacheEnabled = config.cacheOptions.isEnabled(configEnabled: config.configCacheEnabled)

        guard cacheEnabled else {
            return .proceed(
                manager: createDummyManager(
                    client: config.client,
                    logger: config.logger,
                    batchMode: config.batchMode
                ),
                versions: []
            )
        }

        let cachePath = config.cacheOptions.resolvePath(configPath: config.configCachePath)
        let manager = ImageTrackingManager(
            client: config.client,
            cachePath: cachePath,
            logger: config.logger,
            batchMode: config.batchMode
        )

        // Collect all file IDs from configuration using FileIdProvider protocol
        let fileIds = Array(config.params.getFileIds())

        let result = try await config.ui.withSpinner("Checking for changes...") {
            try await manager.checkForChanges(fileIds: fileIds, force: config.cacheOptions.force)
        }

        return handleResult(
            result,
            manager: manager,
            assetType: config.assetType,
            cacheOptions: config.cacheOptions,
            ui: config.ui
        )
    }

    /// Handles the version check result and reports status to UI.
    private static func handleResult(
        _ result: VersionCheckResult,
        manager: ImageTrackingManager,
        assetType: String,
        cacheOptions: CacheOptions,
        ui: TerminalUI
    ) -> VersionTrackingCheckResult {
        switch result {
        case let .noChanges(files):
            ui.success("No changes detected. \(assetType) are up to date.")
            for file in files {
                ui.info("  - \(file.fileName): version \(file.currentVersion) (unchanged)")
            }
            return .skipExport

        case let .exportNeeded(files):
            if cacheOptions.force {
                ui.info("Force export requested.")
            } else {
                ui.info("Changes detected, exporting...")
            }
            reportFileVersions(files, ui: ui)
            return .proceed(manager: manager, versions: files)

        case let .partialChanges(changed, unchanged):
            ui.info("Partial changes detected:")
            for file in changed {
                ui.info("  - \(file.fileName): \(file.cachedVersion ?? "new") -> \(file.currentVersion)")
            }
            for file in unchanged {
                ui.info("  - \(file.fileName): unchanged")
            }
            return .proceed(manager: manager, versions: changed + unchanged)
        }
    }

    /// Reports file version changes to UI.
    private static func reportFileVersions(_ files: [FileVersionInfo], ui: TerminalUI) {
        for file in files {
            if let cached = file.cachedVersion {
                ui.info("  - \(file.fileName): \(cached) -> \(file.currentVersion)")
            } else {
                ui.info("  - \(file.fileName): version \(file.currentVersion) (new)")
            }
        }
    }

    /// Creates a dummy manager for when cache is disabled (no-op for updateCache).
    private static func createDummyManager(
        client: Client,
        logger: Logger,
        batchMode: Bool = false
    ) -> ImageTrackingManager {
        // When cache is disabled, we still return a manager but won't call updateCache
        ImageTrackingManager(client: client, cachePath: nil, logger: logger, batchMode: batchMode)
    }

    /// Updates cache after successful export if versions are available.
    /// In batch mode, defers cache save to the batch orchestrator.
    static func updateCacheIfNeeded(
        manager: ImageTrackingManager?,
        versions: [FileVersionInfo]
    ) throws {
        guard let manager, !versions.isEmpty else { return }
        // Pass manager's batchMode flag to defer saves in batch mode
        try manager.updateCache(with: versions, batchMode: manager.batchMode)
    }
}
