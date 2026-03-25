import FigmaAPI
import Foundation
import Logging

/// Result of checking file versions for changes.
enum VersionCheckResult {
    /// All files have changed or are not in cache, full export needed.
    case exportNeeded(files: [FileVersionInfo])

    /// No files have changed, export can be skipped.
    case noChanges(files: [FileVersionInfo])

    /// Some files changed, some didn't (for multi-file exports).
    case partialChanges(changed: [FileVersionInfo], unchanged: [FileVersionInfo])
}

/// Information about a file's version status.
struct FileVersionInfo {
    let fileId: String
    let fileName: String
    let currentVersion: String
    let cachedVersion: String?
    let needsExport: Bool
}

/// Manages Figma file version tracking and caching.
/// Used to skip exports when files haven't changed since last export.
///
/// ## Batch Mode
///
/// When `batchMode` is true (detected via `BatchContextStorage.context?.isBatchMode`),
/// the manager uses shared cache instead of loading from disk, and defers
/// cache updates to the batch orchestrator.
final class ImageTrackingManager: @unchecked Sendable {
    private let client: Client
    private let cachePath: URL
    private let logger: Logger
    private var cache: ImageTrackingCache

    /// Whether running in batch mode (defers cache saves).
    let batchMode: Bool

    /// Creates a new tracking manager.
    /// - Parameters:
    ///   - client: Figma API client for fetching file metadata.
    ///   - cachePath: Path to the cache file (nil uses default).
    ///   - logger: Logger for debug output.
    ///   - batchMode: If true, uses shared cache and defers saves.
    init(client: Client, cachePath: String? = nil, logger: Logger, batchMode: Bool = false) {
        self.client = client
        self.logger = logger
        self.batchMode = batchMode

        // In batch mode, use shared cache if available
        if batchMode, let shared = BatchContextStorage.context?.granularCache {
            self.cachePath = shared.cachePath
            cache = shared.cache
            logger.debug("Using shared granular cache (batch mode)")
        } else {
            self.cachePath = ImageTrackingCache.resolvePath(customPath: cachePath)
            cache = ImageTrackingCache.load(from: self.cachePath)
        }
    }

    // MARK: - Version Checking

    /// Checks if any of the specified files have changed since last export.
    /// - Parameters:
    ///   - fileIds: List of Figma file IDs to check.
    ///   - force: If true, always returns exportNeeded regardless of cache.
    /// - Returns: Result indicating which files need export.
    func checkForChanges(fileIds: [String], force: Bool = false) async throws -> VersionCheckResult {
        // If force mode, skip cache check entirely
        if force {
            let infos = try await fetchFileVersions(fileIds: fileIds)
            return .exportNeeded(files: infos)
        }

        // Fetch current versions from Figma API
        let infos = try await fetchFileVersions(fileIds: fileIds)

        let changed = infos.filter(\.needsExport)
        let unchanged = infos.filter { !$0.needsExport }

        if changed.isEmpty {
            return .noChanges(files: unchanged)
        } else if unchanged.isEmpty {
            return .exportNeeded(files: changed)
        } else {
            return .partialChanges(changed: changed, unchanged: unchanged)
        }
    }

    /// Fetches file versions in parallel and compares with cache.
    private func fetchFileVersions(fileIds: [String]) async throws -> [FileVersionInfo] {
        try await withThrowingTaskGroup(of: FileVersionInfo.self) { [self] group in
            for fileId in fileIds {
                group.addTask { [fileId] in
                    let metadata = try await self.fetchFileMetadata(fileId: fileId)
                    let cachedVersion = self.cache.cachedVersion(for: fileId)
                    let needsExport = self.cache.needsExport(fileId: fileId, currentVersion: metadata.version)

                    return FileVersionInfo(
                        fileId: fileId,
                        fileName: metadata.name,
                        currentVersion: metadata.version,
                        cachedVersion: cachedVersion,
                        needsExport: needsExport
                    )
                }
            }

            var results: [FileVersionInfo] = []
            for try await info in group {
                results.append(info)
            }
            return results
        }
    }

