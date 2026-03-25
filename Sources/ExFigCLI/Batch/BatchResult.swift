import Foundation

/// Represents a config file to be processed.
struct ConfigFile {
    /// URL to the config file.
    let url: URL
    /// Display name for the config.
    let name: String

    init(url: URL, name: String? = nil) {
        self.url = url
        self.name = name ?? url.lastPathComponent
    }
}

/// Statistics from an export operation.
struct ExportStats {
    let colors: Int
    let icons: Int
    let images: Int
    let typography: Int

    /// Computed node hashes for granular cache update (batch mode only).
    /// Maps fileId -> (nodeId -> hash).
    let computedNodeHashes: [String: [String: String]]

    /// Granular cache statistics (batch mode only).
    let granularCacheStats: GranularCacheStats?

    /// File version information for cache update (batch mode only).
    let fileVersions: [FileVersionInfo]?

    init(
        colors: Int = 0,
        icons: Int = 0,
        images: Int = 0,
        typography: Int = 0,
        computedNodeHashes: [String: [String: String]] = [:],
        granularCacheStats: GranularCacheStats? = nil,
        fileVersions: [FileVersionInfo]? = nil
    ) {
        self.colors = colors
        self.icons = icons
        self.images = images
        self.typography = typography
        self.computedNodeHashes = computedNodeHashes
        self.granularCacheStats = granularCacheStats
        self.fileVersions = fileVersions
    }

    static let zero = ExportStats()

    static func + (lhs: ExportStats, rhs: ExportStats) -> ExportStats {
        ExportStats(
            colors: lhs.colors + rhs.colors,
            icons: lhs.icons + rhs.icons,
            images: lhs.images + rhs.images,
            typography: lhs.typography + rhs.typography,
            computedNodeHashes: mergeHashes(lhs.computedNodeHashes, rhs.computedNodeHashes),
            granularCacheStats: GranularCacheStats.merge(lhs.granularCacheStats, rhs.granularCacheStats),
            fileVersions: mergeFileVersions(lhs.fileVersions, rhs.fileVersions)
        )
    }

    static func += (lhs: inout ExportStats, rhs: ExportStats) {
        lhs = lhs + rhs
    }

    /// Merges two hash dictionaries.
    private static func mergeHashes(
        _ lhs: [String: [String: String]],
        _ rhs: [String: [String: String]]
    ) -> [String: [String: String]] {
        var result = lhs
        for (fileId, hashes) in rhs {
            if let existing = result[fileId] {
                result[fileId] = existing.merging(hashes) { _, new in new }
            } else {
                result[fileId] = hashes
            }
        }
        return result
    }

    /// Merges file version arrays, preferring newer (rhs) versions for duplicate fileIds.
    private static func mergeFileVersions(
        _ lhs: [FileVersionInfo]?,
        _ rhs: [FileVersionInfo]?
    ) -> [FileVersionInfo]? {
        switch (lhs, rhs) {
        case let (l?, r?):
            // Merge arrays, preferring rhs for duplicate fileIds
            var merged: [String: FileVersionInfo] = [:]
            for version in l {
                merged[version.fileId] = version
            }
            for version in r {
                merged[version.fileId] = version // Overwrite with newer version
            }
            return Array(merged.values)
        case let (l?, nil):
            return l
        case let (nil, r?):
            return r
        case (nil, nil):
            return nil
        }
    }
}

/// Statistics about granular cache effectiveness.
struct GranularCacheStats {
    /// Number of nodes skipped (unchanged).
    let skipped: Int
    /// Number of nodes exported (changed or new).
    let exported: Int

    /// Total nodes processed.
    var total: Int {
        skipped + exported
    }

    /// Merges two stats, returning nil if both are nil.
    static func merge(_ lhs: GranularCacheStats?, _ rhs: GranularCacheStats?) -> GranularCacheStats? {
        switch (lhs, rhs) {
        case let (l?, r?):
            GranularCacheStats(skipped: l.skipped + r.skipped, exported: l.exported + r.exported)
        case let (l?, nil):
            l
        case let (nil, r?):
            r
        case (nil, nil):
            nil
        }
    }
}

/// Result of processing a single config.
enum ConfigResult {
    case success(config: ConfigFile, stats: ExportStats)
    case failure(config: ConfigFile, error: any Error)

    var config: ConfigFile {
        switch self {
        case let .success(config, _), let .failure(config, _):
            config
        }
    }

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var stats: ExportStats? {
        if case let .success(_, stats) = self {
            return stats
        }
        return nil
    }

    var error: (any Error)? {
        if case let .failure(_, error) = self {
            return error
        }
        return nil
    }
}

/// Result of batch processing multiple configs.
struct BatchResult {
    /// Results for each config processed.
    let results: [ConfigResult]
    /// Total duration of batch execution.
    let duration: TimeInterval
    /// When the batch started.
    let startTime: Date
    /// When the batch completed.
    let endTime: Date

    /// Number of successful configs.
    var successCount: Int {
        results.filter(\.isSuccess).count
    }

    /// Number of failed configs.
    var failureCount: Int {
        results.count - successCount
    }

    /// Aggregated stats from all successful configs.
    var totalStats: ExportStats {
        results.compactMap(\.stats).reduce(.zero, +)
    }

    /// Failed configs with their errors.
    var failures: [(config: ConfigFile, error: any Error)] {
        results.compactMap { result in
            if case let .failure(config, error) = result {
                return (config, error)
            }
            return nil
        }
    }

    /// Successful configs with their stats.
    var successes: [(config: ConfigFile, stats: ExportStats)] {
        results.compactMap { result in
            if case let .success(config, stats) = result {
                return (config, stats)
            }
            return nil
        }
    }
}
