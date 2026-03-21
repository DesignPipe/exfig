import ExFigCore
import Foundation
import WebExport

/// Exports colors from Figma Variables to CSS variables and TypeScript constants.
///
/// This exporter handles the full export cycle:
/// 1. Loading colors from Figma Variables API
/// 2. Processing colors with kebab-case naming for CSS
/// 3. Generating CSS, TypeScript, and JSON files
public struct WebColorsExporter: ColorsExporter {
    public typealias Entry = WebColorsEntry
    public typealias PlatformConfig = WebPlatformConfig

    public init() {}

    /// Exports colors from Figma to Web project.
    ///
    /// - Parameters:
    ///   - entries: Array of colors configuration entries.
    ///   - platformConfig: Web platform configuration.
    ///   - context: Export context with dependencies.
    /// - Returns: Total number of colors exported.
    public func exportColors(
        entries: [WebColorsEntry],
        platformConfig: WebPlatformConfig,
        context: some ColorsExportContext
    ) async throws -> Int {
        let counts = try await parallelMapEntries(entries) { entry in
            try await exportSingleEntry(
                entry: entry,
                platformConfig: platformConfig,
                context: context
            )
        }
        let totalCount = counts.reduce(0, +)

        if !context.isBatchMode {
            context.success("Done! Exported \(totalCount) colors to Web project.")
        }

        return totalCount
    }

    // MARK: - Private

    private func exportSingleEntry(
        entry: WebColorsEntry,
        platformConfig: WebPlatformConfig,
        context: some ColorsExportContext
    ) async throws -> Int {
        // 1. Load colors from Figma
        let sourceInput = try entry.validatedColorsSourceInput()
        let colors = try await context.withSpinner(
            "Fetching colors from \(sourceInput.spinnerLabel)..."
        ) {
            try await context.loadColors(from: sourceInput)
        }

        // 2. Process colors (Web uses kebab-case for CSS variables)
        let processResult = try await context.withSpinner("Processing colors for Web...") {
            try context.processColors(
                colors,
                platform: .web,
                nameValidateRegexp: entry.nameValidateRegexp,
                nameReplaceRegexp: entry.nameReplaceRegexp,
                nameStyle: .kebabCase
            )
        }

        if let warning = processResult.warning {
            context.warning(warning)
        }

        let colorPairs = processResult.colorPairs

        // 3. Export to Web
        try await context.withSpinner("Exporting colors to Web project...") {
            try exportToWeb(
                colorPairs: colorPairs,
                entry: entry,
                platformConfig: platformConfig,
                context: context
            )
        }

        return colorPairs.count
    }

    private func exportToWeb(
        colorPairs: [AssetPair<Color>],
        entry: WebColorsEntry,
        platformConfig: WebPlatformConfig,
        context: some ColorsExportContext
    ) throws {
        // Determine output directory (entry-level overrides take priority)
        let resolvedOutput = entry.resolvedOutput(fallback: platformConfig.output)
        let outputDirectory: URL = if let entryOutput = entry.outputDirectory {
            resolvedOutput.appendingPathComponent(entryOutput)
        } else {
            resolvedOutput
        }

        // Create output configuration
        let resolvedTemplatesPath = entry.resolvedTemplatesPath(fallback: platformConfig.templatesPath)
        let output = WebOutput(
            outputDirectory: outputDirectory,
            templatesPath: resolvedTemplatesPath
        )

        // Export
        let exporter = WebColorExporter(
            output: output,
            cssFileName: entry.cssFileName,
            tsFileName: entry.tsFileName,
            jsonFileName: entry.jsonFileName
        )
        let files = try exporter.export(colorPairs: colorPairs)

        // Write files
        try context.writeFiles(files)
    }
}
