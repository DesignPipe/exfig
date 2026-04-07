// swiftlint:disable file_length

import AndroidExport
import ExFigCore
import Foundation
import SVGKit

/// Exports images from Figma frames to Android drawable resources.
///
/// Supports multiple workflows:
/// - PNG source → PNG/WebP output
/// - SVG source → VectorDrawable XML output
/// - SVG source → WebP output (rasterization)
public struct AndroidImagesExporter: ImagesExporter {
    public typealias Entry = AndroidImagesEntry
    public typealias PlatformConfig = AndroidPlatformConfig

    public init() {}

    public func exportImages(
        entries: [AndroidImagesEntry],
        platformConfig: AndroidPlatformConfig,
        context: some ImagesExportContext
    ) async throws -> ImagesExportResult {
        let counts = try await parallelMapEntries(entries) { entry in
            try await exportSingleEntry(
                entry: entry,
                platformConfig: platformConfig,
                context: context
            )
        }
        let totalCount = counts.reduce(0, +)

        if !context.isBatchMode {
            context.success("Done! Exported \(totalCount) images to Android project.")
        }

        return ImagesExportResult.simple(count: totalCount)
    }

    // MARK: - Private

    private func exportSingleEntry(
        entry: AndroidImagesEntry,
        platformConfig: AndroidPlatformConfig,
        context: some ImagesExportContext
    ) async throws -> Int {
        let sourceFormat = entry.sourceFormat ?? .png
        let outputFormat = entry.format

        switch (sourceFormat, outputFormat) {
        case (.svg, .svg):
            return try await exportSVGToVectorDrawable(
                entry: entry, platformConfig: platformConfig, context: context
            )
        case (.svg, .webp):
            return try await exportSVGToWebp(
                entry: entry, platformConfig: platformConfig, context: context
            )
        case (.svg, .png):
            return try await exportSVGToPNG(
                entry: entry, platformConfig: platformConfig, context: context
            )
        case (.png, .webp):
            return try await exportPNGToWebp(
                entry: entry, platformConfig: platformConfig, context: context
            )
        case (.png, .png):
            return try await exportPNGToPNG(
                entry: entry, platformConfig: platformConfig, context: context
            )
        case (.png, .svg):
            throw AndroidImagesExporterError.incompatibleFormat(source: "PNG", output: "VectorDrawable")
        }
    }
}

// MARK: - SVG to VectorDrawable

private extension AndroidImagesExporter {
    func exportSVGToVectorDrawable(
        entry: AndroidImagesEntry,
        platformConfig: AndroidPlatformConfig,
        context: some ImagesExportContext
    ) async throws -> Int {
        let (imagePairs, tempDirs) = try await loadAndProcessSVG(entry: entry, context: context)

        let remoteFiles = AndroidImagesHelpers.makeSVGRemoteFiles(
            imagePairs: imagePairs, lightDir: tempDirs.light, darkDir: tempDirs.dark
        )
        let localFiles = try await context.downloadFiles(remoteFiles, progressTitle: "Downloading SVGs")
        try context.writeFiles(localFiles)

        // Convert to VectorDrawable
        let converter = NativeVectorDrawableConverter(strictPathValidation: false)
        try await context.withSpinner("Converting SVGs to vector drawables...") {
            if FileManager.default.fileExists(atPath: tempDirs.light.path) {
                try await converter.convertAsync(inputDirectoryUrl: tempDirs.light, rtlFiles: [])
            }
            if FileManager.default.fileExists(atPath: tempDirs.dark.path) {
                try await converter.convertAsync(inputDirectoryUrl: tempDirs.dark, rtlFiles: [])
            }
        }

        let (lightDir, darkDir) = outputDirectories(entry: entry, platformConfig: platformConfig)
        if context.filter == nil {
            try? FileManager.default.removeItem(atPath: lightDir.path)
            try? FileManager.default.removeItem(atPath: darkDir.path)
        }

        var allFiles = localFiles.map { file -> FileContents in
            let dir = file.dark ? darkDir : lightDir
            let source = file.destination.url.deletingPathExtension().appendingPathExtension("xml")
            let fileURL = file.destination.file.deletingPathExtension().appendingPathExtension("xml")
            return FileContents(destination: Destination(directory: dir, file: fileURL), dataFile: source)
        }

        try addCodeConnectFile(
            to: &allFiles, imagePairs: imagePairs,
            entry: entry, platformConfig: platformConfig, context: context
        )

        let filesToWrite = allFiles
        try await context.withSpinner("Writing files to Android project...") {
            try context.writeFiles(filesToWrite)
        }

        try? FileManager.default.removeItem(at: tempDirs.light)
        try? FileManager.default.removeItem(at: tempDirs.dark)

        return imagePairs.count
    }
}

