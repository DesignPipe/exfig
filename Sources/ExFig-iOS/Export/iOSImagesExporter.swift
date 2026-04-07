// swiftlint:disable type_name file_length type_body_length function_body_length

import ExFigCore
import Foundation
import XcodeExport

/// Exports images from Figma frames to iOS xcassets (PNG/HEIC) and Swift extensions.
///
/// Supports multiple workflows:
/// - PNG source → PNG/HEIC output
/// - SVG source → PNG/HEIC output (rasterization)
///
/// ## Granular Cache Support
///
/// When the context conforms to `ImagesExportContextWithGranularCache` and
/// granular cache is enabled, the exporter will:
/// - Only export changed images (based on content hash)
/// - Return computed hashes for cache update
/// - Still generate templates with all image names
public struct iOSImagesExporter: ImagesExporter {
    public typealias Entry = iOSImagesEntry
    public typealias PlatformConfig = iOSPlatformConfig

    public init() {}

    public func exportImages(
        entries: [iOSImagesEntry],
        platformConfig: iOSPlatformConfig,
        context: some ImagesExportContext
    ) async throws -> ImagesExportResult {
        let results = try await parallelMapEntries(entries) { entry in
            try await exportSingleEntry(
                entry: entry,
                platformConfig: platformConfig,
                context: context
            )
        }

        let merged = ImagesExportResult.merge(results)

        if !context.isBatchMode {
            context.success("Done! Exported \(merged.count) images to Xcode project.")
        }

        return merged
    }

    // MARK: - Private

    // swiftlint:disable:next cyclomatic_complexity
    private func exportSingleEntry(
        entry: iOSImagesEntry,
        platformConfig: iOSPlatformConfig,
        context: some ImagesExportContext
    ) async throws -> ImagesExportResult {
        // Check if context supports granular cache
        let granularCacheContext = context as? (any ImagesExportContextWithGranularCache)
        let useGranularCache = granularCacheContext?.isGranularCacheEnabled ?? false

        let sourceFormat = entry.sourceFormat.flatMap { ImageSourceFormat(rawValue: $0.rawValue) } ?? .png
        let outputFormat = entry.effectiveOutputFormat

        switch (sourceFormat, outputFormat) {
        case (.svg, _):
            return try await exportSVGSource(
                entry: entry, platformConfig: platformConfig, context: context,
                outputFormat: outputFormat, useGranularCache: useGranularCache
            )
        case (.png, .heic):
            return try await exportPNGSourceHeic(
                entry: entry, platformConfig: platformConfig, context: context,
                useGranularCache: useGranularCache
            )
        case (.png, _):
            return try await exportPNGSourceRaster(
                entry: entry, platformConfig: platformConfig, context: context,
                useGranularCache: useGranularCache
            )
        }
    }

    private func exportPNGSourceRaster(
        entry: iOSImagesEntry,
        platformConfig: iOSPlatformConfig,
        context: some ImagesExportContext,
        useGranularCache: Bool
    ) async throws -> ImagesExportResult {
        let (imagePairs, assetsURL, loadResult) = try await loadAndProcess(
            entry: entry, platformConfig: platformConfig, context: context, useGranularCache: useGranularCache
        )

        // If all images unchanged, skip export but return metadata
        if loadResult.allSkipped {
            context.success("All images unchanged (granular cache). Skipping export.")
            return ImagesExportResult(
                count: 0,
                skippedCount: loadResult.allAssetMetadata.count,
                computedHashes: loadResult.computedHashes,
                allAssetMetadata: loadResult.allAssetMetadata
            )
        }

        // For granular cache: process all image names for templates
        let allImageNames: [String]?
        let allAssetMetadata: [AssetMetadata]?
        if useGranularCache, let gcContext = context as? (any ImagesExportContextWithGranularCache) {
            allImageNames = gcContext.processImageNames(
                loadResult.allAssetMetadata.map(\.name),
                nameValidateRegexp: entry.nameValidateRegexp,
                nameReplaceRegexp: entry.nameReplaceRegexp,
                nameStyle: entry.coreNameStyle
            )
            allAssetMetadata = loadResult.allAssetMetadata.map { meta in
                AssetMetadata(
                    name: gcContext.processImageNames(
                        [meta.name],
                        nameValidateRegexp: entry.nameValidateRegexp,
                        nameReplaceRegexp: entry.nameReplaceRegexp,
                        nameStyle: entry.coreNameStyle
                    ).first ?? meta.name,
                    nodeId: meta.nodeId,
                    fileId: meta.fileId
                )
            }
        } else {
            allImageNames = nil
            allAssetMetadata = nil
        }

        let output = entry.makeXcodeImagesOutput(platformConfig: platformConfig, assetsURL: assetsURL)
        let exporter = XcodeImagesExporter(output: output)
        let localAndRemoteFiles = try exporter.export(
            assets: imagePairs, allAssetNames: allImageNames, allAssetMetadata: allAssetMetadata,
            append: context.filter != nil
        )

        if context.filter == nil, !useGranularCache {
            try? FileManager.default.removeItem(atPath: assetsURL.path)
        }

        let localFiles = try await context.downloadFiles(localAndRemoteFiles, progressTitle: "Downloading images")

        try await context.withSpinner("Writing files to Xcode project...") {
            try context.writeFiles(localFiles)
        }

        let skippedCount = useGranularCache
            ? loadResult.allAssetMetadata.count - imagePairs.count
            : 0

        return ImagesExportResult(
            count: imagePairs.count,
            skippedCount: skippedCount,
            computedHashes: loadResult.computedHashes,
            allAssetMetadata: loadResult.allAssetMetadata
        )
    }

