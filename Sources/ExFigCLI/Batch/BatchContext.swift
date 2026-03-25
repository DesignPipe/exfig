import FigmaAPI

// MARK: - BatchContext (Immutable Pre-fetched Data)

/// Immutable pre-fetched data for batch processing optimization.
///
/// Contains data that is fetched once at batch start and shared read-only across all configs.
/// This struct is stored inside `BatchSharedState` and should not be used with TaskLocal directly.
///
/// See: https://github.com/swiftlang/swift/issues/75501
struct BatchContext {
    /// Pre-fetched file metadata for version checking.
    let versions: PreFetchedFileVersions?

    /// Pre-fetched components from Figma API.
    let components: PreFetchedComponents?

    /// Shared granular cache for per-node hash tracking.
    let granularCache: SharedGranularCache?

    /// Pre-fetched node documents for granular cache.
    let nodes: PreFetchedNodes?

    /// Creates a new batch context with optional pre-fetched data.
    init(
        versions: PreFetchedFileVersions? = nil,
        components: PreFetchedComponents? = nil,
        granularCache: SharedGranularCache? = nil,
        nodes: PreFetchedNodes? = nil
    ) {
        self.versions = versions
        self.components = components
        self.granularCache = granularCache
        self.nodes = nodes
    }

    /// Whether any batch context is active (any field is non-nil).
    var isBatchMode: Bool {
        versions != nil || components != nil || granularCache != nil || nodes != nil
    }

    /// Whether granular cache is available in this context.
    var hasGranularCache: Bool {
        granularCache != nil
    }

    /// Returns a copy with updated components.
    func withComponents(_ components: PreFetchedComponents?) -> BatchContext {
        BatchContext(
            versions: versions,
            components: components,
            granularCache: granularCache,
            nodes: nodes
        )
    }
}

// MARK: - ConfigExecutionContext (Per-Config Data)

/// Per-config execution context passed explicitly to avoid nested TaskLocal.withValue().
///
/// This struct contains data specific to a single config being processed.
/// It is passed as a parameter instead of using TaskLocal to avoid the Linux crash.
struct ConfigExecutionContext {
    /// Callback type for reporting incremental download progress to batch view.
    /// Parameters: (assetType, current, total)
    typealias DownloadProgressCallback = @Sendable (AssetType, Int, Int) async -> Void

    /// Callback type for reporting step (asset type) completion to batch progress view.
    /// Parameters: (assetType, exportedCount)
    typealias StepCompletionCallback = @Sendable (AssetType, Int) async -> Void

    /// Config identifier for progress tracking and logging.
    let configId: String

    /// Priority for download ordering (lower = higher priority).
    let configPriority: Int

    /// Asset type currently being processed (for progress routing).
    let assetType: AssetType?

    /// Callback to report download progress to batch progress view.
    /// The callback routes `(current, total)` to the correct asset type slot
    /// in `BatchProgressView.updateProgress()`.
    let downloadProgressCallback: DownloadProgressCallback?

    /// Callback to report step (asset type) completion to batch progress view.
    /// Called from `runExports()` after each parallel export step finishes.
    let stepCompletionCallback: StepCompletionCallback?

    /// Asset types that can be processed.
    enum AssetType: String {
        case colors
        case icons
        case images
        case typography
    }

    init(
        configId: String,
        configPriority: Int = 0,
        assetType: AssetType? = nil,
        downloadProgressCallback: DownloadProgressCallback? = nil,
        stepCompletionCallback: StepCompletionCallback? = nil
    ) {
        self.configId = configId
        self.configPriority = configPriority
        self.assetType = assetType
        self.downloadProgressCallback = downloadProgressCallback
        self.stepCompletionCallback = stepCompletionCallback
    }

    /// Returns a copy with different asset type, inheriting the progress callbacks
    /// which route updates to the correct asset type slot automatically.
    func with(assetType: AssetType) -> ConfigExecutionContext {
        ConfigExecutionContext(
            configId: configId,
            configPriority: configPriority,
            assetType: assetType,
            downloadProgressCallback: downloadProgressCallback,
            stepCompletionCallback: stepCompletionCallback
        )
    }
}

// MARK: - BatchSharedState (Consolidated Actor)

