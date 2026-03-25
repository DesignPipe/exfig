// swiftlint:disable file_length
import ExFigConfig
import FigmaAPI
import Foundation

protocol ConfigExportPerforming: Sendable {
    func export(
        configFile: ConfigFile,
        options: ExFigOptions,
        client: Client,
        ui: TerminalUI
    ) async throws -> ExportStats
}

struct SubcommandConfigExporter: ConfigExportPerforming {
    let globalOptions: GlobalOptions
    let resume: Bool
    let cache: Bool
    let noCache: Bool
    let force: Bool
    let cachePath: String?
    let experimentalGranularCache: Bool
    let concurrentDownloads: Int

    /// Config execution context with per-config data (passed explicitly, no TaskLocal nesting).
    let configContext: ConfigExecutionContext

    func export(
        configFile: ConfigFile,
        options: ExFigOptions,
        client: Client,
        ui: TerminalUI
    ) async throws -> ExportStats {
        // No nested withValue calls - all context comes from:
        // 1. BatchSharedState.current (single TaskLocal)
        // 2. configContext (passed explicitly)
        // 3. client (passed as parameter)
        try await runExports(options: options, client: client, ui: ui)
    }

    // swiftlint:disable function_body_length cyclomatic_complexity
    private func runExports(
        options: ExFigOptions,
        client: Client,
        ui: TerminalUI
    ) async throws -> ExportStats {
        let cacheOpts = makeCacheOptions()
        let faultTolerance = FaultToleranceOptions()
        let heavyFaultTolerance = makeHeavyFaultToleranceOptions()
        let params = options.params

        enum StepResult: Sendable {
            case colors(ExportStats)
            case icons(ExportStats)
            case images(ExportStats)
            case typography(ExportStats)
        }

        var stats = ExportStats.zero

        try await withThrowingTaskGroup(of: StepResult.self) { [self] group in
            if hasColorsConfig(params) {
                group.addTask { [self] in
                    let cmd = makeColors(
                        options: options,
                        cacheOptions: cacheOpts,
                        faultToleranceOptions: faultTolerance
                    )
                    let result = try await cmd.performExportWithResult(
                        client: client,
                        ui: ui,
                        context: configContext.with(assetType: .colors)
                    )
                    return .colors(ExportStats(colors: result.count, fileVersions: result.fileVersions))
                }
            }

            if hasIconsConfig(params) {
                group.addTask { [self] in
                    let cmd = makeIcons(
                        options: options, cacheOptions: cacheOpts, faultToleranceOptions: heavyFaultTolerance
                    )
                    let result = try await cmd.performExportWithResult(
                        client: client,
                        ui: ui,
                        context: configContext.with(assetType: .icons)
                    )
                    return .icons(ExportStats(
                        icons: result.count,
                        computedNodeHashes: result.computedHashes,
                        granularCacheStats: result.granularCacheStats,
                        fileVersions: result.fileVersions
                    ))
                }
            }

            if hasImagesConfig(params) {
                group.addTask { [self] in
                    let cmd = makeImages(
                        options: options, cacheOptions: cacheOpts, faultToleranceOptions: heavyFaultTolerance
                    )
                    let result = try await cmd.performExportWithResult(
                        client: client,
                        ui: ui,
                        context: configContext.with(assetType: .images)
                    )
                    return .images(ExportStats(
                        images: result.count,
                        computedNodeHashes: result.computedHashes,
                        granularCacheStats: result.granularCacheStats,
                        fileVersions: result.fileVersions
                    ))
                }
            }

            if hasTypographyConfig(params) {
                group.addTask { [self] in
                    let cmd = makeTypography(
                        options: options, cacheOptions: cacheOpts, faultToleranceOptions: faultTolerance
                    )
                    let result = try await cmd.performExportWithResult(
                        client: client,
                        ui: ui,
                        context: configContext.with(assetType: .typography)
                    )
                    return .typography(ExportStats(typography: result.count, fileVersions: result.fileVersions))
                }
            }

            for try await stepResult in group {
                switch stepResult {
                case let .colors(s):
                    stats += s
                    if let cb = configContext.stepCompletionCallback {
                        await cb(.colors, s.colors)
                    }
                case let .icons(s):
                    stats += s
                    if let cb = configContext.stepCompletionCallback {
                        await cb(.icons, s.icons)
                    }
                case let .images(s):
                    stats += s
                    if let cb = configContext.stepCompletionCallback {
                        await cb(.images, s.images)
                    }
                case let .typography(s):
                    stats += s
                    if let cb = configContext.stepCompletionCallback {
                        await cb(.typography, s.typography)
                    }
                }
            }
        }

        return stats
    }

    // swiftlint:enable function_body_length cyclomatic_complexity

    private func makeCacheOptions() -> CacheOptions {
        var options = CacheOptions()
        options.cache = cache
        options.noCache = noCache
        options.force = force
        options.cachePath = cachePath
        options.experimentalGranularCache = experimentalGranularCache
        return options
    }