    /// Fetches file metadata from Figma API or pre-fetched storage.
    ///
    /// In batch mode with `--cache`, file versions are pre-fetched before parallel
    /// config processing. This method checks the pre-fetched storage first to avoid
    /// redundant API calls when multiple configs reference the same file.
    private func fetchFileMetadata(fileId: String) async throws -> FileMetadata {
        // Check pre-fetched versions first (batch optimization)
        if let preFetched = BatchContextStorage.context?.versions,
           let metadata = preFetched.metadata(for: fileId)
        {
            logger.debug("Using pre-fetched version for \(fileId)")
            return metadata
        }

        // Fall back to API request (standalone mode or missing pre-fetch)
        let endpoint = FileMetadataEndpoint(fileId: fileId)
        return try await client.request(endpoint)
    }

    // MARK: - Cache Management

    /// Updates cache after successful export.
    /// - Parameters:
    ///   - fileInfos: File version information to cache.
    ///   - batchMode: If true, defers saving to disk (batch orchestrator handles final save).
    func updateCache(with fileInfos: [FileVersionInfo], batchMode: Bool = false) throws {
        for info in fileInfos {
            cache.updateFileVersion(
                fileId: info.fileId,
                version: info.currentVersion,
                fileName: info.fileName
            )
        }

        if !batchMode {
            try cache.save(to: cachePath)
            logger.info("Cache updated at \(cachePath.path)")
        } else {
            logger.debug("Cache update deferred (batch mode, \(fileInfos.count) files)")
        }
    }

    /// Updates cache for a single file after successful export.
    /// - Parameters:
    ///   - fileId: The Figma file ID.
    ///   - version: The file version.
    ///   - fileName: Optional file name.
    ///   - batchMode: If true, defers saving to disk (batch orchestrator handles final save).
    func updateCache(fileId: String, version: String, fileName: String? = nil, batchMode: Bool = false) throws {
        cache.updateFileVersion(fileId: fileId, version: version, fileName: fileName)

        if !batchMode {
            try cache.save(to: cachePath)
        }
    }

    /// Clears all cached data.
    func clearCache() throws {
        cache = ImageTrackingCache()
        try cache.save(to: cachePath)
        logger.info("Cache cleared")
    }

    /// Returns the current cache path.
    var currentCachePath: URL {
        cachePath
    }

    // MARK: - Granular Cache Operations

    /// Creates a GranularCacheManager using this manager's cache.
    func createGranularCacheManager() -> GranularCacheManager {
        GranularCacheManager(client: client, cache: cache)
    }

    /// Updates node hashes for a file after successful export.
    ///
    /// In batch mode, this is a no-op — the caller is responsible for collecting
    /// hashes via `ExportStats.computedNodeHashes` and the batch orchestrator
    /// will merge and save them after all configs complete.
    ///
    /// - Parameters:
    ///   - fileId: The Figma file ID.
    ///   - hashes: Map of node ID to computed hash.
    func updateNodeHashes(fileId: String, hashes: [NodeId: String]) throws {
        guard !batchMode else {
            logger.debug("Skipping node hash save in batch mode (\(hashes.count) hashes for \(fileId))")
            return
        }

        cache.updateNodeHashes(fileId: fileId, hashes: hashes)
        try cache.save(to: cachePath)
        logger.debug("Updated \(hashes.count) node hashes for \(fileId)")
    }

    /// Clears node hashes for a file (used with --force flag).
    ///
    /// In batch mode, this updates only the in-memory cache (shared).
    /// The batch orchestrator handles final persistence.
    func clearNodeHashes(fileId: String) throws {
        if batchMode {
            // In batch mode, just log — force clears are handled at batch start
            logger.debug("Force flag: node hashes will be cleared for \(fileId)")
            return
        }

        cache.clearNodeHashes(fileId: fileId)
        try cache.save(to: cachePath)
        logger.debug("Cleared node hashes for \(fileId)")
    }
}

// MARK: - Convenience Extensions

extension ImageTrackingManager {
    /// Checks if files need export based on light and optional dark file IDs.
    /// - Parameters:
    ///   - lightFileId: Light mode file ID.
    ///   - darkFileId: Optional dark mode file ID.
    ///   - force: If true, always returns exportNeeded.
    /// - Returns: Result indicating if export is needed.
    func checkForChanges(
        lightFileId: String,
        darkFileId: String? = nil,
        force: Bool = false
    ) async throws -> VersionCheckResult {
        var fileIds = [lightFileId]
        if let darkFileId, darkFileId != lightFileId {
            fileIds.append(darkFileId)
        }
        return try await checkForChanges(fileIds: fileIds, force: force)
    }
}