// MARK: - SVG to WebP

private extension AndroidImagesExporter {
    func exportSVGToWebp(
        entry: AndroidImagesEntry,
        platformConfig: AndroidPlatformConfig,
        context: some ImagesExportContext
    ) async throws -> Int {
        let (imagePairs, tempDirs) = try await loadAndProcessSVG(entry: entry, context: context)

        let remoteFiles = AndroidImagesHelpers.makeSVGRemoteFiles(
            imagePairs: imagePairs, lightDir: tempDirs.light, darkDir: tempDirs.dark
        )
        let localSVGFiles = try await context.downloadFiles(remoteFiles, progressTitle: "Downloading SVGs")
        try context.writeFiles(localSVGFiles)

        let scales = entry.effectiveScales
        let webpFiles = try await context.rasterizeSVGs(
            localSVGFiles, scales: scales, to: .webp,
            webpOptions: entry.webpConverterOptions,
            progressTitle: "Rasterizing SVGs to WebP"
        )

        let resolvedMainRes = resolveAndCleanOutput(
            entry: entry, platformConfig: platformConfig, context: context
        )

        let isSingleScale = scales.count == 1
        var collectedFiles: [FileContents] = []
        for file in webpFiles {
            guard let data = file.data else {
                let name = file.destination.file.lastPathComponent
                context.warning("Skipped image '\(name)': no data after WebP conversion")
                continue
            }
            let stripped = file.strippingScaleSuffix()
            let dirName = Drawable.scaleToDrawableName(file.scale, dark: file.dark, singleScale: isSingleScale)
            let directory = resolvedMainRes
                .appendingPathComponent(entry.output)
                .appendingPathComponent(dirName, isDirectory: true)
            collectedFiles.append(FileContents(
                destination: Destination(directory: directory, file: stripped.destination.file),
                data: data,
                scale: file.scale,
                dark: file.dark
            ))
        }
        try addCodeConnectFile(
            to: &collectedFiles, imagePairs: imagePairs,
            entry: entry, platformConfig: platformConfig, context: context
        )

        let finalFiles = collectedFiles

        try await context.withSpinner("Writing files to Android project...") {
            try context.writeFiles(finalFiles)
        }

        try? FileManager.default.removeItem(at: tempDirs.light)
        try? FileManager.default.removeItem(at: tempDirs.dark)

        return imagePairs.count
    }
}

// MARK: - SVG to PNG

private extension AndroidImagesExporter {
    func exportSVGToPNG(
        entry: AndroidImagesEntry,
        platformConfig: AndroidPlatformConfig,
        context: some ImagesExportContext
    ) async throws -> Int {
        let (imagePairs, tempDirs) = try await loadAndProcessSVG(entry: entry, context: context)

        let remoteFiles = AndroidImagesHelpers.makeSVGRemoteFiles(
            imagePairs: imagePairs, lightDir: tempDirs.light, darkDir: tempDirs.dark
        )
        let localSVGFiles = try await context.downloadFiles(remoteFiles, progressTitle: "Downloading SVGs")
        try context.writeFiles(localSVGFiles)

        let scales = entry.effectiveScales
        let pngFiles = try await context.rasterizeSVGs(
            localSVGFiles, scales: scales, to: .png,
            progressTitle: "Rasterizing SVGs to PNG"
        )

        let resolvedMainRes = resolveAndCleanOutput(
            entry: entry, platformConfig: platformConfig, context: context
        )

        let isSingleScale = scales.count == 1
        var collectedFiles: [FileContents] = []
        for file in pngFiles {
            guard let data = file.data else {
                let name = file.destination.file.lastPathComponent
                context.warning("Skipped image '\(name)': no data after PNG conversion")
                continue
            }
            let stripped = file.strippingScaleSuffix()
            let dirName = Drawable.scaleToDrawableName(file.scale, dark: file.dark, singleScale: isSingleScale)
            let directory = resolvedMainRes
                .appendingPathComponent(entry.output)
                .appendingPathComponent(dirName, isDirectory: true)
            collectedFiles.append(FileContents(
                destination: Destination(directory: directory, file: stripped.destination.file),
                data: data,
                scale: file.scale,
                dark: file.dark
            ))
        }

        try addCodeConnectFile(
            to: &collectedFiles, imagePairs: imagePairs,
            entry: entry, platformConfig: platformConfig, context: context
        )

        let finalFiles = collectedFiles

        try await context.withSpinner("Writing files to Android project...") {
            try context.writeFiles(finalFiles)
        }

        try? FileManager.default.removeItem(at: tempDirs.light)
        try? FileManager.default.removeItem(at: tempDirs.dark)

        return imagePairs.count
    }
}

