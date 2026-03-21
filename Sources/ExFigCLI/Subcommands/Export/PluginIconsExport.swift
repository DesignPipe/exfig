import ExFig_Android
import ExFig_Flutter
import ExFig_iOS
import ExFig_Web
import ExFigCore
import FigmaAPI
import Foundation
import XcodeExport

// swiftlint:disable function_parameter_count

// MARK: - Plugin-based Icons Export

extension ExFigCommand.ExportIcons {
    /// Exports iOS icons using plugin architecture.
    ///
    /// This method uses `iOSIconsExporter` from the plugin system with full
    /// granular cache support. The exporter detects cache context and uses
    /// appropriate loading methods.
    ///
    /// - Parameters:
    ///   - entries: Params entries to convert and export.
    ///   - ios: iOS platform configuration from PKLConfig.
    ///   - client: Figma API client.
    ///   - params: Full params for context creation.
    ///   - ui: Terminal UI for output.
    ///   - granularCacheManager: Optional granular cache manager.
    /// - Returns: Platform export result with count, hashes, and skipped count.
    func exportiOSIconsViaPlugin(
        entries: [iOSIconsEntry],
        ios: PKLConfig.iOS,
        client: Client,
        params: PKLConfig,
        ui: TerminalUI,
        granularCacheManager: GranularCacheManager?
    ) async throws -> PlatformExportResult {
        let platformConfig = ios.platformConfig()

        let batchMode = BatchSharedState.current?.isBatchMode ?? false
        let fileDownloader = faultToleranceOptions.createFileDownloader()

        let componentsSource = FigmaComponentsSource(
            client: client,
            params: params,
            platform: .ios,
            logger: ExFigCommand.logger,
            filter: filter
        )

        let context = IconsExportContextImpl(
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

        // Export via plugin (returns IconsExportResult with hashes)
        let exporter = iOSIconsExporter()
        let result = try await ui.withParallelEntries(
            "Exporting iOS icons (\(entries.count) entries)...",
            count: entries.count
        ) {
            try await exporter.exportIcons(
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

        // Convert IconsExportResult to PlatformExportResult
        return result.toPlatformExportResult()
    }

    /// Exports Android icons using plugin architecture.
    func exportAndroidIconsViaPlugin(
        entries: [AndroidIconsEntry],
        android: PKLConfig.Android,
        client: Client,
        params: PKLConfig,
        ui: TerminalUI,
        granularCacheManager: GranularCacheManager?
    ) async throws -> PlatformExportResult {
        let platformConfig = android.platformConfig()

        let batchMode = BatchSharedState.current?.isBatchMode ?? false
        let fileDownloader = faultToleranceOptions.createFileDownloader()

        let componentsSource = FigmaComponentsSource(
            client: client,
            params: params,
            platform: .android,
            logger: ExFigCommand.logger,
            filter: filter
        )

        let context = IconsExportContextImpl(
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

        let exporter = AndroidIconsExporter()
        let result = try await ui.withParallelEntries(
            "Exporting Android icons (\(entries.count) entries)...",
            count: entries.count
        ) {
            try await exporter.exportIcons(
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

    /// Exports Flutter icons using plugin architecture.
    func exportFlutterIconsViaPlugin(
        entries: [FlutterIconsEntry],
        flutter: PKLConfig.Flutter,
        client: Client,
        params: PKLConfig,
        ui: TerminalUI,
        granularCacheManager: GranularCacheManager?
    ) async throws -> PlatformExportResult {
        let platformConfig = flutter.platformConfig()

        let batchMode = BatchSharedState.current?.isBatchMode ?? false
        let fileDownloader = faultToleranceOptions.createFileDownloader()

        let componentsSource = FigmaComponentsSource(
            client: client,
            params: params,
            platform: .flutter,
            logger: ExFigCommand.logger,
            filter: filter
        )

        let context = IconsExportContextImpl(
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

        let exporter = FlutterIconsExporter()
        let result = try await ui.withParallelEntries(
            "Exporting Flutter icons (\(entries.count) entries)...",
            count: entries.count
        ) {
            try await exporter.exportIcons(
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

    /// Exports Web icons using plugin architecture.
    func exportWebIconsViaPlugin(
        entries: [WebIconsEntry],
        web: PKLConfig.Web,
        client: Client,
        params: PKLConfig,
        ui: TerminalUI,
        granularCacheManager: GranularCacheManager?
    ) async throws -> PlatformExportResult {
        let platformConfig = web.platformConfig()

        let batchMode = BatchSharedState.current?.isBatchMode ?? false
        let fileDownloader = faultToleranceOptions.createFileDownloader()

        let componentsSource = FigmaComponentsSource(
            client: client,
            params: params,
            platform: .web,
            logger: ExFigCommand.logger,
            filter: filter
        )

        let context = IconsExportContextImpl(
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

        let exporter = WebIconsExporter()
        let result = try await ui.withParallelEntries(
            "Exporting Web icons (\(entries.count) entries)...",
            count: entries.count
        ) {
            try await exporter.exportIcons(
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

// MARK: - IconsExportResult Extension

extension IconsExportResult {
    /// Converts to CLI's PlatformExportResult format.
    ///
    /// `NodeId` is a typealias for `String`, so we just use the hashes directly.
    func toPlatformExportResult() -> PlatformExportResult {
        PlatformExportResult(
            count: count,
            hashes: computedHashes,
            skippedCount: skippedCount
        )
    }
}

// swiftlint:enable function_parameter_count