/// Actor consolidating ALL shared state for batch mode processing.
///
/// This actor replaces multiple individual TaskLocal storages to avoid deep nesting
/// of `withValue()` calls, which causes Swift runtime crashes on Linux.
/// See: https://github.com/swiftlang/swift/issues/75501
///
/// ## Architecture
///
/// Instead of nested TaskLocal scopes:
/// ```swift
/// // OLD (causes crash on Linux with 10+ nesting levels)
/// $collector.withValue(c) {
///     $progressView.withValue(p) {
///         $context.withValue(ctx) {
///             $queue.withValue(q) { ... }
///         }
///     }
/// }
/// ```
///
/// We use a single TaskLocal with an actor:
/// ```swift
/// // NEW (single nesting level)
/// BatchSharedState.$current.withValue(state) {
///     // Access everything via state actor
/// }
/// ```
///
/// ## Usage
///
/// ```swift
/// let state = BatchSharedState(
///     context: batchContext,
///     progressView: progressView,
///     themeCollector: collector,
///     downloadQueue: queue
/// )
///
/// await BatchSharedState.$current.withValue(state) {
///     // Inside batch processing
///     if let ctx = BatchSharedState.current?.context { ... }
///     if let progress = BatchSharedState.current?.progressView { ... }
/// }
/// ```
actor BatchSharedState {
    // MARK: - Immutable Pre-fetched Data

    /// Consolidated immutable pre-fetched data.
    let context: BatchContext

    // MARK: - Shared Actors (Thread-safe Mutable State)

    /// Progress view for batch UI display.
    let progressView: BatchProgressView?

    /// Collector for theme attributes across configs.
    let themeCollector: SharedThemeAttributesCollector?

    /// Shared download queue for cross-config pipelining.
    let downloadQueue: SharedDownloadQueue?

    // MARK: - Mutable Components State

    /// Locally pre-fetched components (can be updated during execution).
    /// Used when batch-level pre-fetch didn't include components for a specific file.
    private var localComponents: PreFetchedComponents?

    // MARK: - TaskLocal Storage

    /// Single TaskLocal for all batch state.
    /// This is the ONLY TaskLocal used in batch mode to avoid nesting issues.
    @TaskLocal static var current: BatchSharedState?

    // MARK: - Initialization

    init(
        context: BatchContext,
        progressView: BatchProgressView? = nil,
        themeCollector: SharedThemeAttributesCollector? = nil,
        downloadQueue: SharedDownloadQueue? = nil
    ) {
        self.context = context
        self.progressView = progressView
        self.themeCollector = themeCollector
        self.downloadQueue = downloadQueue
        localComponents = nil
    }

    // MARK: - Accessors (nonisolated for sync access)

    /// Get pre-fetched versions (nonisolated - immutable data).
    nonisolated var versions: PreFetchedFileVersions? {
        context.versions
    }

    /// Get pre-fetched nodes (nonisolated - immutable data).
    nonisolated var nodes: PreFetchedNodes? {
        context.nodes
    }

    /// Get shared granular cache (nonisolated - immutable data).
    nonisolated var granularCache: SharedGranularCache? {
        context.granularCache
    }

    /// Check if batch mode is active.
    nonisolated var isBatchMode: Bool {
        context.isBatchMode
    }

    // MARK: - Components Access (may need isolation)

    /// Get components - either from batch context or locally pre-fetched.
    func getComponents() -> PreFetchedComponents? {
        localComponents ?? context.components
    }

    /// Set locally pre-fetched components.
    func setLocalComponents(_ components: PreFetchedComponents?) {
        localComponents = components
    }

    /// Check if components are available for a file.
    func hasComponents(for fileId: String) -> Bool {
        if let local = localComponents, local.components(for: fileId) != nil {
            return true
        }
        if let batch = context.components, batch.components(for: fileId) != nil {
            return true
        }
        return false
    }

    /// Get components for a specific file.
    func getComponents(for fileId: String) -> [Component]? {
        if let local = localComponents, let comps = local.components(for: fileId) {
            return comps
        }
        return context.components?.components(for: fileId)
    }
}

// MARK: - Legacy Compatibility (BatchContextStorage)

/// Legacy TaskLocal storage for backward compatibility.
///
/// @deprecated Use `BatchSharedState.current` instead.
/// This enum provides compatibility shims during migration.
///
/// ## Migration Path
///
/// Old code:
/// ```swift
/// if let ctx = BatchContextStorage.context { ... }
/// ```
///
/// New code:
/// ```swift
/// if let state = BatchSharedState.current { ... }
/// ```
enum BatchContextStorage {
    /// Legacy accessor - returns context from BatchSharedState if available.
    static var context: BatchContext? {
        BatchSharedState.current?.context
    }

    /// Check if batch mode is active.
    static var isBatchMode: Bool {
        BatchSharedState.current?.isBatchMode ?? false
    }
}
