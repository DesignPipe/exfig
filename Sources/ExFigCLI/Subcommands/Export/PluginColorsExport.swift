import ExFig_Android
import ExFig_Flutter
import ExFig_iOS
import ExFig_Web
import ExFigCore
import FigmaAPI
import Foundation
import XcodeExport

// MARK: - Plugin-based Colors Export

extension ExFigCommand.ExportColors {
    /// Exports iOS colors using plugin architecture.
    ///
    /// This method uses `iOSColorsExporter` from the plugin system instead of
    /// direct implementation. It handles both export and post-export tasks
    /// like syncCodeSyntax and Xcode project updates.
    ///
    /// - Parameters:
    ///   - entries: Params entries to convert and export.
    ///   - ios: iOS platform configuration from PKLConfig.
    ///   - client: Figma API client.
    ///   - ui: Terminal UI for output.
    /// - Returns: Number of colors exported.
    func exportiOSColorsViaPlugin(
        entries: [iOSColorsEntry],
        ios: PKLConfig.iOS,
        client: Client,
        ui: TerminalUI
    ) async throws -> Int {
        let platformConfig = ios.platformConfig()

        // Create context (SourceFactory dispatches per-entry based on sourceKind)
        let batchMode = BatchSharedState.current?.isBatchMode ?? false
        let context = ColorsExportContextImpl(
            client: client,
            ui: ui,
            filter: filter,
            isBatchMode: batchMode
        )

        // Export via plugin
        let exporter = iOSColorsExporter()
        let count = try await ui.withParallelEntries(
            "Exporting iOS colors (\(entries.count) entries)...",
            count: entries.count
        ) {
            try await exporter.exportColors(
                entries: entries,
                platformConfig: platformConfig,
                context: context
            )
        }

        try await syncCodeSyntaxIfNeeded(entries: entries, client: client, ui: ui)

        // Post-export: update Xcode project (only if not in Swift Package)
        if ios.xcassetsInSwiftPackage != true {
            do {
                let xcodeProject = try XcodeProjectWriter(
                    xcodeProjPath: ios.xcodeprojPath,
                    target: ios.target
                )
                // Add Swift file references for each entry
                for entry in entries {
                    if let url = entry.colorSwiftURL {
                        try xcodeProject.addFileReferenceToXcodeProj(url)
                    }
                    if let url = entry.swiftuiColorSwiftURL {
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

        return count
    }

    private func syncCodeSyntaxIfNeeded(
        entries: [iOSColorsEntry],
        client: Client,
        ui: TerminalUI
    ) async throws {
        for entry in entries where entry.syncCodeSyntax == true {
            guard let fileId = entry.tokensFileId, !fileId.isEmpty else {
                ui.warning("Cannot sync codeSyntax: tokensFileId is required")
                continue
            }
            guard let collectionName = entry.tokensCollectionName, !collectionName.isEmpty else {
                ui.warning("Cannot sync codeSyntax: tokensCollectionName is required")
                continue
            }
            if let template = entry.codeSyntaxTemplate {
                let syncCount = try await ui.withSpinner("Syncing codeSyntax to Figma...") {
                    let syncer = CodeSyntaxSyncer(client: client)
                    return try await syncer.sync(
                        fileId: fileId,
                        collectionName: collectionName,
                        template: template,
                        nameStyle: entry.coreNameStyle,
                        nameValidateRegexp: entry.nameValidateRegexp,
                        nameReplaceRegexp: entry.nameReplaceRegexp
                    )
                }
                ui.info("Synced codeSyntax for \(syncCount) variables")
            }
        }
    }

    /// Exports Android colors using plugin architecture.
    func exportAndroidColorsViaPlugin(
        entries: [AndroidColorsEntry],
        android: PKLConfig.Android,
        client: Client,
        ui: TerminalUI
    ) async throws -> Int {
        let platformConfig = android.platformConfig()

        let batchMode = BatchSharedState.current?.isBatchMode ?? false
        let context = ColorsExportContextImpl(
            client: client,
            ui: ui,
            filter: filter,
            isBatchMode: batchMode
        )

        let exporter = AndroidColorsExporter()
        let count = try await ui.withParallelEntries(
            "Exporting Android colors (\(entries.count) entries)...",
            count: entries.count
        ) {
            try await exporter.exportColors(
                entries: entries,
                platformConfig: platformConfig,
                context: context
            )
        }

        if !batchMode {
            await checkForUpdate(logger: ExFigCommand.logger)
        }

        return count
    }

    /// Exports Flutter colors using plugin architecture.
    func exportFlutterColorsViaPlugin(
        entries: [FlutterColorsEntry],
        flutter: PKLConfig.Flutter,
        client: Client,
        ui: TerminalUI
    ) async throws -> Int {
        let platformConfig = flutter.platformConfig()

        let batchMode = BatchSharedState.current?.isBatchMode ?? false
        let context = ColorsExportContextImpl(
            client: client,
            ui: ui,
            filter: filter,
            isBatchMode: batchMode
        )

        let exporter = FlutterColorsExporter()
        let count = try await ui.withParallelEntries(
            "Exporting Flutter colors (\(entries.count) entries)...",
            count: entries.count
        ) {
            try await exporter.exportColors(
                entries: entries,
                platformConfig: platformConfig,
                context: context
            )
        }

        if !batchMode {
            await checkForUpdate(logger: ExFigCommand.logger)
        }

        return count
    }

    /// Exports Web colors using plugin architecture.
    func exportWebColorsViaPlugin(
        entries: [WebColorsEntry],
        web: PKLConfig.Web,
        client: Client,
        ui: TerminalUI
    ) async throws -> Int {
        let platformConfig = web.platformConfig()

        let batchMode = BatchSharedState.current?.isBatchMode ?? false
        let context = ColorsExportContextImpl(
            client: client,
            ui: ui,
            filter: filter,
            isBatchMode: batchMode
        )

        let exporter = WebColorsExporter()
        let count = try await ui.withParallelEntries(
            "Exporting Web colors (\(entries.count) entries)...",
            count: entries.count
        ) {
            try await exporter.exportColors(
                entries: entries,
                platformConfig: platformConfig,
                context: context
            )
        }

        if !batchMode {
            await checkForUpdate(logger: ExFigCommand.logger)
        }

        return count
    }
}
