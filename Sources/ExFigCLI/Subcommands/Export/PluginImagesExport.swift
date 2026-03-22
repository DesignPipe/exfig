import ExFig_Android
import ExFig_Flutter
import ExFig_iOS
import ExFig_Web
import ExFigCore
import FigmaAPI
import Foundation
import XcodeExport

// swiftlint:disable function_parameter_count

// MARK: - Plugin-based Images Export

extension ExFigCommand.ExportImages {
    /// Exports iOS images using plugin architecture.
    ///
    /// This method uses `iOSImagesExporter` from the plugin system. For granular
    /// cache support, the context internally routes to cache-aware loading.
    ///
    /// - Parameters:
    ///   - entries: Params entries to convert and export.
    ///   - ios: iOS platform configuration from PKLConfig.
    ///   - client: Figma API client.
    ///   - params: Full params for context creation.
    ///   - ui: Terminal UI for output.
    ///   - granularCacheManager: Optional granular cache manager.
    /// - Returns: Platform export result with count and hashes.
    func exportiOSImagesViaPlugin(
        entries: [iOSImagesEntry],
        ios: PKLConfig.iOS,
        client: Client,
        params: PKLConfig,
        ui: TerminalUI,
        granularCacheManager: GranularCacheManager?
    ) async throws -> PlatformExportResult {
        let platformConfig = ios.platformConfig()

        let batchMode = BatchSharedState.current?.isBatchMode ?? false
        let fileDownloader = faultToleranceOptions.createFileDownloader()

        // All entries in a platform section share one source kind (mixed sources not yet supported)
        guard let sourceKind = entries.first?.resolvedSourceKind else {
            throw ExFigError.configurationError("No entries provided for images export")
        }
        let componentsSource = try SourceFactory.createComponentsSource(
            for: sourceKind,
            client: client,
            params: params,
            platform: .ios,
            logger: ExFigCommand.logger,
            filter: filter,
            ui: ui
        )

        let context = ImagesExportContextImpl(
            client: client,
            componentsSource: componentsSource,
            ui: ui,
            params: params,
            filter: filter,
            isBatchMode: batchMode,
            fileDownloader: fileDownloader,
            granularCacheManager: granularCacheManager,
            platform: .ios
        )

        // Export via plugin (returns ImagesExportResult with hashes)
        let exporter = iOSImagesExporter()
        let result = try await ui.withParallelEntries(
            "Exporting iOS images (\(entries.count) entries)...",
            count: entries.count
        ) {
            try await exporter.exportImages(
                entries: entries,
                platformConfig: platformConfig,
                context: context
            )
        }

        // Post-export: update Xcode project (only if not in Swift Package)
        if ios.xcassetsInSwiftPackage != true {
            do {
                let xcodeProject = try XcodeProjectWriter(
                    xcodeProjPath: ios.xcodeprojPath,
                    target: ios.target
                )
                for entry in entries {
                    if let url = entry.imageSwiftURL {
                        try xcodeProject.addFileReferenceToXcodeProj(url)
                    }
                    if let url = entry.swiftUIImageSwiftURL {
                        try xcodeProject.addFileReferenceToXcodeProj(url)
                    }
                }
                try xcodeProject.save()
            } catch {
                ui.warning(.xcodeProjectUpdateFailed(detail: error.localizedDescription))
            }
        }

        // Check for updates (only in standalone mode)
        if !batchMode {
            await checkForUpdate(logger: ExFigCommand.logger)
        }

        return result.toPlatformExportResult()
    }

    /// Exports Android images using plugin architecture.
    func exportAndroidImagesViaPlugin(
        entries: [AndroidImagesEntry],
        android: PKLConfig.Android,
        client: Client,
        params: PKLConfig,
        ui: TerminalUI,
        granularCacheManager: GranularCacheManager?
    ) async throws -> PlatformExportResult {
        let platformConfig = android.platformConfig()

        let batchMode = BatchSharedState.current?.isBatchMode ?? false
        let fileDownloader = faultToleranceOptions.createFileDownloader()

        // All entries in a platform section share one source kind (mixed sources not yet supported)
        guard let sourceKind = entries.first?.resolvedSourceKind else {
            throw ExFigError.configurationError("No entries provided for images export")
        }
        let componentsSource = try SourceFactory.createComponentsSource(
            for: sourceKind,
            client: client,
            params: params,
            platform: .android,
            logger: ExFigCommand.logger,
            filter: filter,
            ui: ui
        )

        let context = ImagesExportContextImpl(
            client: client,
            componentsSource: componentsSource,
            ui: ui,
            params: params,
            filter: filter,
            isBatchMode: batchMode,
            fileDownloader: fileDownloader,
            granularCacheManager: granularCacheManager,
            platform: .android
        )

        let exporter = AndroidImagesExporter()
        let result = try await ui.withParallelEntries(
            "Exporting Android images (\(entries.count) entries)...",
            count: entries.count
        ) {
            try await exporter.exportImages(
                entries: entries,
                platformConfig: platformConfig,
                context: context
            )
        }

        if !batchMode {
            await checkForUpdate(logger: ExFigCommand.logger)
        }

        return result.toPlatformExportResult()
    }