// MARK: - PNG to WebP

private extension AndroidImagesExporter {
    func exportPNGToWebp(
        entry: AndroidImagesEntry,
        platformConfig: AndroidPlatformConfig,
        context: some ImagesExportContext
    ) async throws -> Int {
        let (imagePairs, tempDir) = try await loadAndProcessPNG(entry: entry, context: context)

        let remoteFiles = try AndroidImagesHelpers.makeRasterRemoteFiles(
            imagePairs: imagePairs, outputDirectory: tempDir
        )
        var localFiles = try await context.downloadFiles(remoteFiles, progressTitle: "Downloading images")
        try context.writeFiles(localFiles)

        // Convert PNG to WebP
        localFiles = try await context.convertFormat(
            localFiles, to: .webp,
            heicOptions: nil, webpOptions: entry.webpConverterOptions,
            progressTitle: "Converting to WebP"
        )

        let resolvedMainRes = resolveAndCleanOutput(
            entry: entry, platformConfig: platformConfig, context: context
        )

        let scales = entry.effectiveScales
        let isSingleScale = scales.count == 1
        var allFiles = localFiles.map { file -> FileContents in
            let dirName = Drawable.scaleToDrawableName(file.scale, dark: file.dark, singleScale: isSingleScale)
            let directory = resolvedMainRes
                .appendingPathComponent(entry.output)
                .appendingPathComponent(dirName, isDirectory: true)
            return FileContents(
                destination: Destination(directory: directory, file: file.destination.file),
                dataFile: file.destination.url
            )
        }

        try addCodeConnectFile(
            to: &allFiles, imagePairs: imagePairs,
            entry: entry, platformConfig: platformConfig, context: context
        )

        let filesToWrite = allFiles
        try await context.withSpinner("Writing files to Android project...") {
            try context.writeFiles(filesToWrite)
        }

        try? FileManager.default.removeItem(at: tempDir)

        return imagePairs.count
    }
}

// MARK: - PNG to PNG

private extension AndroidImagesExporter {
    func exportPNGToPNG(
        entry: AndroidImagesEntry,
        platformConfig: AndroidPlatformConfig,
        context: some ImagesExportContext
    ) async throws -> Int {
        let (imagePairs, tempDir) = try await loadAndProcessPNG(entry: entry, context: context)

        let remoteFiles = try AndroidImagesHelpers.makeRasterRemoteFiles(
            imagePairs: imagePairs, outputDirectory: tempDir
        )
        let localFiles = try await context.downloadFiles(remoteFiles, progressTitle: "Downloading images")
        try context.writeFiles(localFiles)

        let resolvedMainRes = resolveAndCleanOutput(
            entry: entry, platformConfig: platformConfig, context: context
        )

        let scales = entry.effectiveScales
        let isSingleScale = scales.count == 1
        var allFiles = localFiles.map { file -> FileContents in
            let dirName = Drawable.scaleToDrawableName(file.scale, dark: file.dark, singleScale: isSingleScale)
            let directory = resolvedMainRes
                .appendingPathComponent(entry.output)
                .appendingPathComponent(dirName, isDirectory: true)
            return FileContents(
                destination: Destination(directory: directory, file: file.destination.file),
                dataFile: file.destination.url
            )
        }

        try addCodeConnectFile(
            to: &allFiles, imagePairs: imagePairs,
            entry: entry, platformConfig: platformConfig, context: context
        )

        let filesToWrite = allFiles
        try await context.withSpinner("Writing files to Android project...") {
            try context.writeFiles(filesToWrite)
        }

        try? FileManager.default.removeItem(at: tempDir)

        return imagePairs.count
    }
}