    private func exportPNGSourceHeic(
        entry: iOSImagesEntry,
        platformConfig: iOSPlatformConfig,
        context: some ImagesExportContext,
        useGranularCache: Bool
    ) async throws -> ImagesExportResult {
        let (imagePairs, assetsURL, loadResult) = try await loadAndProcess(
            entry: entry, platformConfig: platformConfig, context: context, useGranularCache: useGranularCache
        )

        // If all images unchanged, skip export but return metadata
        if loadResult.allSkipped {
            context.success("All images unchanged (granular cache). Skipping export.")
            return ImagesExportResult(
                count: 0,
                skippedCount: loadResult.allAssetMetadata.count,
                computedHashes: loadResult.computedHashes,
                allAssetMetadata: loadResult.allAssetMetadata
            )
        }

        // For granular cache: process all image names for templates
        let allImageNames: [String]?
        let allAssetMetadata: [AssetMetadata]?
        if useGranularCache, let gcContext = context as? (any ImagesExportContextWithGranularCache) {
            allImageNames = gcContext.processImageNames(
                loadResult.allAssetMetadata.map(\.name),
                nameValidateRegexp: entry.nameValidateRegexp,
                nameReplaceRegexp: entry.nameReplaceRegexp,
                nameStyle: entry.coreNameStyle
            )
            allAssetMetadata = loadResult.allAssetMetadata.map { meta in
                AssetMetadata(
                    name: gcContext.processImageNames(
                        [meta.name],
                        nameValidateRegexp: entry.nameValidateRegexp,
                        nameReplaceRegexp: entry.nameReplaceRegexp,
                        nameStyle: entry.coreNameStyle
                    ).first ?? meta.name,
                    nodeId: meta.nodeId,
                    fileId: meta.fileId
                )
            }
        } else {
            allImageNames = nil
            allAssetMetadata = nil
        }

        let output = entry.makeXcodeImagesOutput(platformConfig: platformConfig, assetsURL: assetsURL)
        let exporter = XcodeImagesExporter(output: output)
        let localAndRemoteFiles = try exporter.exportForHeic(
            assets: imagePairs, allAssetNames: allImageNames, allAssetMetadata: allAssetMetadata,
            append: context.filter != nil
        )

        if context.filter == nil, !useGranularCache {
            try? FileManager.default.removeItem(atPath: assetsURL.path)
        }

        var localFiles = try await context.downloadFiles(localAndRemoteFiles, progressTitle: "Downloading images")

        let pngFiles = localFiles.filter { $0.destination.file.pathExtension == "png" }
        if !pngFiles.isEmpty {
            localFiles = try await context.convertFormat(
                localFiles, to: .heic,
                heicOptions: entry.heicConverterOptions, webpOptions: nil,
                progressTitle: "Converting to HEIC"
            )
        }

        let filesToWrite = localFiles.filter { $0.destination.file.pathExtension != "heic" }
        try await context.withSpinner("Writing files to Xcode project...") {
            try context.writeFiles(filesToWrite)
        }

        let skippedCount = useGranularCache
            ? loadResult.allAssetMetadata.count - imagePairs.count
            : 0

        return ImagesExportResult(
            count: imagePairs.count,
            skippedCount: skippedCount,
            computedHashes: loadResult.computedHashes,
            allAssetMetadata: loadResult.allAssetMetadata
        )
    }

