import ExFigCore
import FlutterExport
import Foundation

/// Exports colors from Figma Variables to Flutter Dart color classes.
///
/// This exporter handles the full export cycle:
/// 1. Loading colors from Figma Variables API
/// 2. Processing colors with camelCase naming
/// 3. Generating Dart color class files
public struct FlutterColorsExporter: ColorsExporter {
    public typealias Entry = FlutterColorsEntry
    public typealias PlatformConfig = FlutterPlatformConfig

    public init() {}

    /// Exports colors from Figma to Flutter project.
    ///
    /// - Parameters:
    ///   - entries: Array of colors configuration entries.
    ///   - platformConfig: Flutter platform configuration.
    ///   - context: Export context with dependencies.
    /// - Returns: Total number of colors exported.
    public func exportColors(
        entries: [FlutterColorsEntry],
        platformConfig: FlutterPlatformConfig,
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
            context.success("Done! Exported \(totalCount) colors to Flutter project.")
        }

        return totalCount
    }

    // MARK: - Private

    private func exportSingleEntry(
        entry: FlutterColorsEntry,
        platformConfig: FlutterPlatformConfig,
        context: some ColorsExportContext
    ) async throws -> Int {
        // 1. Load colors from Figma
        let sourceInput = try entry.validatedColorsSourceInput()
        let colors = try await context.withSpinner(
            "Fetching colors (\(sourceInput.sourceKind.rawValue))..."
        ) {
            try await context.loadColors(from: sourceInput)
        }

        // 2. Process colors (Flutter uses camelCase)
        let processResult = try await context.withSpinner("Processing colors for Flutter...") {
            try context.processColors(
                colors,
                platform: .flutter,
                nameValidateRegexp: entry.nameValidateRegexp,
                nameReplaceRegexp: entry.nameReplaceRegexp,
                nameStyle: .camelCase
            )
        }

        if let warning = processResult.warning {
            context.warning(warning)
        }

        let colorPairs = processResult.colorPairs

        // 3. Export to Flutter
        try await context.withSpinner("Exporting colors to Flutter project...") {
            try exportToFlutter(
                colorPairs: colorPairs,
                entry: entry,
                platformConfig: platformConfig,
                context: context
            )
        }

        return colorPairs.count
    }

    private func exportToFlutter(
        colorPairs: [AssetPair<Color>],
        entry: FlutterColorsEntry,
        platformConfig: FlutterPlatformConfig,
        context: some ColorsExportContext
    ) throws {
        // Create output configuration (entry-level overrides take priority)
        let resolvedTemplatesPath = entry.resolvedTemplatesPath(fallback: platformConfig.templatesPath)
        let output = FlutterOutput(
            outputDirectory: platformConfig.output,
            templatesPath: resolvedTemplatesPath,
            colorsClassName: entry.className
        )

        // Export
        let exporter = FlutterColorExporter(
            output: output,
            outputFileName: entry.output
        )
        let files = try exporter.export(colorPairs: colorPairs)

        // Clean up old file
        let fileName = entry.output ?? "colors.dart"
        let colorsFileURL = platformConfig.output.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(atPath: colorsFileURL.path)

        // Write files
        try context.writeFiles(files)
    }
}
