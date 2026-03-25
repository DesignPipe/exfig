import ExFigCore
import Foundation

/// Represents a batch of files to download for a specific config.
/// Used by SharedDownloadQueue to coordinate downloads across multiple configs.
struct DownloadJob {
    /// Unique identifier for this job
    let id: UUID

    /// Files to download (only remote files with sourceURL)
    let files: [FileContents]

    /// Config identifier for tracking and cancellation
    let configId: String

    /// Priority level (lower = higher priority, for FIFO ordering)
    let priority: Int

    /// Total number of files in this job (for progress tracking)
    var fileCount: Int {
        files.count
    }

    init(
        id: UUID = UUID(),
        files: [FileContents],
        configId: String,
        priority: Int = 0
    ) {
        self.id = id
        self.files = files
        self.configId = configId
        self.priority = priority
    }
}

/// Result of a completed download job
struct DownloadJobResult {
    let jobId: UUID
    let configId: String
    let downloadedFiles: [FileContents]
    let duration: TimeInterval
}