    private func exportSVGSource(
        entry: iOSImagesEntry,
        platformConfig: iOSPlatformConfig,
        context: some ImagesExportContext,
        outputFormat: ImageOutputFormat,
        useGranularCache: Bool
    ) async throws -> ImagesExportResult {
        let (imagePairs, assetsURL, loadResult) = try await loadAndProcessSVG(
            entry: entry, platformConfig: platformConfig, context: context, useGranularCache: useGranularCache
        )

        // If all images unchanged, skip export but return metadata
        if loadResult.allSkipped {
            context.success("All images unchanged (granular cache). Skipping export.")
            return ImagesExportResult(
                count: 0,
                skippedCount: loadResult.allAssetMetadata.count,
                computedHashes: loadResult.computedHashes,
                allAssetMetadata: loadResult.allAssetMetadata
            )
        }

        // For granular cache: process all image names for templates
        let allImageNames: [String]?
        let allAssetMetadata: [AssetMetadata]?
        if useGranularCache, let gcContext = context as? (any ImagesExportContextWithGranularCache) {
            allImageNames = gcContext.processImageNames(
                loadResult.allAssetMetadata.map(\.name),
                nameValidateRegexp: entry.nameValidateRegexp,
                nameReplaceRegexp: entry.nameReplaceRegexp,
                nameStyle: entry.coreNameStyle
            )
            allAssetMetadata = loadResult.allAssetMetadata.map { meta in
                AssetMetadata(
                    name: gcContext.processImageNames(
                        [meta.name],
                        nameValidateRegexp: entry.nameValidateRegexp,
                        nameReplaceRegexp: entry.nameReplaceRegexp,
                        nameStyle: entry.coreNameStyle
                    ).first ?? meta.name,
                    nodeId: meta.nodeId,
                    fileId: meta.fileId
                )
            }
        } else {
            allImageNames = nil
            allAssetMetadata = nil
        }

        let svgRemoteFiles = iOSImagesExporterHelpers.makeSVGRemoteFiles(imagePairs: imagePairs, assetsURL: assetsURL)
        let downloadedSVGs = try await context.downloadFiles(svgRemoteFiles, progressTitle: "Downloading SVGs")

        if context.filter == nil, !useGranularCache {
            try? FileManager.default.removeItem(atPath: assetsURL.path)
        }

        let scales = entry.effectiveScales
        let rasterFiles = try await context.rasterizeSVGs(
            downloadedSVGs, scales: scales, to: outputFormat,
            heicOptions: outputFormat == .heic ? entry.heicConverterOptions : nil,
            progressTitle: "Rasterizing SVGs to \(outputFormat.rawValue.uppercased())"
        )

        let output = entry.makeXcodeImagesOutput(platformConfig: platformConfig, assetsURL: assetsURL)
        let exporter = XcodeImagesExporter(output: output)
        let extensionFiles = try exporter.exportSwiftExtensions(
            assets: imagePairs, allAssetNames: allImageNames, allAssetMetadata: allAssetMetadata,
            append: context.filter != nil
        )

        let contentsJsonFiles = try iOSImagesExporterHelpers.makeImagesetContentsJson(
            imagePairs: imagePairs, scales: scales, assetsURL: assetsURL,
            renderMode: entry.coreRenderMode, fileExtension: outputFormat.rawValue
        )

        let folderContentsFile = iOSImagesExporterHelpers.makeFolderContentsJson(assetsURL: assetsURL)

        let filesToWrite = rasterFiles + contentsJsonFiles + extensionFiles + [folderContentsFile]
        try await context.withSpinner("Writing files to Xcode project...") {
            try context.writeFiles(filesToWrite)
        }

        let skippedCount = useGranularCache
            ? loadResult.allAssetMetadata.count - imagePairs.count
            : 0

        return ImagesExportResult(
            count: imagePairs.count,
            skippedCount: skippedCount,
            computedHashes: loadResult.computedHashes,
            allAssetMetadata: loadResult.allAssetMetadata
        )
    }

