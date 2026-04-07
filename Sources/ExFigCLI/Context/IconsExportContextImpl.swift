import ExFigConfig
import ExFigCore
import FigmaAPI
import Foundation

/// Concrete implementation of `IconsExportContext` for the ExFig CLI.
///
/// Bridges between the plugin system and ExFig's internal services:
/// - Uses `IconsLoader` for Figma data loading
/// - Uses `ImagesProcessor` for platform-specific processing
/// - Uses `ExFigCommand.fileWriter` for file output
/// - Uses `TerminalUI` for progress and logging
/// - Uses `PipelinedDownloader` for batch-optimized downloads
/// - Supports granular cache for incremental exports
struct IconsExportContextImpl: IconsExportContextWithGranularCache {
    let client: Client
    let componentsSource: any ComponentsSource
    let ui: TerminalUI
    let params: PKLConfig
    let filter: String?
    let isBatchMode: Bool
    let fileDownloader: FileDownloader
    let configExecutionContext: ConfigExecutionContext?
    let granularCacheManager: GranularCacheManager?
    let platform: Platform
    let variablesCache: VariablesCache?
    let componentsCache: ComponentsCache?

    init(
        client: Client,
        componentsSource: any ComponentsSource,
        ui: TerminalUI,
        params: PKLConfig,
        filter: String? = nil,
        isBatchMode: Bool = false,
        fileDownloader: FileDownloader = FileDownloader(),
        configExecutionContext: ConfigExecutionContext? = nil,
        granularCacheManager: GranularCacheManager? = nil,
        platform: Platform,
        variablesCache: VariablesCache? = nil,
        componentsCache: ComponentsCache? = nil
    ) {
        self.client = client
        self.componentsSource = componentsSource
        self.ui = ui
        self.params = params
        self.filter = filter
        self.isBatchMode = isBatchMode
        self.fileDownloader = fileDownloader
        self.configExecutionContext = configExecutionContext
        self.granularCacheManager = granularCacheManager
        self.platform = platform
        self.variablesCache = variablesCache
        self.componentsCache = componentsCache
    }

    var isGranularCacheEnabled: Bool {
        granularCacheManager != nil
    }

    // MARK: - ExportContext

    func writeFiles(_ files: [FileContents]) throws {
        try ExFigCommand.fileWriter.write(files: files)
    }

    func info(_ message: String) {
        ui.info(message)
    }

    func warning(_ message: String) {
        ui.warning(message)
    }

    func success(_ message: String) {
        ui.success(message)
    }

    func withSpinner<T: Sendable>(
        _ message: String,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await ui.withSpinner(message, operation: operation)
    }

    // MARK: - IconsExportContext

    func loadIcons(from source: IconsSourceInput) async throws -> IconsLoadOutput {
        try await componentsSource.loadIcons(from: source)
    }

    func processIcons(
        _ icons: IconsLoadOutput,
        platform: Platform,
        nameValidateRegexp: String?,
        nameReplaceRegexp: String?,
        nameStyle: NameStyle
    ) throws -> IconsProcessResult {
        let processor = ImagesProcessor(
            platform: platform,
            nameValidateRegexp: nameValidateRegexp,
            nameReplaceRegexp: nameReplaceRegexp,
            nameStyle: nameStyle
        )

        let result = processor.process(
            light: icons.light,
            dark: icons.dark.isEmpty ? nil : icons.dark
        )

        if let warning = result.warning {
            let formatted = WarningFormatter().format(warning, compact: isBatchMode)
            ExFigCommand.logger.debug("\(formatted)")
        }

        return try IconsProcessResult(
            iconPairs: result.get()
        )
    }

    func downloadFiles(
        _ files: [FileContents],
        progressTitle: String
    ) async throws -> [FileContents] {
        let remoteFilesCount = files.filter { $0.sourceURL != nil }.count

        guard remoteFilesCount > 0 else {
            return files
        }

        return try await ui.withProgress(progressTitle, total: remoteFilesCount) { progress in
            try await PipelinedDownloader.download(
                files: files,
                fileDownloader: fileDownloader,
                context: configExecutionContext
            ) { current, _ in
                progress.update(current: current)
            }
        }
    }

