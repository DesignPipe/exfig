import AndroidExport
import ExFigCore
import Foundation

/// Exports colors from Figma Variables to Android XML resources and Kotlin extensions.
///
/// This exporter handles the full export cycle:
/// 1. Loading colors from Figma Variables API
/// 2. Processing colors with snake_case naming
/// 3. Generating XML resources and Kotlin Compose extensions
///
/// ## Usage
///
/// ```swift
/// let exporter = AndroidColorsExporter()
/// let count = try await exporter.exportColors(
///     entries: colorsEntries,
///     platformConfig: androidPlatformConfig,
///     context: colorsContext
/// )
/// ```
public struct AndroidColorsExporter: ColorsExporter {
    public typealias Entry = AndroidColorsEntry
    public typealias PlatformConfig = AndroidPlatformConfig

    public init() {}

    /// Exports colors from Figma to Android project.
    ///
    /// - Parameters:
    ///   - entries: Array of colors configuration entries.
    ///   - platformConfig: Android platform configuration.
    ///   - context: Export context with dependencies.
    /// - Returns: Total number of colors exported.
    public func exportColors(
        entries: [AndroidColorsEntry],
        platformConfig: AndroidPlatformConfig,
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
            context.success("Done! Exported \(totalCount) colors to Android project.")
        }

        return totalCount
    }

    // MARK: - Private

    private func exportSingleEntry(
        entry: AndroidColorsEntry,
        platformConfig: AndroidPlatformConfig,
        context: some ColorsExportContext
    ) async throws -> Int {
        // 1. Load colors from Figma
        let sourceInput = try entry.validatedColorsSourceInput()
        let colors = try await context.withSpinner(
            "Fetching colors from \(sourceInput.spinnerLabel)..."
        ) {
            try await context.loadColors(from: sourceInput)
        }

        // 2. Process colors (Android uses snake_case)
        let processResult = try await context.withSpinner("Processing colors for Android...") {
            try context.processColors(
                colors,
                platform: .android,
                nameValidateRegexp: entry.nameValidateRegexp,
                nameReplaceRegexp: entry.nameReplaceRegexp,
                nameStyle: .snakeCase
            )
        }

        if let warning = processResult.warning {
            context.warning(warning)
        }

        let colorPairs = processResult.colorPairs

        // 3. Export to Android
        try await context.withSpinner("Exporting colors to Android Studio project...") {
            try exportToAndroid(
                colorPairs: colorPairs,
                entry: entry,
                platformConfig: platformConfig,
                context: context
            )
        }

        return colorPairs.count
    }

    private func exportToAndroid(
        colorPairs: [AssetPair<Color>],
        entry: AndroidColorsEntry,
        platformConfig: AndroidPlatformConfig,
        context: some ColorsExportContext
    ) throws {
        // Resolve entry-level overrides
        let resolvedMainRes = entry.resolvedMainRes(fallback: platformConfig.mainRes)
        let resolvedMainSrc = entry.resolvedMainSrc(fallback: platformConfig.mainSrc)
        let resolvedTemplatesPath = entry.resolvedTemplatesPath(fallback: platformConfig.templatesPath)

        // Create output configuration
        let output = AndroidOutput(
            xmlOutputDirectory: resolvedMainRes,
            xmlResourcePackage: platformConfig.resourcePackage,
            srcDirectory: resolvedMainSrc,
            packageName: entry.composePackageName,
            colorKotlinURL: entry.colorKotlinURL,
            templatesPath: resolvedTemplatesPath,
            xmlDisabled: entry.xmlDisabled ?? false
        )

        // Export
        let exporter = AndroidColorExporter(
            output: output,
            xmlOutputFileName: entry.xmlOutputFileName
        )
        let files = try exporter.export(colorPairs: colorPairs)

        // Clean up old XML files (unless XML generation is disabled)
        if !(entry.xmlDisabled ?? false) {
            let fileName = entry.xmlOutputFileName ?? "colors.xml"
            let lightColorsFileURL = resolvedMainRes
                .appendingPathComponent("values/\(fileName)")
            let darkColorsFileURL = resolvedMainRes
                .appendingPathComponent("values-night/\(fileName)")

            try? FileManager.default.removeItem(atPath: lightColorsFileURL.path)
            try? FileManager.default.removeItem(atPath: darkColorsFileURL.path)
        }

        // Write files
        try context.writeFiles(files)
    }
}