    private func makeHeavyFaultToleranceOptions() -> HeavyFaultToleranceOptions {
        var options = HeavyFaultToleranceOptions()
        options.resume = resume
        options.concurrentDownloads = concurrentDownloads
        return options
    }

    // MARK: - Config Detection

    private func hasColorsConfig(_ params: ExFig.ModuleImpl?) -> Bool {
        guard let params else { return false }
        let hasColorSource = params.common?.colors != nil || params.common?.variablesColors != nil
        let hasColorOutput = params.ios?.colors != nil
            || params.android?.colors != nil
            || params.flutter?.colors != nil
            || params.web?.colors != nil
        return hasColorSource || hasColorOutput
    }

    private func hasIconsConfig(_ params: ExFig.ModuleImpl?) -> Bool {
        guard let params else { return false }
        return params.ios?.icons != nil
            || params.android?.icons != nil
            || params.flutter?.icons != nil
            || params.web?.icons != nil
    }

    private func hasImagesConfig(_ params: ExFig.ModuleImpl?) -> Bool {
        guard let params else { return false }
        return params.ios?.images != nil
            || params.android?.images != nil
            || params.flutter?.images != nil
            || params.web?.images != nil
    }

    private func hasTypographyConfig(_ params: ExFig.ModuleImpl?) -> Bool {
        guard let params else { return false }
        return params.ios?.typography != nil
            || params.android?.typography != nil
    }
}

struct BatchConfigRunner {
    let rateLimiter: SharedRateLimiter
    let retryPolicy: RetryPolicy
    let globalOptions: GlobalOptions
    let maxRetries: Int
    let resume: Bool
    let cache: Bool
    let noCache: Bool
    let force: Bool
    let cachePath: String?
    let experimentalGranularCache: Bool
    let concurrentDownloads: Int
    /// CLI timeout override (in seconds). When set, overrides per-config timeout.
    let cliTimeout: Int?
    /// Priority for this config's downloads (lower = higher priority, based on submission order).
    let configPriority: Int
    /// Test-only: injected exporter for unit testing.
    private let _testExporter: (any ConfigExportPerforming)?

    init(
        rateLimiter: SharedRateLimiter,
        retryPolicy: RetryPolicy,
        globalOptions: GlobalOptions,
        maxRetries: Int,
        resume: Bool,
        cache: Bool = false,
        noCache: Bool = false,
        force: Bool = false,
        cachePath: String? = nil,
        experimentalGranularCache: Bool = false,
        concurrentDownloads: Int = FileDownloader.defaultMaxConcurrentDownloads,
        cliTimeout: Int? = nil,
        configPriority: Int = 0,
        exporter: (any ConfigExportPerforming)? = nil
    ) {
        self.rateLimiter = rateLimiter
        self.retryPolicy = retryPolicy
        self.globalOptions = globalOptions
        self.maxRetries = maxRetries
        self.resume = resume
        self.cache = cache
        self.noCache = noCache
        self.force = force
        self.cachePath = cachePath
        self.experimentalGranularCache = experimentalGranularCache
        self.concurrentDownloads = concurrentDownloads
        self.cliTimeout = cliTimeout
        self.configPriority = configPriority
        _testExporter = exporter
    }

    // swiftlint:disable cyclomatic_complexity

    /// Count the number of active asset types in a config (colors, icons, images, typography).
    static func countActiveAssetTypes(_ params: ExFig.ModuleImpl?) -> Int {
        guard let params else { return 0 }
        let checks: [Bool] = [
            params.common?.colors != nil || params.common?.variablesColors != nil
                || params.ios?.colors != nil || params.android?.colors != nil
                || params.flutter?.colors != nil || params.web?.colors != nil,
            params.ios?.icons != nil || params.android?.icons != nil
                || params.flutter?.icons != nil || params.web?.icons != nil,
            params.ios?.images != nil || params.android?.images != nil
                || params.flutter?.images != nil || params.web?.images != nil,
            params.ios?.typography != nil || params.android?.typography != nil,
        ]
        return checks.filter { $0 }.count
    }

    // swiftlint:enable cyclomatic_complexity

