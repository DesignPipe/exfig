import ExFigCore
import Foundation
import Logging
#if os(Linux)
    import FoundationNetworking
#endif

/// Progress callback type for download operations
typealias DownloadProgressCallback = @Sendable (Int, Int) async -> Void

/// Validates that a download URL uses HTTPS and has a valid host.
/// Shared by both `FileDownloader` and `SharedDownloadQueue`.
func validateDownloadURL(_ url: URL) throws {
    // Allow file:// URLs for locally reconstructed assets (e.g., Penpot SVG from shape tree)
    if url.isFileURL { return }

    guard url.scheme?.lowercased() == "https" else {
        throw URLError(
            .badURL,
            userInfo: [NSLocalizedDescriptionKey: "Download URL must use HTTPS scheme, got: \(url.scheme ?? "nil")"]
        )
    }
    guard let host = url.host, !host.isEmpty else {
        throw URLError(
            .badURL,
            userInfo: [NSLocalizedDescriptionKey: "Download URL must have a valid host"]
        )
    }
}

final class FileDownloader: Sendable {
    private let logger = Logger(label: "com.designpipe.exfig.file-downloader")
    private let session: URLSession

    /// Default concurrent downloads for CDN (S3/Cloudflare can handle high concurrency)
    static let defaultMaxConcurrentDownloads = 20

    init(maxConcurrentDownloads: Int = defaultMaxConcurrentDownloads) {
        let config = URLSessionConfiguration.ephemeral
        config.httpMaximumConnectionsPerHost = maxConcurrentDownloads
        session = URLSession(configuration: config)
    }

    /// Fetch files with optional progress callback
    /// - Parameters:
    ///   - files: Files to download
    ///   - onProgress: Optional callback called with (current, total) after each download
    /// - Returns: Downloaded files with local URLs
    func fetch(
        files: [FileContents],
        onProgress: DownloadProgressCallback? = nil
    ) async throws -> [FileContents] {
        let remoteFiles = files.filter { $0.sourceURL != nil }
        let localFiles = files.filter { $0.sourceURL == nil }
        let remoteFileCount = remoteFiles.count

        if remoteFiles.isEmpty {
            return localFiles
        }

        let maxConcurrentDownloads = session.configuration.httpMaximumConnectionsPerHost

        return try await withThrowingTaskGroup(of: FileContents.self) { group in
            var results = localFiles
            var downloadedCount = 0
            var iterator = remoteFiles.makeIterator()
            var activeTaskCount = 0

            // Start initial batch of concurrent downloads
            for _ in 0 ..< min(maxConcurrentDownloads, remoteFiles.count) {
                if let file = iterator.next() {
                    group.addTask {
                        try await self.downloadFile(file)
                    }
                    activeTaskCount += 1
                }
            }

            // Process completed downloads and start new ones
            for try await downloadedFile in group {
                results.append(downloadedFile)
                downloadedCount += 1
                activeTaskCount -= 1

                // Report progress via callback or logger
                if let onProgress {
                    await onProgress(downloadedCount, remoteFileCount)
                } else {
                    logger.info("Downloaded \(downloadedCount)/\(remoteFileCount)")
                }

                // Start next download if there are more files
                if let file = iterator.next() {
                    group.addTask {
                        try await self.downloadFile(file)
                    }
                    activeTaskCount += 1
                }
            }

            return results
        }
    }

    private func downloadFile(_ file: FileContents) async throws -> FileContents {
        guard let remoteURL = file.sourceURL else {
            return file
        }

        try validateDownloadURL(remoteURL)

        // Local files (e.g., Penpot SVG reconstructed from shape tree) — already on disk
        if remoteURL.isFileURL {
            return FileContents(
                destination: file.destination,
                dataFile: remoteURL,
                scale: file.scale,
                dark: file.dark,
                isRTL: file.isRTL
            )
        }

        let (localURL, _) = try await session.download(from: remoteURL)

        return FileContents(
            destination: file.destination,
            dataFile: localURL,
            scale: file.scale,
            dark: file.dark,
            isRTL: file.isRTL
        )
    }
}