    private func loadAndProcess(
        entry: iOSImagesEntry,
        platformConfig: iOSPlatformConfig,
        context: some ImagesExportContext,
        useGranularCache: Bool
    ) async throws -> ([AssetPair<ImagePack>], URL, ImagesLoadOutputWithHashes) {
        let loadResult: ImagesLoadOutputWithHashes
        if useGranularCache, let gcContext = context as? (any ImagesExportContextWithGranularCache) {
            loadResult = try await gcContext.withSpinner("Fetching images from Figma (\(entry.assetsFolder))...") {
                try await gcContext.loadImagesWithGranularCache(
                    from: entry.imagesSourceInput(),
                    onProgress: nil
                )
            }
        } else {
            let images = try await context.withSpinner("Fetching images from Figma (\(entry.assetsFolder))...") {
                try await context.loadImages(from: entry.imagesSourceInput())
            }
            loadResult = ImagesLoadOutputWithHashes(light: images.light, dark: images.dark)
        }

        let processResult = try await context.withSpinner("Processing images for iOS...") {
            try context.processImages(
                loadResult.asLoadOutput, platform: .ios,
                nameValidateRegexp: entry.nameValidateRegexp,
                nameReplaceRegexp: entry.nameReplaceRegexp,
                nameStyle: entry.coreNameStyle
            )
        }

        if let warning = processResult.warning { context.warning(warning) }

        guard let xcassetsPath = entry.resolvedXcassetsPath(fallback: platformConfig.xcassetsPath) else {
            throw iOSImagesExportError.xcassetsPathNotSpecified
        }
        let assetsURL = xcassetsPath.appendingPathComponent(entry.assetsFolder)
        return (processResult.imagePairs, assetsURL, loadResult)
    }

    private func loadAndProcessSVG(
        entry: iOSImagesEntry,
        platformConfig: iOSPlatformConfig,
        context: some ImagesExportContext,
        useGranularCache: Bool
    ) async throws -> ([AssetPair<ImagePack>], URL, ImagesLoadOutputWithHashes) {
        let loadResult: ImagesLoadOutputWithHashes
        if useGranularCache, let gcContext = context as? (any ImagesExportContextWithGranularCache) {
            loadResult = try await gcContext.withSpinner("Fetching SVG images from Figma (\(entry.assetsFolder))...") {
                try await gcContext.loadImagesWithGranularCache(
                    from: entry.svgSourceInput(),
                    onProgress: nil
                )
            }
        } else {
            let images = try await context.withSpinner("Fetching SVG images from Figma (\(entry.assetsFolder))...") {
                let input = entry.svgSourceInput()
                return try await context.loadImages(from: input)
            }
            loadResult = ImagesLoadOutputWithHashes(light: images.light, dark: images.dark)
        }

        let processResult = try await context.withSpinner("Processing images for iOS...") {
            try context.processImages(
                loadResult.asLoadOutput, platform: .ios,
                nameValidateRegexp: entry.nameValidateRegexp,
                nameReplaceRegexp: entry.nameReplaceRegexp,
                nameStyle: entry.coreNameStyle
            )
        }

        if let warning = processResult.warning { context.warning(warning) }

        guard let xcassetsPath = entry.resolvedXcassetsPath(fallback: platformConfig.xcassetsPath) else {
            throw iOSImagesExportError.xcassetsPathNotSpecified
        }
        let assetsURL = xcassetsPath.appendingPathComponent(entry.assetsFolder)
        return (processResult.imagePairs, assetsURL, loadResult)
    }
}

// MARK: - Errors

/// Errors that can occur during iOS images export.
public enum iOSImagesExportError: LocalizedError {
    /// xcassetsPath not specified when exporting images.
    case xcassetsPathNotSpecified

    /// Failed to serialize Contents.json for an imageset.
    case contentsJsonSerializationFailed(imageset: String, underlyingError: Error)

    public var errorDescription: String? {
        switch self {
        case .xcassetsPathNotSpecified:
            "xcassetsPath is required for iOS images export"
        case let .contentsJsonSerializationFailed(imageset, error):
            "Failed to create Contents.json for \(imageset): \(error.localizedDescription)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .xcassetsPathNotSpecified:
            "Add 'xcassetsPath' to your iOS configuration"
        case .contentsJsonSerializationFailed:
            "Check that the image data is valid and try again"
        }
    }
}

// MARK: - Entry Helpers

private extension iOSImagesEntry {
    func makeXcodeImagesOutput(platformConfig: iOSPlatformConfig, assetsURL: URL) -> XcodeImagesOutput {
        XcodeImagesOutput(
            assetsFolderURL: assetsURL,
            assetsInMainBundle: platformConfig.xcassetsInMainBundle,
            assetsInSwiftPackage: platformConfig.xcassetsInSwiftPackage,
            resourceBundleNames: platformConfig.resourceBundleNames,
            addObjcAttribute: platformConfig.addObjcAttribute,
            uiKitImageExtensionURL: imageSwiftURL,
            swiftUIImageExtensionURL: swiftUIImageSwiftURL,
            codeConnectSwiftURL: codeConnectSwiftURL,
            templatesPath: resolvedTemplatesPath(fallback: platformConfig.templatesPath),
            renderMode: coreRenderMode
        )
    }