    // swiftlint:disable:next function_body_length
    func process(
        configFile: ConfigFile,
        ui: TerminalUI
    ) async -> ConfigResult {
        // Get progress view from BatchSharedState (if in batch mode)
        let progressView = BatchSharedState.current?.progressView

        // Start config in progress view or log to UI
        if let progressView {
            await progressView.startConfig(name: configFile.name)
        } else {
            ui.info("Processing: \(configFile.name)")
        }

        do {
            var options = ExFigOptions()
            options.input = configFile.url.path
            try options.validate()

            let retryHandler = RetryLogger.createHandler(ui: ui, maxAttempts: maxRetries)

            // CLI timeout takes precedence over per-config timeout
            let effectiveTimeout: TimeInterval? = cliTimeout.map { TimeInterval($0) }
                ?? options.params.figma?.timeout

            let baseClient = try FigmaClient(
                accessToken: options.requireFigmaToken(),
                timeout: effectiveTimeout
            )

            let client = RateLimitedClient(
                client: baseClient,
                rateLimiter: rateLimiter,
                configID: ConfigID(configFile.name),
                retryPolicy: retryPolicy,
                onRetry: { attempt, error in
                    let delay = retryPolicy.delay(for: attempt - 1, error: error)
                    retryHandler(configFile.name, attempt, error, delay)
                }
            )

            // Create download progress callback that routes to batch progress view
            let configName = configFile.name
            let downloadCallback: ConfigExecutionContext.DownloadProgressCallback? =
                if let pv = progressView {
                    { (assetType: ConfigExecutionContext.AssetType, current: Int, total: Int) in
                        await pv.updateProgress(
                            name: configName,
                            colors: assetType == .colors ? (current, total) : nil,
                            icons: assetType == .icons ? (current, total) : nil,
                            images: assetType == .images ? (current, total) : nil,
                            typography: assetType == .typography ? (current, total) : nil
                        )
                    }
                } else {
                    nil
                }

            // Create step completion callback that routes to batch progress view
            let stepCallback: ConfigExecutionContext.StepCompletionCallback? =
                if let pv = progressView {
                    { (assetType: ConfigExecutionContext.AssetType, count: Int) in
                        await pv.completeExportStep(name: configName, assetType: assetType, count: count)
                    }
                } else {
                    nil
                }

            // Set total steps before export starts
            if let pv = progressView {
                let totalSteps = Self.countActiveAssetTypes(options.params)
                await pv.setTotalSteps(name: configName, total: totalSteps)
            }

            // Create per-config execution context (passed explicitly, no TaskLocal nesting)
            let configContext = ConfigExecutionContext(
                configId: configFile.name,
                configPriority: configPriority,
                downloadProgressCallback: downloadCallback,
                stepCompletionCallback: stepCallback
            )

            // Use test exporter if provided, otherwise create real exporter
            let exporter: any ConfigExportPerforming = _testExporter ?? SubcommandConfigExporter(
                globalOptions: globalOptions,
                resume: resume,
                cache: cache,
                noCache: noCache,
                force: force,
                cachePath: cachePath,
                experimentalGranularCache: experimentalGranularCache,
                concurrentDownloads: concurrentDownloads,
                configContext: configContext
            )

            // No nested withValue calls - context is passed explicitly
            let stats = try await exporter.export(
                configFile: configFile,
                options: options,
                client: client,
                ui: ui
            )

            // Mark config as succeeded (step progress already updated incrementally)
            if let progressView {
                await progressView.succeedConfig(name: configFile.name)
            } else {
                ui.success("Completed: \(configFile.name)")
            }

            return .success(config: configFile, stats: stats)

        } catch {
            // Update progress view with failure or log error
            if let progressView {
                let errorMsg = String(error.localizedDescription.prefix(30))
                await progressView.failConfig(name: configFile.name, error: errorMsg)
            } else {
                ui.error("Failed: \(configFile.name)")
                ui.error(error)
            }
            return .failure(config: configFile, error: error)
        }
    }
}

private extension SubcommandConfigExporter {
    func makeColors(
        options: ExFigOptions,
        cacheOptions: CacheOptions,
        faultToleranceOptions: FaultToleranceOptions
    ) -> ExFigCommand.ExportColors {
        var cmd = ExFigCommand.ExportColors()
        cmd.globalOptions = globalOptions
        cmd.options = options
        cmd.cacheOptions = cacheOptions
        cmd.faultToleranceOptions = faultToleranceOptions
        cmd.filter = nil
        return cmd
    }

    func makeIcons(
        options: ExFigOptions,
        cacheOptions: CacheOptions,
        faultToleranceOptions: HeavyFaultToleranceOptions
    ) -> ExFigCommand.ExportIcons {
        var cmd = ExFigCommand.ExportIcons()
        cmd.globalOptions = globalOptions
        cmd.options = options
        cmd.cacheOptions = cacheOptions
        cmd.faultToleranceOptions = faultToleranceOptions
        cmd.filter = nil
        cmd.strictPathValidation = false
        return cmd
    }

    func makeImages(
        options: ExFigOptions,
        cacheOptions: CacheOptions,
        faultToleranceOptions: HeavyFaultToleranceOptions
    ) -> ExFigCommand.ExportImages {
        var cmd = ExFigCommand.ExportImages()
        cmd.globalOptions = globalOptions
        cmd.options = options
        cmd.cacheOptions = cacheOptions
        cmd.faultToleranceOptions = faultToleranceOptions
        cmd.filter = nil
        return cmd
    }

    func makeTypography(
        options: ExFigOptions,
        cacheOptions: CacheOptions,
        faultToleranceOptions: FaultToleranceOptions
    ) -> ExFigCommand.ExportTypography {
        var cmd = ExFigCommand.ExportTypography()
        cmd.globalOptions = globalOptions
        cmd.options = options
        cmd.cacheOptions = cacheOptions
        cmd.faultToleranceOptions = faultToleranceOptions
        return cmd
    }
}
