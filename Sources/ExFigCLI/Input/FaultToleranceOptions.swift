import ArgumentParser
import ExFigCore
import FigmaAPI
import Foundation

/// CLI options for fault tolerance configuration.
///
/// These options allow users to configure retry behavior and rate limiting
/// for Figma API requests in individual commands.
struct FaultToleranceOptions: ParsableArguments {
    @Option(
        name: .long,
        help: "Maximum retry attempts for failed API requests"
    )
    var maxRetries: Int = 4

    @Option(
        name: .long,
        help: "Maximum API requests per minute"
    )
    var rateLimit: Int = 10

    @Option(
        name: .long,
        help: "Figma API request timeout in seconds (overrides config)"
    )
    var timeout: Int?

    mutating func validate() throws {
        if let timeout, timeout <= 0 {
            throw ValidationError("Timeout must be positive")
        }
    }

    /// Create a retry policy from the options.
    /// - Returns: A configured `RetryPolicy`.
    func createRetryPolicy() -> RetryPolicy {
        RetryPolicy(maxRetries: maxRetries)
    }

    /// Create a shared rate limiter from the options.
    /// - Returns: A configured `SharedRateLimiter`.
    func createRateLimiter() -> SharedRateLimiter {
        SharedRateLimiter(requestsPerMinute: Double(rateLimit))
    }

    /// Create a rate-limited client wrapping the given client.
    /// - Parameters:
    ///   - client: The underlying client to wrap.
    ///   - rateLimiter: The shared rate limiter to use.
    ///   - configID: Identifier for this client's config (default: "default").
    ///   - onRetry: Optional callback invoked before each retry attempt.
    /// - Returns: A `RateLimitedClient` instance.
    func createRateLimitedClient(
        wrapping client: Client,
        rateLimiter: SharedRateLimiter,
        configID: ConfigID = ConfigID("default"),
        onRetry: RetryCallback? = nil
    ) -> Client {
        RateLimitedClient(
            client: client,
            rateLimiter: rateLimiter,
            configID: configID,
            retryPolicy: createRetryPolicy(),
            onRetry: onRetry
        )
    }
}

// MARK: - Heavy Fault Tolerance Options

/// Extended fault tolerance options for commands that download many files.
///
/// In addition to basic retry and rate limiting, these options support:
/// - `--fail-fast`: Stop on first error without retrying
/// - `--resume`: Continue from checkpoint after interruption
/// - `--timeout`: Figma API request timeout in seconds
struct HeavyFaultToleranceOptions: ParsableArguments {
    @Option(
        name: .long,
        help: "Maximum retry attempts for failed API requests"
    )
    var maxRetries: Int = 4

    @Option(
        name: .long,
        help: "Maximum API requests per minute"
    )
    var rateLimit: Int = 10

    @Option(
        name: .long,
        help: "Figma API request timeout in seconds (overrides config)"
    )
    var timeout: Int?

    @Flag(
        name: .long,
        help: "Stop on first error without retrying"
    )
    var failFast: Bool = false

    @Flag(
        name: .long,
        help: "Continue from checkpoint after interruption"
    )
    var resume: Bool = false

    @Option(
        name: .long,
        help: "Maximum concurrent CDN downloads"
    )
    var concurrentDownloads: Int = FileDownloader.defaultMaxConcurrentDownloads

    mutating func validate() throws {
        if let timeout, timeout <= 0 {
            throw ValidationError("Timeout must be positive")
        }
    }

    /// Create a file downloader with configured concurrency.
    /// - Returns: A configured `FileDownloader`.
    func createFileDownloader() -> FileDownloader {
        FileDownloader(maxConcurrentDownloads: concurrentDownloads)
    }

    /// Create a retry policy from the options.
    /// - Returns: A configured `RetryPolicy`.
    func createRetryPolicy() -> RetryPolicy {
        if failFast {
            return RetryPolicy(maxRetries: 0)
        }
        return RetryPolicy(maxRetries: maxRetries)
    }

