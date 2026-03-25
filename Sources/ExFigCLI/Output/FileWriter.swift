import ExFigCore
import Foundation
#if canImport(FoundationXML)
    import FoundationXML
#endif

/// Progress callback type for write operations
typealias WriteProgressCallback = @Sendable (Int, Int) async -> Void

/// Cache of parent directory contents for case mismatch detection.
/// Key: parent path, Value: lowercase name -> actual URL
private typealias ParentContentsCache = [String: [String: URL]]

final class FileWriter: Sendable {
    private let maxConcurrentWrites: Int

    init(maxConcurrentWrites: Int = 8) {
        self.maxConcurrentWrites = maxConcurrentWrites
    }

    /// Writes files sequentially (original behavior)
    func write(files: [FileContents]) throws {
        var parentCache: ParentContentsCache = [:]
        try files.forEach { file in
            try writeFile(file, parentCache: &parentCache)
        }
    }

    /// Writes files in parallel for ~2x speedup on large batches
    /// - Parameters:
    ///   - files: Files to write
    ///   - onProgress: Optional callback called with (current, total) after each write
    func writeParallel(
        files: [FileContents],
        onProgress: WriteProgressCallback? = nil
    ) async throws {
        guard !files.isEmpty else { return }

        let totalCount = files.count

        // 1. Collect unique directories and create them (sequential, fast)
        var parentCache: ParentContentsCache = [:]
        let directories = Set(files.map { URL(fileURLWithPath: $0.destination.url.deletingLastPathComponent().path) })
        for directory in directories {
            try fixCaseMismatchIfNeeded(for: directory, parentCache: &parentCache)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            updateCacheAfterCreation(directory: directory, parentCache: &parentCache)
        }

        // 2. Write files in parallel
        try await withThrowingTaskGroup(of: Void.self) { [self] group in
            var iterator = files.makeIterator()
            var activeCount = 0
            var writtenCount = 0

            // Start initial batch
            for _ in 0 ..< min(maxConcurrentWrites, files.count) {
                if let file = iterator.next() {
                    group.addTask { [file] in
                        try self.writeFileData(file)
                    }
                    activeCount += 1
                }
            }

            // Process completed and start new ones
            for try await _ in group {
                activeCount -= 1
                writtenCount += 1

                // Report progress
                if let onProgress {
                    await onProgress(writtenCount, totalCount)
                }

                if let file = iterator.next() {
                    group.addTask { [file] in
                        try self.writeFileData(file)
                    }
                    activeCount += 1
                }
            }
        }
    }

    func write(xmlFile: XMLDocument, directory: URL) throws {
        let fileURL = URL(fileURLWithPath: directory.path)
        let options: XMLNode.Options = [.nodePrettyPrint, .nodeCompactEmptyElement]
        try xmlFile.xmlData(options: options).write(to: fileURL, options: .atomic)
    }

    // MARK: - Private

    private func writeFile(_ file: FileContents, parentCache: inout ParentContentsCache) throws {
        let directoryURL = URL(fileURLWithPath: file.destination.url.deletingLastPathComponent().path)
        try fixCaseMismatchIfNeeded(for: directoryURL, parentCache: &parentCache)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)

        // Update cache with newly created directory
        updateCacheAfterCreation(directory: directoryURL, parentCache: &parentCache)

        try writeFileData(file)
    }

    /// Fixes directory name case mismatch on case-insensitive file systems (macOS).
    ///
    /// On case-insensitive FS, `speech2text.imageset` and `speech2Text.imageset` are the same directory.
    /// When asset name casing changes, the old directory name persists. This method renames it.
    ///
    /// Uses a cache to avoid re-scanning the same parent directory multiple times.
    private func fixCaseMismatchIfNeeded(for targetURL: URL, parentCache: inout ParentContentsCache) throws {
        let fileManager = FileManager.default
        let parent = targetURL.deletingLastPathComponent()
        let parentPath = parent.path
        let targetName = targetURL.lastPathComponent

        // Build cache on first access to this parent
        if parentCache[parentPath] == nil {
            guard fileManager.fileExists(atPath: parentPath) else { return }

            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: parent,
                    includingPropertiesForKeys: [.isDirectoryKey]
                )
                parentCache[parentPath] = contents.reduce(into: [:]) { map, item in
                    map[item.lastPathComponent.lowercased()] = item
                }
            } catch {
                // Non-fatal: case-mismatch detection unavailable for this directory.
                // Store empty sentinel to prevent repeated failed attempts.
                parentCache[parentPath] = [:]
            }
        }

        guard let lowercaseMap = parentCache[parentPath] else { return }

        let lowercaseName = targetName.lowercased()
        guard let existingItem = lowercaseMap[lowercaseName],
              existingItem.lastPathComponent != targetName
        else {
            return
        }

        // Rename via temp directory (direct rename fails on case-insensitive FS)
        let tempURL = parent.appendingPathComponent(UUID().uuidString)
        try fileManager.moveItem(at: existingItem, to: tempURL)
        try fileManager.moveItem(at: tempURL, to: targetURL)

        // Update cache after rename
        parentCache[parentPath]?[lowercaseName] = targetURL
    }

    /// Updates the parent cache after a directory is created.
    private func updateCacheAfterCreation(directory: URL, parentCache: inout ParentContentsCache) {
        let parent = directory.deletingLastPathComponent()
        let parentPath = parent.path
        parentCache[parentPath]?[directory.lastPathComponent.lowercased()] = directory
    }

    private func writeFileData(_ file: FileContents) throws {
        let fileURL = URL(fileURLWithPath: file.destination.url.path)
        let tracker = ManifestTrackerStorage.current

        if let data = file.data {
            // Capture pre-state before write (zero overhead when tracker is nil)
            let preState = tracker?.capturePreState(for: fileURL.path)
            try data.write(to: fileURL, options: .atomic)
            // Record only after successful write
            if let tracker, let preState {
                tracker.recordWrite(path: fileURL.path, data: data, preState: preState)
            }
        } else if let localFileURL = file.dataFile {
            // Capture pre-state before write
            let preState = tracker?.capturePreState(for: fileURL.path)
            // Remove existing file if present (copyItem fails if destination exists)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            try FileManager.default.copyItem(at: localFileURL, to: fileURL)
            // Record only after successful copy
            if let tracker, let preState {
                tracker.recordCopy(path: fileURL.path, sourceURL: localFileURL, preState: preState)
            }
        } else {
            fatalError("FileContents.data is nil. Use FileDownloader to download contents of the file.")
        }
    }
}