    func svgSourceInput() -> ImagesSourceInput {
        ImagesSourceInput(
            figmaFileId: figmaFileId,
            darkFileId: nil,
            frameName: figmaFrameName ?? "Images",
            pageName: figmaPageName,
            sourceFormat: .svg,
            scales: [1.0],
            useSingleFile: true,
            darkModeSuffix: "_dark",
            rtlProperty: rtlProperty,
            rtlActiveValues: rtlActiveValues,
            nameValidateRegexp: nameValidateRegexp,
            nameReplaceRegexp: nameReplaceRegexp
        )
    }
}

// MARK: - Static Helpers

private enum iOSImagesExporterHelpers {
    static func makeSVGRemoteFiles(imagePairs: [AssetPair<ImagePack>], assetsURL: URL) -> [FileContents] {
        var files: [FileContents] = []

        for pair in imagePairs {
            if let image = pair.light.images.first {
                let imagesetDir = assetsURL.appendingPathComponent("\(pair.light.name).imageset")
                files.append(FileContents(
                    destination: Destination(
                        directory: imagesetDir,
                        file: URL(fileURLWithPath: "\(pair.light.name).svg")
                    ),
                    sourceURL: image.url
                ))
            }

            if let dark = pair.dark, let image = dark.images.first {
                let imagesetDir = assetsURL.appendingPathComponent("\(pair.light.name).imageset")
                files.append(FileContents(
                    destination: Destination(
                        directory: imagesetDir,
                        file: URL(fileURLWithPath: "\(pair.light.name)D.svg")
                    ),
                    sourceURL: image.url, dark: true
                ))
            }
        }

        return files
    }

    static func makeImagesetContentsJson(
        imagePairs: [AssetPair<ImagePack>],
        scales: [Double],
        assetsURL: URL,
        renderMode: XcodeRenderMode?,
        fileExtension: String
    ) throws -> [FileContents] {
        try imagePairs.map { pair -> FileContents in
            let imagesetDir = assetsURL.appendingPathComponent("\(pair.light.name).imageset")
            var imagesArray: [[String: Any]] = []

            for scale in scales {
                let scaleSuffix = scale == 1.0 ? "" : "@\(Int(scale))x"
                let scaleString = scale == 1.0 ? "1x" : "\(Int(scale))x"
                imagesArray.append([
                    "filename": "\(pair.light.name)\(scaleSuffix).\(fileExtension)",
                    "idiom": "universal", "scale": scaleString,
                ])
            }

            if pair.dark != nil {
                for scale in scales {
                    let scaleSuffix = scale == 1.0 ? "" : "@\(Int(scale))x"
                    let scaleString = scale == 1.0 ? "1x" : "\(Int(scale))x"
                    imagesArray.append([
                        "appearances": [["appearance": "luminosity", "value": "dark"]],
                        "filename": "\(pair.light.name)D\(scaleSuffix).\(fileExtension)",
                        "idiom": "universal", "scale": scaleString,
                    ])
                }
            }

            var contentsJson: [String: Any] = [
                "images": imagesArray,
                "info": ["author": "xcode", "version": 1],
            ]

            if let renderMode, renderMode == .original || renderMode == .template {
                contentsJson["properties"] = ["template-rendering-intent": renderMode.rawValue]
            }

            let jsonData: Data
            do {
                jsonData = try JSONSerialization.data(
                    withJSONObject: contentsJson, options: [.prettyPrinted, .sortedKeys]
                )
            } catch {
                throw iOSImagesExportError.contentsJsonSerializationFailed(
                    imageset: imagesetDir.lastPathComponent, underlyingError: error
                )
            }

            return FileContents(
                destination: Destination(directory: imagesetDir, file: URL(fileURLWithPath: "Contents.json")),
                data: jsonData
            )
        }
    }

    static func makeFolderContentsJson(assetsURL: URL) -> FileContents {
        FileContents(
            destination: Destination(directory: assetsURL, file: URL(fileURLWithPath: "Contents.json")),
            data: Data(#"{"info":{"author":"xcode","version":1}}"#.utf8)
        )
    }
}

// swiftlint:enable type_name file_length