    /// Create a shared rate limiter from the options.
    /// - Returns: A configured `SharedRateLimiter`.
    func createRateLimiter() -> SharedRateLimiter {
        SharedRateLimiter(requestsPerMinute: Double(rateLimit))
    }

    /// Create a rate-limited client wrapping the given client.
    /// - Parameters:
    ///   - client: The underlying client to wrap.
    ///   - rateLimiter: The shared rate limiter to use.
    ///   - configID: Identifier for this client's config (default: "default").
    ///   - onRetry: Optional callback invoked before each retry attempt.
    /// - Returns: A `RateLimitedClient` instance.
    func createRateLimitedClient(
        wrapping client: Client,
        rateLimiter: SharedRateLimiter,
        configID: ConfigID = ConfigID("default"),
        onRetry: RetryCallback? = nil
    ) -> Client {
        RateLimitedClient(
            client: client,
            rateLimiter: rateLimiter,
            configID: configID,
            retryPolicy: createRetryPolicy(),
            onRetry: onRetry
        )
    }

    // MARK: - Checkpoint Management

    /// Load or create a checkpoint tracker for resumable downloads.
    /// - Parameters:
    ///   - configPath: Path to the config file.
    ///   - workingDirectory: Directory to save checkpoint file.
    ///   - assetType: Type of assets (icons or images).
    ///   - assetNames: Set of all asset names to track.
    ///   - ui: Terminal UI for progress messages.
    /// - Returns: Checkpoint tracker, or nil if resume is disabled.
    func loadOrCreateCheckpoint(
        configPath: String,
        workingDirectory: URL,
        assetType: CheckpointTracker.AssetType,
        assetNames: Set<String>,
        ui: TerminalUI
    ) async throws -> CheckpointTracker? {
        guard resume else { return nil }

        // Try to load existing checkpoint
        if let existing = try CheckpointTracker.loadIfValid(
            configPath: configPath,
            directory: workingDirectory,
            assetType: assetType
        ) {
            let completed = await existing.completedNames.count
            let pending = await existing.pendingNames.count
            ui.info("Resuming: \(completed) completed, \(pending) remaining")
            return existing
        }

        // Create new checkpoint
        return try CheckpointTracker(
            configPath: configPath,
            directory: workingDirectory,
            assetType: assetType,
            assetNames: assetNames
        )
    }

    /// Filter files to download based on checkpoint state.
    /// - Parameters:
    ///   - files: All files to potentially download.
    ///   - checkpoint: Optional checkpoint tracker.
    /// - Returns: Files that need to be downloaded (excluding completed ones).
    func filterFilesForDownload(
        _ files: [FileContents],
        checkpoint: CheckpointTracker?
    ) async -> [FileContents] {
        guard let checkpoint else { return files }
        return await checkpoint.filterPending(files)
    }

    /// Mark files as completed and save checkpoint.
    /// - Parameters:
    ///   - files: Downloaded files to mark as completed.
    ///   - checkpoint: Optional checkpoint tracker.
    func markFilesCompleted(
        _ files: [FileContents],
        checkpoint: CheckpointTracker?
    ) async {
        guard let checkpoint else { return }
        let names = files.map { $0.destination.file.deletingPathExtension().lastPathComponent }
        await checkpoint.markCompleted(names)
    }

    /// Finalize checkpoint after successful export.
    /// - Parameter checkpoint: Optional checkpoint tracker to clean up.
    func finalizeCheckpoint(_ checkpoint: CheckpointTracker?) async throws {
        guard let checkpoint else { return }
        if await checkpoint.isComplete {
            try await checkpoint.delete()
        } else {
            try await checkpoint.save()
        }
    }
}

// MARK: - Client Resolution

