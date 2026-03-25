import ExFigCore
import Foundation
import Logging

/// Cache model for tracking Figma file versions and node hashes.
/// Used to skip exports when files haven't changed since last export.
///
/// Schema versions:
/// - v1: File-level version tracking only
/// - v2: Added per-node hash tracking for granular cache (experimental)
struct ImageTrackingCache: Codable {
    /// Current schema version for cache file format.
    /// v2 adds nodeHashes field to CachedFileInfo.
    static let currentSchemaVersion = 2

    /// Default cache file name.
    static let defaultFileName = ".exfig-cache.json"

    /// Schema version for cache format migration.
    let schemaVersion: Int

    /// Cached file versions keyed by file ID.
    var files: [String: CachedFileInfo]

    /// Creates a new empty cache.
    init() {
        schemaVersion = Self.currentSchemaVersion
        files = [:]
    }

    /// Creates cache with existing data.
    init(schemaVersion: Int, files: [String: CachedFileInfo]) {
        self.schemaVersion = schemaVersion
        self.files = files
    }
}

// MARK: - CachedFileInfo

/// Information about a cached Figma file.
struct CachedFileInfo: Codable {
    /// Figma file version identifier.
    /// Changes when library is published or version is manually saved.
    let version: String

    /// ISO 8601 timestamp of last successful export.
    let lastExport: String

    /// Optional: file name for debugging/display purposes.
    let fileName: String?

    /// Optional: per-node content hashes for granular change detection.
    /// Maps node ID (e.g., "1:23") to FNV-1a 64-bit hash hex string.
    /// Only populated when `--experimental-granular-cache` is used.
    var nodeHashes: [String: String]?

    /// Creates cached file info.
    init(
        version: String,
        lastExport: Date = Date(),
        fileName: String? = nil,
        nodeHashes: [String: String]? = nil
    ) {
        self.version = version
        self.lastExport = ISO8601DateFormatter().string(from: lastExport)
        self.fileName = fileName
        self.nodeHashes = nodeHashes
    }
}

// MARK: - Cache Persistence

extension ImageTrackingCache {
    private static let logger = Logger(label: "com.designpipe.exfig.image-tracking-cache")

    /// Loads cache from a file at the specified path.
    /// Returns an empty cache if file doesn't exist or is invalid.
    /// Migrates from older schema versions automatically.
    static func load(from path: URL) -> ImageTrackingCache {
        guard FileManager.default.fileExists(atPath: path.path) else {
            return ImageTrackingCache()
        }

        do {
            let data = try Data(contentsOf: path)
            let cache = try JSONCodec.decode(ImageTrackingCache.self, from: data)

            // Migration: v1 → v2 (nodeHashes field added, backward compatible)
            if cache.schemaVersion < currentSchemaVersion {
                // v1 files decode fine with v2 schema (nodeHashes will be nil)
                // Return with updated schema version
                return ImageTrackingCache(
                    schemaVersion: currentSchemaVersion,
                    files: cache.files
                )
            }

            return cache
        } catch {
            // Log the error - helps diagnose cache compatibility issues after migrations
            logger.warning(
                "Cache file corrupted or incompatible, starting with empty cache",
                metadata: [
                    "path": "\(path.path)",
                    "error": "\(error.localizedDescription)",
                ]
            )
            return ImageTrackingCache()
        }
    }

    /// Saves cache to a file at the specified path.
    func save(to path: URL) throws {
        let data = try JSONCodec.encodePretty(self)
        try data.write(to: path, options: .atomic)
    }

    /// Resolves cache file path from optional custom path.
    static func resolvePath(customPath: String?) -> URL {
        if let customPath {
            return URL(fileURLWithPath: customPath)
        }
        return URL(fileURLWithPath: defaultFileName)
    }
}

// MARK: - Cache Operations

extension ImageTrackingCache {
    /// Checks if file version has changed since last export.
    /// Returns true if export is needed (version changed or file not in cache).
    func needsExport(fileId: String, currentVersion: String) -> Bool {
        guard let cached = files[fileId] else {
            // File not in cache, needs export
            return true
        }
        return cached.version != currentVersion
    }

    /// Updates cache with new file version after successful export.
    mutating func updateFileVersion(fileId: String, version: String, fileName: String? = nil) {
        let existingHashes = files[fileId]?.nodeHashes
        files[fileId] = CachedFileInfo(
            version: version,
            lastExport: Date(),
            fileName: fileName,
            nodeHashes: existingHashes
        )
    }

    /// Returns cached version for a file, if available.
    func cachedVersion(for fileId: String) -> String? {
        files[fileId]?.version
    }
}

// MARK: - Node Hash Operations

extension ImageTrackingCache {
    /// Returns node IDs that have changed compared to cached hashes.
    ///
    /// - Parameters:
    ///   - fileId: The Figma file ID.
    ///   - currentHashes: Map of node ID to current hash for all nodes to export.
    /// - Returns: Array of node IDs that need re-export (new or changed).
    ///            Deleted nodes (in cache but not in currentHashes) are excluded.
    func changedNodeIds(fileId: String, currentHashes: [String: String]) -> [String] {
        guard let cachedInfo = files[fileId],
              let cachedHashes = cachedInfo.nodeHashes
        else {
            // No cached hashes, all nodes need export
            return Array(currentHashes.keys)
        }

        var changedIds: [String] = []

        for (nodeId, currentHash) in currentHashes {
            if let cachedHash = cachedHashes[nodeId] {
                // Node exists in cache - check if hash changed
                if cachedHash != currentHash {
                    changedIds.append(nodeId)
                }
            } else {
                // New node not in cache
                changedIds.append(nodeId)
            }
        }

        // Note: Deleted nodes (in cachedHashes but not in currentHashes)
        // are silently ignored - they will be cleaned up when cache is saved

        return changedIds
    }

    /// Updates node hashes for a file after successful export.
    ///
    /// - Parameters:
    ///   - fileId: The Figma file ID.
    ///   - hashes: Map of node ID to hash for all exported nodes.
    /// - Note: Merges with existing hashes (new hashes overwrite old for same nodeId).
    mutating func updateNodeHashes(fileId: String, hashes: [String: String]) {
        guard var fileInfo = files[fileId] else { return }

        // Merge with existing hashes instead of replacing
        if var existingHashes = fileInfo.nodeHashes {
            existingHashes.merge(hashes) { _, new in new }
            fileInfo.nodeHashes = existingHashes
        } else {
            fileInfo.nodeHashes = hashes
        }

        files[fileId] = fileInfo
    }

    /// Clears node hashes for a file (used with --force flag).
    ///
    /// - Parameter fileId: The Figma file ID.
    mutating func clearNodeHashes(fileId: String) {
        guard var fileInfo = files[fileId] else { return }
        fileInfo.nodeHashes = nil
        files[fileId] = fileInfo
    }

    /// Clears node hashes for all files (used with --force flag in batch mode).
    mutating func clearAllNodeHashes() {
        for fileId in files.keys {
            files[fileId]?.nodeHashes = nil
        }
    }
}
