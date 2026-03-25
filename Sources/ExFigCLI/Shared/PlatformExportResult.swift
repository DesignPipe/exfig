import FigmaAPI
import Foundation

/// Result of a platform export operation with granular cache hashes.
/// Used by ExportIcons and ExportImages for consistent result aggregation.
struct PlatformExportResult {
    /// Number of assets exported.
    let count: Int
    /// Per-file node hashes computed during export.
    let hashes: [String: [NodeId: String]]
    /// Number of assets skipped by granular cache.
    let skippedCount: Int

    init(count: Int, hashes: [String: [NodeId: String]], skippedCount: Int = 0) {
        self.count = count
        self.hashes = hashes
        self.skippedCount = skippedCount
    }
}