/// Resolves a Figma API client, using injected client if available (batch mode)
/// or creating a new rate-limited client (standalone command mode).
///
/// - Parameters:
///   - accessToken: Figma personal access token.
///   - timeout: Request timeout interval from config (optional, uses FigmaClient default if nil).
///   - options: Fault tolerance options for creating new client (may contain CLI timeout override).
///   - ui: Terminal UI for retry warnings.
/// - Returns: A configured `Client` instance.
///
/// Timeout precedence: CLI `--timeout` > config > FigmaClient default (30s)
func resolveClient(
    accessToken: String?,
    timeout: TimeInterval?,
    options: FaultToleranceOptions,
    ui: TerminalUI
) -> Client {
    if let injectedClient = InjectedClientStorage.client {
        return injectedClient
    }
    guard let accessToken else {
        // No Figma token — return a client that throws on any call.
        // Non-Figma sources (Penpot, tokens-file) never call it.
        // SourceFactory also guards the .figma branch with accessTokenNotFound.
        return NoTokenFigmaClient()
    }
    // CLI timeout takes precedence over config timeout
    let effectiveTimeout: TimeInterval? = options.timeout.map { TimeInterval($0) } ?? timeout
    let baseClient = FigmaClient(accessToken: accessToken, timeout: effectiveTimeout)
    let rateLimiter = options.createRateLimiter()
    let maxRetries = options.maxRetries
    return options.createRateLimitedClient(
        wrapping: baseClient,
        rateLimiter: rateLimiter,
        onRetry: { attempt, error in
            let warning = ExFigWarning.retrying(
                attempt: attempt,
                maxAttempts: maxRetries,
                error: error.localizedDescription,
                delay: "..."
            )
            ui.warning(warning)
        }
    )
}

/// Resolves a Figma API client for heavy commands, using injected client if available
/// (batch mode) or creating a new rate-limited client (standalone command mode).
///
/// When `accessToken` is nil (no `FIGMA_PERSONAL_TOKEN`), returns ``NoTokenFigmaClient`` —
/// a fail-fast client that throws on any request. Non-Figma sources (Penpot, tokens-file)
/// never call it, so pure-Penpot workflows work without Figma credentials.
///
/// - Parameters:
///   - accessToken: Figma personal access token (nil when using non-Figma sources only).
///   - timeout: Request timeout interval from config (optional, uses FigmaClient default if nil).
///   - options: Heavy fault tolerance options for creating new client (may contain CLI timeout override).
///   - ui: Terminal UI for retry warnings.
/// - Returns: A configured `Client` instance.
///
/// Timeout precedence: CLI `--timeout` > config > FigmaClient default (30s)
func resolveClient(
    accessToken: String?,
    timeout: TimeInterval?,
    options: HeavyFaultToleranceOptions,
    ui: TerminalUI
) -> Client {
    if let injectedClient = InjectedClientStorage.client {
        return injectedClient
    }
    guard let accessToken else {
        // No Figma token — return a client that throws on any call.
        // Non-Figma sources (Penpot, tokens-file) never call it.
        return NoTokenFigmaClient()
    }
    // CLI timeout takes precedence over config timeout
    let effectiveTimeout: TimeInterval? = options.timeout.map { TimeInterval($0) } ?? timeout
    let baseClient = FigmaClient(accessToken: accessToken, timeout: effectiveTimeout)
    let rateLimiter = options.createRateLimiter()
    let maxRetries = options.maxRetries
    return options.createRateLimitedClient(
        wrapping: baseClient,
        rateLimiter: rateLimiter,
        onRetry: { attempt, error in
            let warning = ExFigWarning.retrying(
                attempt: attempt,
                maxAttempts: maxRetries,
                error: error.localizedDescription,
                delay: "..."
            )
            ui.warning(warning)
        }
    )
}

// MARK: - No-Token Client

/// A Figma API client placeholder that throws `accessTokenNotFound` on any request.
///
/// Used when `FIGMA_PERSONAL_TOKEN` is not set. Non-Figma sources (Penpot, tokens-file)
/// never call this client. If accidentally invoked, the error message clearly tells the user
/// to set the token — instead of making real HTTP requests with an invalid token.
final class NoTokenFigmaClient: Client, @unchecked Sendable {
    func request<T: Endpoint>(_: T) async throws -> T.Content {
        throw ExFigError.accessTokenNotFound
    }
}
