import ExFigCore
import Foundation
import Logging
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Progress callback for individual jobs
typealias JobProgressCallback = @Sendable (Int, Int) async -> Void

/// Actor that coordinates file downloads across multiple configs in batch mode.
/// Downloads are processed in parallel with configurable concurrency.
actor SharedDownloadQueue {
    private let logger = Logger(label: "com.designpipe.exfig.shared-download-queue")
    private let session: URLSession
    private let maxConcurrentDownloads: Int

    /// Pending jobs waiting to be processed
    private var pendingJobs: [DownloadJob] = []

    /// Currently active download tasks by job ID
    private var activeJobs: Set<UUID> = []

    /// Completed job results by job ID
    private var completedResults: [UUID: DownloadJobResult] = [:]

    /// Order of completed results for LRU eviction (oldest first)
    private var completedResultsOrder: [UUID] = []

    /// Maximum number of unclaimed results to keep (prevents memory leak if waitForCompletion not called)
    private let maxUnclaimedResults = 100

    /// Continuations waiting for job completion
    private var jobCompletionContinuations: [UUID: CheckedContinuation<DownloadJobResult, Error>] = [:]

    /// Active download count for backpressure
    private var activeDownloadCount = 0

    /// Total downloads completed (for stats)
    private var totalDownloadsCompleted = 0

    /// Whether the queue is currently processing
    private var isProcessing = false

    /// Cancelled config IDs
    private var cancelledConfigs: Set<String> = []

    init(maxConcurrentDownloads: Int = FileDownloader.defaultMaxConcurrentDownloads) {
        self.maxConcurrentDownloads = maxConcurrentDownloads
        let config = URLSessionConfiguration.ephemeral
        config.httpMaximumConnectionsPerHost = maxConcurrentDownloads
        session = URLSession(configuration: config)
    }

    /// Submit a download job to the queue.
    /// Returns immediately; use `waitForCompletion(jobId:)` to wait for results.
    func submit(job: DownloadJob) {
        guard !cancelledConfigs.contains(job.configId) else {
            logger.debug("Job \(job.id) skipped - config \(job.configId) is cancelled")
            return
        }

        pendingJobs.append(job)
        pendingJobs.sort { $0.priority < $1.priority }

        logger.debug(
            "Job submitted: \(job.id) config=\(job.configId) files=\(job.fileCount) pending=\(pendingJobs.count)"
        )
    }

    /// Submit a job and immediately start processing.
    /// Returns the job ID for tracking.
    @discardableResult
    func submitAndProcess(job: DownloadJob) async -> UUID {
        submit(job: job)
        await processNextJobs()
        return job.id
    }

    /// Wait for a specific job to complete and return its result.
    func waitForCompletion(jobId: UUID) async throws -> DownloadJobResult {
        // Check if already completed
        if let result = completedResults.removeValue(forKey: jobId) {
            completedResultsOrder.removeAll { $0 == jobId }
            return result
        }

        // Wait for completion
        return try await withCheckedThrowingContinuation { continuation in
            jobCompletionContinuations[jobId] = continuation
        }
    }

    /// Cancel all pending jobs for a specific config.
    func cancelConfig(_ configId: String) {
        cancelledConfigs.insert(configId)
        pendingJobs.removeAll { $0.configId == configId }
        logger.info("Cancelled all jobs for config: \(configId)")
    }

    /// Get queue statistics
    func stats() -> QueueStats {
        QueueStats(
            pendingJobs: pendingJobs.count,
            activeJobs: activeJobs.count,
            activeDownloads: activeDownloadCount,
            totalCompleted: totalDownloadsCompleted,
            maxConcurrent: maxConcurrentDownloads
        )
    }

    /// Process pending jobs up to concurrency limit
    private func processNextJobs() async {
        guard !isProcessing else { return }
        isProcessing = true

        defer { isProcessing = false }

        while !pendingJobs.isEmpty, activeDownloadCount < maxConcurrentDownloads {
            let job = pendingJobs.removeFirst()

            guard !cancelledConfigs.contains(job.configId) else {
                continue
            }

            activeJobs.insert(job.id)

            // Process job in background
            Task {
                await processJob(job)
            }
        }
    }

    /// Process a single download job
    private func processJob(_ job: DownloadJob) async {
        let startTime = Date()

        do {
            let downloadedFiles = try await downloadFiles(job.files)
            let duration = Date().timeIntervalSince(startTime)

            let result = DownloadJobResult(
                jobId: job.id,
                configId: job.configId,
                downloadedFiles: downloadedFiles,
                duration: duration
            )

            completeJob(job.id, result: .success(result))

        } catch {
            logger.error("Job \(job.id) failed: \(error)")
            completeJob(job.id, result: .failure(error))
        }
    }

    /// Mark job as complete and notify waiters
    private func completeJob(_ jobId: UUID, result: Result<DownloadJobResult, Error>) {
        activeJobs.remove(jobId)

        switch result {
        case let .success(downloadResult):
            if let continuation = jobCompletionContinuations.removeValue(forKey: jobId) {
                continuation.resume(returning: downloadResult)
            } else {
                // Store result for later retrieval
                completedResults[jobId] = downloadResult
                completedResultsOrder.append(jobId)
                evictOldResultsIfNeeded()
            }

        case let .failure(error):
            if let continuation = jobCompletionContinuations.removeValue(forKey: jobId) {
                continuation.resume(throwing: error)
            }
            // Failed jobs without waiters are not cached (no result to return)
        }

        // Trigger processing of next jobs
        Task {
            await processNextJobs()
        }
    }

    /// Remove oldest unclaimed results if cache exceeds limit
    private func evictOldResultsIfNeeded() {
        while completedResults.count > maxUnclaimedResults {
            guard let oldestId = completedResultsOrder.first else { break }
            completedResultsOrder.removeFirst()
            if let evicted = completedResults.removeValue(forKey: oldestId) {
                logger.debug("Evicted unclaimed result: job=\(oldestId) config=\(evicted.configId)")
            }
        }
    }

    /// Download files with controlled concurrency
    private func downloadFiles(_ files: [FileContents]) async throws -> [FileContents] {
        let remoteFiles = files.filter { $0.sourceURL != nil }
        let localFiles = files.filter { $0.sourceURL == nil }

        if remoteFiles.isEmpty {
            return localFiles
        }

        // Calculate how many slots we can use
        let availableSlots = max(1, maxConcurrentDownloads - activeDownloadCount)
        let effectiveConcurrency = min(availableSlots, remoteFiles.count)

        return try await withThrowingTaskGroup(of: FileContents.self) { group in
            var results = localFiles
            var iterator = remoteFiles.makeIterator()
            var activeCount = 0

            // Start initial batch
            for _ in 0 ..< effectiveConcurrency {
                if let file = iterator.next() {
                    activeDownloadCount += 1
                    activeCount += 1
                    group.addTask {
                        try await self.downloadFile(file)
                    }
                }
            }

            // Process results and start new downloads
            for try await downloadedFile in group {
                results.append(downloadedFile)
                activeDownloadCount -= 1
                activeCount -= 1
                totalDownloadsCompleted += 1

                // Dynamic concurrency adjustment
                // Always try to fill available slots, or maintain at least 1 active task if files remain
                while activeDownloadCount < maxConcurrentDownloads || activeCount == 0 {
                    if let file = iterator.next() {
                        activeDownloadCount += 1
                        activeCount += 1
                        group.addTask {
                            try await self.downloadFile(file)
                        }
                    } else {
                        break
                    }
                }
            }

            return results
        }
    }

    /// Download a single file
    private nonisolated func downloadFile(_ file: FileContents) async throws -> FileContents {
        guard let remoteURL = file.sourceURL else {
            return file
        }

        try validateDownloadURL(remoteURL)
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

// MARK: - Statistics

struct QueueStats {
    let pendingJobs: Int
    let activeJobs: Int
    let activeDownloads: Int
    let totalCompleted: Int
    let maxConcurrent: Int

    var description: String {
        let downloads = "downloads=\(activeDownloads)/\(maxConcurrent)"
        return "pending=\(pendingJobs) active=\(activeJobs) \(downloads) completed=\(totalCompleted)"
    }
}