// MARK: - Code Connect

private extension AndroidImagesExporter {
    func generateCodeConnect(
        imagePairs: [AssetPair<ImagePack>],
        entry: AndroidImagesEntry,
        platformConfig: AndroidPlatformConfig,
        context: some ImagesExportContext
    ) throws -> FileContents? {
        guard let url = entry.codeConnectKotlinURL else { return nil }
        guard let resourcePackage = platformConfig.resourcePackage else {
            context.warning("Code Connect skipped: 'resourcePackage' is required")
            return nil
        }
        let exporter = AndroidCodeConnectExporter(
            templatesPath: entry.resolvedTemplatesPath(fallback: platformConfig.templatesPath)
        )
        // Images use resourcePackage as both the Kotlin package and R class package,
        // since image Code Connect files live alongside the resource module.
        // Icons use the dedicated composePackageName which may differ.
        return try exporter.generateCodeConnect(
            imagePacks: imagePairs,
            url: url,
            packageName: resourcePackage,
            xmlResourcePackage: resourcePackage
        )
    }

    func addCodeConnectFile(
        to files: inout [FileContents],
        imagePairs: [AssetPair<ImagePack>],
        entry: AndroidImagesEntry,
        platformConfig: AndroidPlatformConfig,
        context: some ImagesExportContext
    ) throws {
        if let codeConnectFile = try generateCodeConnect(
            imagePairs: imagePairs, entry: entry, platformConfig: platformConfig, context: context
        ) {
            files.append(codeConnectFile)
        }
    }
}

// MARK: - Output Directory

private extension AndroidImagesExporter {
    /// Resolves the main res path from entry override or platform config fallback,
    /// and cleans the output directory when no filter is active.
    func resolveAndCleanOutput(
        entry: AndroidImagesEntry,
        platformConfig: AndroidPlatformConfig,
        context: some ImagesExportContext
    ) -> URL {
        let resolvedMainRes = entry.resolvedMainRes(fallback: platformConfig.mainRes)
        if context.filter == nil {
            let outputDir = resolvedMainRes.appendingPathComponent(entry.output)
            try? FileManager.default.removeItem(atPath: outputDir.path)
        }
        return resolvedMainRes
    }
}

// MARK: - Load & Process

private extension AndroidImagesExporter {
    func loadAndProcessSVG(
        entry: AndroidImagesEntry,
        context: some ImagesExportContext
    ) async throws -> ([AssetPair<ImagePack>], (light: URL, dark: URL)) {
        let images = try await context.withSpinner("Fetching images from Figma (\(entry.output))...") {
            let input = ImagesSourceInput(
                figmaFileId: entry.figmaFileId,
                frameName: entry.figmaFrameName ?? "Images",
                pageName: entry.figmaPageName,
                sourceFormat: .svg,
                scales: [1.0],
                useSingleFile: true,
                darkModeSuffix: "_dark",
                rtlProperty: entry.rtlProperty,
                rtlActiveValues: entry.rtlActiveValues,
                nameValidateRegexp: entry.nameValidateRegexp,
                nameReplaceRegexp: entry.nameReplaceRegexp
            )
            return try await context.loadImages(from: input)
        }

        let processResult = try await context.withSpinner("Processing images for Android...") {
            try context.processImages(
                images,
                platform: .android,
                nameValidateRegexp: entry.nameValidateRegexp,
                nameReplaceRegexp: entry.nameReplaceRegexp,
                nameStyle: entry.effectiveNameStyle
            )
        }

        if let warning = processResult.warning { context.warning(warning) }

        let tempLight = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let tempDark = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (processResult.imagePairs, (light: tempLight, dark: tempDark))
    }