    func withProgress<T: Sendable>(
        _ title: String,
        total: Int,
        operation: @escaping @Sendable (ProgressReporter) async throws -> T
    ) async throws -> T {
        try await ui.withProgress(title, total: total) { progress in
            // Wrap ProgressBar to conform to ProgressReporter
            let reporter = ProgressBarReporter(progressBar: progress)
            return try await operation(reporter)
        }
    }

    // MARK: - IconsExportContextWithGranularCache

    func loadIconsWithGranularCache(
        from source: IconsSourceInput,
        onProgress: (@Sendable (Int, Int) -> Void)?
    ) async throws -> IconsLoadOutputWithHashes {
        let config = IconsLoaderConfig(
            entryFileId: source.figmaFileId,
            frameName: source.frameName,
            pageName: source.pageName,
            format: source.format,
            renderMode: source.renderMode,
            renderModeDefaultSuffix: source.renderModeDefaultSuffix,
            renderModeOriginalSuffix: source.renderModeOriginalSuffix,
            renderModeTemplateSuffix: source.renderModeTemplateSuffix,
            rtlProperty: source.rtlProperty,
            rtlActiveValues: source.rtlActiveValues
        )

        let loader = IconsLoader(
            client: client,
            params: params,
            platform: platform,
            logger: ExFigCommand.logger,
            config: config
        )
        loader.componentsCache = componentsCache

        let output: IconsLoadOutputWithHashes
        if let manager = granularCacheManager {
            loader.granularCacheManager = manager
            let result = try await loader.loadWithGranularCache(
                filter: filter,
                onBatchProgress: onProgress ?? { _, _ in }
            )
            output = IconsLoadOutputWithHashes(
                light: result.light,
                dark: result.dark ?? [],
                computedHashes: result.computedHashes,
                allSkipped: result.allSkipped,
                allAssetMetadata: result.allAssetMetadata
            )
        } else {
            let result = try await loader.load(filter: filter, onBatchProgress: onProgress ?? { _, _ in })
            output = IconsLoadOutputWithHashes(
                light: result.light,
                dark: result.dark ?? [],
                computedHashes: [:],
                allSkipped: false,
                allAssetMetadata: []
            )
        }

        return try await applyVariableModeDark(to: output, source: source)
    }

    /// Applies variable-mode dark generation to granular cache output.
    private func applyVariableModeDark(
        to output: IconsLoadOutputWithHashes,
        source: IconsSourceInput
    ) async throws -> IconsLoadOutputWithHashes {
        guard let collectionName = source.variablesCollectionName,
              let lightModeName = source.variablesLightModeName,
              let darkModeName = source.variablesDarkModeName
        else { return output }

        let logger = ExFigCommand.logger
        guard let fileId = source.figmaFileId ?? params.figma?.lightFileId, !fileId.isEmpty else {
            logger.warning("Variable-mode dark generation requires a Figma file ID, skipping")
            return output
        }
        let generator = VariableModeDarkGenerator(client: client, logger: logger, variablesCache: variablesCache)
        let darkPacks = try await generator.generateDarkVariants(
            lightPacks: output.light,
            config: .init(
                fileId: fileId,
                collectionName: collectionName,
                lightModeName: lightModeName,
                darkModeName: darkModeName,
                primitivesModeName: source.variablesPrimitivesModeName,
                variablesFileId: source.variablesFileId
            )
        )
        return IconsLoadOutputWithHashes(
            light: output.light,
            dark: darkPacks,
            computedHashes: output.computedHashes,
            allSkipped: output.allSkipped,
            allAssetMetadata: output.allAssetMetadata
        )
    }

    func processIconNames(
        _ names: [String],
        nameValidateRegexp: String?,
        nameReplaceRegexp: String?,
        nameStyle: NameStyle
    ) -> [String] {
        let processor = ImagesProcessor(
            platform: platform,
            nameValidateRegexp: nameValidateRegexp,
            nameReplaceRegexp: nameReplaceRegexp,
            nameStyle: nameStyle
        )
        return processor.processNames(names)
    }
}

// MARK: - ProgressBarReporter

/// Wrapper to make ProgressBar conform to ProgressReporter protocol.
struct ProgressBarReporter: ProgressReporter {
    let progressBar: ProgressBar

    func update(current: Int) {
        progressBar.update(current: current)
    }

    func increment() {
        progressBar.increment()
    }
}