    /// Exports Flutter images using plugin architecture.
    func exportFlutterImagesViaPlugin(
        entries: [FlutterImagesEntry],
        flutter: PKLConfig.Flutter,
        client: Client,
        params: PKLConfig,
        ui: TerminalUI,
        granularCacheManager: GranularCacheManager?
    ) async throws -> PlatformExportResult {
        let platformConfig = flutter.platformConfig()

        let batchMode = BatchSharedState.current?.isBatchMode ?? false
        let fileDownloader = faultToleranceOptions.createFileDownloader()

        // All entries in a platform section share one source kind (mixed sources not yet supported)
        guard let sourceKind = entries.first?.resolvedSourceKind else {
            throw ExFigError.configurationError("No entries provided for images export")
        }
        let componentsSource = try SourceFactory.createComponentsSource(
            for: sourceKind,
            client: client,
            params: params,
            platform: .flutter,
            logger: ExFigCommand.logger,
            filter: filter,
            ui: ui
        )

        let context = ImagesExportContextImpl(
            client: client,
            componentsSource: componentsSource,
            ui: ui,
            params: params,
            filter: filter,
            isBatchMode: batchMode,
            fileDownloader: fileDownloader,
            granularCacheManager: granularCacheManager,
            platform: .flutter
        )

        let exporter = FlutterImagesExporter()
        let result = try await ui.withParallelEntries(
            "Exporting Flutter images (\(entries.count) entries)...",
            count: entries.count
        ) {
            try await exporter.exportImages(
                entries: entries,
                platformConfig: platformConfig,
                context: context
            )
        }

        if !batchMode {
            await checkForUpdate(logger: ExFigCommand.logger)
        }

        return result.toPlatformExportResult()
    }

    /// Exports Web images using plugin architecture.
    func exportWebImagesViaPlugin(
        entries: [WebImagesEntry],
        web: PKLConfig.Web,
        client: Client,
        params: PKLConfig,
        ui: TerminalUI,
        granularCacheManager: GranularCacheManager?
    ) async throws -> PlatformExportResult {
        let platformConfig = web.platformConfig()

        let batchMode = BatchSharedState.current?.isBatchMode ?? false
        let fileDownloader = faultToleranceOptions.createFileDownloader()

        // All entries in a platform section share one source kind (mixed sources not yet supported)
        guard let sourceKind = entries.first?.resolvedSourceKind else {
            throw ExFigError.configurationError("No entries provided for images export")
        }
        let componentsSource = try SourceFactory.createComponentsSource(
            for: sourceKind,
            client: client,
            params: params,
            platform: .web,
            logger: ExFigCommand.logger,
            filter: filter,
            ui: ui
        )

        let context = ImagesExportContextImpl(
            client: client,
            componentsSource: componentsSource,
            ui: ui,
            params: params,
            filter: filter,
            isBatchMode: batchMode,
            fileDownloader: fileDownloader,
            granularCacheManager: granularCacheManager,
            platform: .web
        )

        let exporter = WebImagesExporter()
        let result = try await ui.withParallelEntries(
            "Exporting Web images (\(entries.count) entries)...",
            count: entries.count
        ) {
            try await exporter.exportImages(
                entries: entries,
                platformConfig: platformConfig,
                context: context
            )
        }

        if !batchMode {
            await checkForUpdate(logger: ExFigCommand.logger)
        }

        return result.toPlatformExportResult()
    }
}

// MARK: - ImagesExportResult Extension

extension ImagesExportResult {
    /// Converts to CLI's PlatformExportResult format.
    func toPlatformExportResult() -> PlatformExportResult {
        PlatformExportResult(
            count: count,
            hashes: computedHashes,
            skippedCount: skippedCount
        )
    }
}

// swiftlint:enable function_parameter_count