    func loadAndProcessPNG(
        entry: AndroidImagesEntry,
        context: some ImagesExportContext
    ) async throws -> ([AssetPair<ImagePack>], URL) {
        let images = try await context.withSpinner("Fetching images from Figma (\(entry.output))...") {
            try await context.loadImages(from: entry.imagesSourceInput())
        }

        let processResult = try await context.withSpinner("Processing images for Android...") {
            try context.processImages(
                images,
                platform: .android,
                nameValidateRegexp: entry.nameValidateRegexp,
                nameReplaceRegexp: entry.nameReplaceRegexp,
                nameStyle: entry.effectiveNameStyle
            )
        }

        if let warning = processResult.warning { context.warning(warning) }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (processResult.imagePairs, tempDir)
    }

    func outputDirectories(
        entry: AndroidImagesEntry,
        platformConfig: AndroidPlatformConfig
    ) -> (light: URL, dark: URL) {
        let resolvedMainRes = entry.resolvedMainRes(fallback: platformConfig.mainRes)
        let lightDir = resolvedMainRes
            .appendingPathComponent(entry.output)
            .appendingPathComponent("drawable", isDirectory: true)
        let darkDir = resolvedMainRes
            .appendingPathComponent(entry.output)
            .appendingPathComponent("drawable-night", isDirectory: true)
        return (lightDir, darkDir)
    }
}

// MARK: - Static Helpers

private enum AndroidImagesHelpers {
    static func makeSVGRemoteFiles(
        imagePairs: [AssetPair<ImagePack>],
        lightDir: URL,
        darkDir: URL
    ) -> [FileContents] {
        var files: [FileContents] = []

        for pair in imagePairs {
            for image in pair.light.images {
                let fileURL = URL(fileURLWithPath: "\(image.name).svg")
                files.append(FileContents(
                    destination: Destination(directory: lightDir, file: fileURL),
                    sourceURL: image.url
                ))
            }

            if let dark = pair.dark {
                for image in dark.images {
                    let fileURL = URL(fileURLWithPath: "\(image.name).svg")
                    files.append(FileContents(
                        destination: Destination(directory: darkDir, file: fileURL),
                        sourceURL: image.url,
                        dark: true
                    ))
                }
            }
        }

        return files
    }

    static func makeRasterRemoteFiles(
        imagePairs: [AssetPair<ImagePack>],
        outputDirectory: URL
    ) throws -> [FileContents] {
        var files: [FileContents] = []

        for pair in imagePairs {
            try files.append(contentsOf: makeRemoteFiles(
                images: pair.light.images, dark: false, outputDirectory: outputDirectory
            ))

            if let dark = pair.dark {
                try files.append(contentsOf: makeRemoteFiles(
                    images: dark.images, dark: true, outputDirectory: outputDirectory
                ))
            }
        }

        return files
    }

    static func makeRemoteFiles(
        images: [Image],
        dark: Bool,
        outputDirectory: URL
    ) throws -> [FileContents] {
        try images.map { image -> FileContents in
            guard let name = image.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let fileURL = URL(string: "\(name).\(image.format)")
            else {
                throw AndroidImagesExporterError.invalidFileName(image.name)
            }
            let scale = image.scale.value
            let dest = Destination(
                directory: outputDirectory
                    .appendingPathComponent(dark ? "dark" : "light")
                    .appendingPathComponent(String(scale)),
                file: fileURL
            )
            return FileContents(destination: dest, sourceURL: image.url, scale: scale, dark: dark)
        }
    }
}

// MARK: - Error

public enum AndroidImagesExporterError: LocalizedError {
    case invalidFileName(String)
    case incompatibleFormat(source: String, output: String)

    public var errorDescription: String? {
        switch self {
        case let .invalidFileName(name):
            "Invalid file name: \(name)"
        case let .incompatibleFormat(source, output):
            "Cannot convert \(source) source to \(output) output"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidFileName:
            nil
        case .incompatibleFormat:
            "Use SVG source format for vector output, or change the output format to PNG or WebP"
        }
    }
}

// swiftlint:enable file_length
