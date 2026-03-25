import ExFig_Android
import ExFig_iOS
import ExFigCore
import FigmaAPI
import Foundation
import XcodeExport

// MARK: - Typography Export Input

/// Groups common parameters for typography export to reduce function parameter count.
struct TypographyExportInput {
    let figma: PKLConfig.Figma?
    let common: PKLConfig.Common?
    let client: Client
    let ui: TerminalUI
}

// MARK: - Plugin-based Typography Export

extension ExFigCommand.ExportTypography {
    /// Exports iOS typography using plugin architecture.
    ///
    /// This method uses `iOSTypographyExporter` from the plugin system instead of
    /// direct implementation. It handles both export and post-export tasks
    /// like Xcode project updates.
    ///
    /// - Parameters:
    ///   - entry: Params typography entry to convert and export.
    ///   - ios: iOS platform configuration from PKLConfig.
    ///   - input: Common export input (figma, common, client, ui).
    /// - Returns: Number of text styles exported.
    func exportiOSTypographyViaPlugin(
        entry: iOSTypographyEntry,
        ios: PKLConfig.iOS,
        input: TypographyExportInput
    ) async throws -> Int {
        // Convert Params to plugin types
        let pluginEntry = entry
        let platformConfig = ios.platformConfig(figma: input.figma)

        // Create context
        let batchMode = BatchSharedState.current?.isBatchMode ?? false
        let typographySource = FigmaTypographySource(client: input.client)
        let context = TypographyExportContextImpl(
            client: input.client,
            typographySource: typographySource,
            ui: input.ui,
            filter: nil,
            isBatchMode: batchMode
        )

        // Export via plugin
        let exporter = iOSTypographyExporter()
        let count = try await exporter.exportTypography(
            entry: pluginEntry,
            platformConfig: platformConfig,
            context: context
        )

        // Post-export: update Xcode project (only if not in Swift Package)
        #if canImport(XcodeProj)
            if ios.xcassetsInSwiftPackage != true {
                do {
                    let xcodeProject = try XcodeProjectWriter(
                        xcodeProjPath: ios.xcodeprojPath,
                        target: ios.target
                    )
                    // Add Swift file references
                    if let url = pluginEntry.fontSwiftURL {
                        try xcodeProject.addFileReferenceToXcodeProj(url)
                    }
                    if let url = pluginEntry.swiftUIFontSwiftURL {
                        try xcodeProject.addFileReferenceToXcodeProj(url)
                    }
                    if let url = pluginEntry.labelStyleSwiftURL {
                        try xcodeProject.addFileReferenceToXcodeProj(url)
                    }
                    try xcodeProject.save()
                } catch {
                    input.ui.warning(.xcodeProjectUpdateFailed(detail: error.localizedDescription))
                }
            }
        #endif

        // Check for updates (only in standalone mode)
        if !batchMode {
            await checkForUpdate(logger: ExFigCommand.logger)
        }

        return count
    }

    /// Exports Android typography using plugin architecture.
    func exportAndroidTypographyViaPlugin(
        entry: AndroidTypographyEntry,
        android: PKLConfig.Android,
        input: TypographyExportInput
    ) async throws -> Int {
        let pluginEntry = entry
        let platformConfig = android.platformConfig(figma: input.figma)

        let batchMode = BatchSharedState.current?.isBatchMode ?? false
        let typographySource = FigmaTypographySource(client: input.client)
        let context = TypographyExportContextImpl(
            client: input.client,
            typographySource: typographySource,
            ui: input.ui,
            filter: nil,
            isBatchMode: batchMode
        )

        let exporter = AndroidTypographyExporter()
        let count = try await exporter.exportTypography(
            entry: pluginEntry,
            platformConfig: platformConfig,
            context: context
        )

        if !batchMode {
            await checkForUpdate(logger: ExFigCommand.logger)
        }

        return count
    }
}
