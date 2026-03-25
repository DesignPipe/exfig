import ExFigCore
import Foundation

/// Tracks file write operations for asset manifest generation.
///
/// Uses a two-phase API: `capturePreState` before write, `recordWrite`/`recordCopy`
/// after successful write. This ensures entries are only recorded for files that
/// were actually written, and action detection (created/modified/unchanged) uses
/// the correct pre-write filesystem state.
///
/// Uses `Lock<[ManifestEntry]>` for thread-safe access without requiring `await`,
/// eliminating the `DispatchSemaphore` bridge that was needed with the actor version.
/// Only active when `--report` is specified — zero overhead otherwise.
///
/// Initialized with a default `assetType` since each export command handles
/// one asset type (colors/icons/images/typography).
final class ManifestTracker: Sendable {
    private let entries = Lock<[ManifestEntry]>([])

    /// Default asset type for all recorded entries.
    let defaultAssetType: String

    private let workingDirectory: String

    init(assetType: String) {
        defaultAssetType = assetType
        workingDirectory = FileManager.default.currentDirectoryPath
    }

    /// Pre-write filesystem state for a file path.
    struct PreWriteState {
        let fileExisted: Bool
        let existingChecksum: String?
    }

    /// Capture filesystem state before writing a file.
    ///
    /// Must be called BEFORE the file is written to disk, so that existing content
    /// can be compared for action detection (created vs. modified vs. unchanged).
    func capturePreState(for path: String) -> PreWriteState {
        if let existingData = FileManager.default.contents(atPath: path) {
            PreWriteState(fileExisted: true, existingChecksum: FNV1aHasher.hashToHex(existingData))
        } else {
            PreWriteState(fileExisted: false, existingChecksum: nil)
        }
    }

    /// Record a file write operation after successful write.
    ///
    /// - Parameters:
    ///   - path: Absolute path to the written file.
    ///   - data: Content that was written (used for checksum).
    ///   - preState: Pre-write state captured via `capturePreState(for:)`.
    ///   - assetType: Type of asset. Defaults to tracker's `defaultAssetType`.
    func recordWrite(path: String, data: Data, preState: PreWriteState, assetType: String? = nil) {
        let assetType = assetType ?? defaultAssetType
        let relativePath = makeRelativePath(path)
        let newChecksum = FNV1aHasher.hashToHex(data)
        let action = determineAction(preState: preState, newChecksum: newChecksum)

        entries.withLock {
            $0.append(ManifestEntry(
                path: relativePath,
                action: action,
                checksum: newChecksum,
                assetType: assetType
            ))
        }
    }

    /// Record a file copy operation after successful copy.
    ///
    /// - Parameters:
    ///   - path: Absolute path to the destination file.
    ///   - sourceURL: URL of the source file that was copied.
    ///   - preState: Pre-write state captured via `capturePreState(for:)`.
    ///   - assetType: Type of asset. Defaults to tracker's `defaultAssetType`.
    func recordCopy(path: String, sourceURL: URL, preState: PreWriteState, assetType: String? = nil) {
        let assetType = assetType ?? defaultAssetType
        let relativePath = makeRelativePath(path)

        // Read copied file from destination (it was just written successfully)
        let newChecksum: String? = if let destData = FileManager.default.contents(atPath: path) {
            FNV1aHasher.hashToHex(destData)
        } else if let sourceData = try? Data(contentsOf: sourceURL) {
            FNV1aHasher.hashToHex(sourceData)
        } else {
            nil
        }

        if newChecksum == nil {
            WarningCollectorStorage.current?.add("Manifest: could not compute checksum for \(relativePath)")
        }

        let action = determineAction(preState: preState, newChecksum: newChecksum)

        entries.withLock {
            $0.append(ManifestEntry(
                path: relativePath,
                action: action,
                checksum: newChecksum,
                assetType: assetType
            ))
        }
    }

    /// Get all recorded manifest entries.
    func getAll() -> [ManifestEntry] {
        entries.withLock { $0 }
    }

    /// Build an `AssetManifest` from recorded entries.
    ///
    /// If `previousReportPath` is provided, detects deleted files by comparing
    /// against the previous report's manifest.
    func buildManifest(previousReportPath: String? = nil) -> AssetManifest {
        var allEntries = entries.withLock { $0 }

        if let previousPath = previousReportPath,
           let previousData = FileManager.default.contents(atPath: previousPath)
        {
            do {
                let previousReport = try JSONCodec.decode(PreviousReportManifest.self, from: previousData)
                let currentPaths = Set(allEntries.map(\.path))
                for previousEntry in previousReport.manifest?.files ?? []
                    where !currentPaths.contains(previousEntry.path)
                {
                    allEntries.append(ManifestEntry(
                        path: previousEntry.path,
                        action: .deleted,
                        checksum: nil,
                        assetType: previousEntry.assetType
                    ))
                }
            } catch {
                let message = "Could not read previous report at \(previousPath): "
                    + "\(error.localizedDescription). Deleted file detection skipped."
                WarningCollectorStorage.current?.add(message)
            }
        }

        return AssetManifest(files: allEntries)
    }

    /// Determine file action based on pre-write state and new checksum.
    private func determineAction(preState: PreWriteState, newChecksum: String?) -> FileAction {
        if !preState.fileExisted {
            .created
        } else if let existingChecksum = preState.existingChecksum, let newChecksum {
            existingChecksum == newChecksum ? .unchanged : .modified
        } else {
            .modified
        }
    }

    /// Make path relative to working directory captured at init time.
    private func makeRelativePath(_ absolutePath: String) -> String {
        if absolutePath.hasPrefix(workingDirectory + "/") {
            return String(absolutePath.dropFirst(workingDirectory.count + 1))
        }
        return absolutePath
    }
}

/// Lightweight Decodable for reading only the manifest from a previous report.
private struct PreviousReportManifest: Decodable {
    let manifest: PreviousManifest?

    struct PreviousManifest: Decodable {
        let files: [PreviousEntry]
    }

    struct PreviousEntry: Decodable {
        let path: String
        let assetType: String
    }
}

/// Global storage for the active manifest tracker.
///
/// Same pattern as `WarningCollectorStorage` — `nonisolated(unsafe)` static var.
enum ManifestTrackerStorage {
    nonisolated(unsafe) static var current: ManifestTracker?
}
