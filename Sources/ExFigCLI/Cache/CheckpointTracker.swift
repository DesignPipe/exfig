import ExFigCore
import Foundation

/// Actor for managing export checkpoints in individual commands.
///
/// Provides thread-safe checkpoint management for icons and images exports,
/// enabling resumption after interruptions.
actor CheckpointTracker {
    /// Type of asset being tracked.
    enum AssetType {
        case icons
        case images
    }

    private var checkpoint: ExportCheckpoint
    private let directory: URL
    private let assetType: AssetType
    private var savesPending = 0
    private let saveThreshold = 5 // Save every N updates

    /// Initialize a new checkpoint tracker.
    /// - Parameters:
    ///   - configPath: Path to the config file for hash validation.
    ///   - directory: Directory to save checkpoint file in.
    ///   - assetType: Type of assets being tracked.
    ///   - assetNames: Initial set of asset names to track.
    init(
        configPath: String,
        directory: URL,
        assetType: AssetType,
        assetNames: Set<String>
    ) throws {
        self.directory = directory
        self.assetType = assetType

        let configHash = try ExportCheckpoint.computeConfigHash(
            from: URL(fileURLWithPath: configPath)
        )

        let pending = switch assetType {
        case .icons:
            ExportCheckpoint.PendingItems(icons: assetNames)
        case .images:
            ExportCheckpoint.PendingItems(images: assetNames)
        }

        checkpoint = ExportCheckpoint(
            configPath: configPath,
            configHash: configHash,
            pending: pending
        )
    }

    /// Try to load existing checkpoint for resumption.
    /// - Parameters:
    ///   - configPath: Path to config file.
    ///   - directory: Directory containing checkpoint file.
    ///   - assetType: Type of assets being tracked.
    /// - Returns: Loaded tracker if valid checkpoint exists, nil otherwise.
    static func loadIfValid(
        configPath: String,
        directory: URL,
        assetType: AssetType
    ) throws -> CheckpointTracker? {
        guard let existing = try ExportCheckpoint.load(from: directory) else {
            return nil
        }

        // Check expiration
        if existing.isExpired() {
            try ExportCheckpoint.delete(from: directory)
            return nil
        }

        // Check config hash
        let currentHash = try ExportCheckpoint.computeConfigHash(
            from: URL(fileURLWithPath: configPath)
        )
        guard existing.matchesConfig(hash: currentHash) else {
            try ExportCheckpoint.delete(from: directory)
            return nil
        }

        return CheckpointTracker(existing: existing, directory: directory, assetType: assetType)
    }

    /// Private init for loading existing checkpoint.
    private init(existing: ExportCheckpoint, directory: URL, assetType: AssetType) {
        checkpoint = existing
        self.directory = directory
        self.assetType = assetType
    }

    /// Get completed asset names.
    var completedNames: Set<String> {
        switch assetType {
        case .icons:
            checkpoint.completed.icons
        case .images:
            checkpoint.completed.images
        }
    }

    /// Get pending asset names.
    var pendingNames: Set<String> {
        switch assetType {
        case .icons:
            checkpoint.pending.icons
        case .images:
            checkpoint.pending.images
        }
    }

    /// Mark an asset as completed.
    /// - Parameter name: Name of the completed asset.
    func markCompleted(_ name: String) {
        switch assetType {
        case .icons:
            checkpoint.markIconCompleted(name)
        case .images:
            checkpoint.markImageCompleted(name)
        }

        savesPending += 1
        if savesPending >= saveThreshold {
            try? checkpoint.save(to: directory)
            savesPending = 0
        }
    }

    /// Mark multiple assets as completed.
    /// - Parameter names: Names of completed assets.
    func markCompleted(_ names: [String]) {
        for name in names {
            switch assetType {
            case .icons:
                checkpoint.markIconCompleted(name)
            case .images:
                checkpoint.markImageCompleted(name)
            }
        }
        try? checkpoint.save(to: directory)
        savesPending = 0
    }

    /// Force save checkpoint to disk.
    func save() throws {
        try checkpoint.save(to: directory)
        savesPending = 0
    }

    /// Delete checkpoint (call on successful completion).
    func delete() throws {
        try ExportCheckpoint.delete(from: directory)
    }

    /// Check if all assets are completed.
    var isComplete: Bool {
        switch assetType {
        case .icons:
            checkpoint.pending.icons.isEmpty
        case .images:
            checkpoint.pending.images.isEmpty
        }
    }
}

// MARK: - File Filtering Extension

extension CheckpointTracker {
    /// Filter file contents to exclude already-downloaded files.
    /// - Parameter files: All files to potentially download.
    /// - Returns: Files that haven't been downloaded yet.
    func filterPending(_ files: [FileContents]) -> [FileContents] {
        let completed = completedNames
        return files.filter { file in
            let name = file.destination.file.deletingPathExtension().lastPathComponent
            return !completed.contains(name)
        }
    }
}
