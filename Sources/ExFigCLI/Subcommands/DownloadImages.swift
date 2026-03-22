// swiftlint:disable file_length
import ArgumentParser
import ExFigCore
import FigmaAPI
import Foundation
import Logging
import PenpotAPI

extension ExFigCommand {
    // swiftlint:disable type_body_length
    struct FetchImages: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "fetch",
            abstract: "Downloads images from Figma or Penpot without config file",
            discussion: """
            Downloads images from a specific frame to a local directory.
            All parameters are passed via command-line arguments.

            When required options (--file-id, --frame, --output) are omitted in an
            interactive terminal, a guided wizard helps you fill them in.

            Examples:
              # Interactive wizard (TTY only)
              exfig fetch

              # Download PNGs from Figma at 3x scale (default)
              exfig fetch -f abc123 -r "Illustrations" -o ./images

              # Download SVGs
              exfig fetch -f abc123 -r "Icons" -o ./icons --format svg

              # Download from Penpot
              exfig fetch --source penpot -f <penpot-uuid> -r "Icons" -o ./icons

              # Download from self-hosted Penpot
              exfig fetch --source penpot --penpot-base-url https://penpot.mycompany.com/ \\
                -f <uuid> -r "UI" -o ./components

              # Download with filtering
              exfig fetch -f abc123 -r "Images" -o ./images --filter "logo/*"

              # Download as WebP with quality settings
              exfig fetch -f abc123 -r "Images" -o ./images --format webp --webp-quality 90
            """
        )

        @OptionGroup
        var globalOptions: GlobalOptions

        @OptionGroup
        var downloadOptions: DownloadOptions

        @Option(name: .long, help: "Maximum retry attempts for failed API requests")
        var maxRetries: Int = 4

        @Option(name: .long, help: "Maximum API requests per minute")
        var rateLimit: Int = 10

        @Flag(name: .long, help: "Stop on first error without retrying")
        var failFast: Bool = false

        @Flag(name: .long, help: "Continue from checkpoint after interruption")
        var resume: Bool = false

        @Option(name: .long, help: "Maximum concurrent CDN downloads")
        var concurrentDownloads: Int = FileDownloader.defaultMaxConcurrentDownloads

        /// Constructs `HeavyFaultToleranceOptions` from locally declared options,
        /// using `DownloadOptions.timeout` to avoid duplicate `--timeout` flags.
        var faultToleranceOptions: HeavyFaultToleranceOptions {
            var opts = HeavyFaultToleranceOptions()
            opts.maxRetries = maxRetries
            opts.rateLimit = rateLimit
            opts.timeout = downloadOptions.timeout
            opts.failFast = failFast
            opts.resume = resume
            opts.concurrentDownloads = concurrentDownloads
            return opts
        }

        // swiftlint:disable function_body_length cyclomatic_complexity

        func run() async throws {
            // Initialize terminal UI
            ExFigCommand.initializeTerminalUI(verbose: globalOptions.verbose, quiet: globalOptions.quiet)
            let ui = ExFigCommand.terminalUI!

            // Resolve required options via wizard if missing
            var options = downloadOptions
            var wizardResult: FetchWizardResult?
            if options.fileId == nil || options.frameName == nil || options.outputPath == nil {
                guard TTYDetector.isTTY else {
                    throw ValidationError(
                        "Missing required options: --file-id, --frame, --output. " +
                            "Run in interactive terminal for guided setup."
                    )
                }
                let result = FetchWizard.run()
                wizardResult = result
                options.fileId = options.fileId ?? result.fileId
                options.frameName = options.frameName ?? result.frameName
                options.outputPath = options.outputPath ?? result.outputPath
                options.pageName = options.pageName ?? result.pageName
                options.filter = options.filter ?? result.filter
                if options.format == nil {
                    options.format = result.format
                }
                if options.nameStyle == nil {
                    options.nameStyle = result.nameStyle
                }
                if options.scale == nil {
                    options.scale = result.scale
                }
            }

            // Determine design source: from wizard, from --source flag, or default figma
            let designSource: WizardDesignSource = wizardResult?.designSource
                ?? options.source.map { $0 == .penpot ? .penpot : .figma }
                ?? .figma

            // Penpot path — use PenpotAPI directly
            if designSource == .penpot {
                let penpotBaseURL = wizardResult?.penpotBaseURL ?? options.penpotBaseURL
                try await runPenpotFetch(options: options, penpotBaseURL: penpotBaseURL, ui: ui)
                return
            }

            // Validate required fields are now populated
            guard let fileId = options.fileId else {
                throw ValidationError("--file-id is required")
            }
            guard let frameName = options.frameName else {
                throw ValidationError("--frame is required")
            }
            guard let outputPath = options.outputPath else {
                throw ValidationError("--output is required")
            }

            // Validate access token
            guard let accessToken = options.accessToken else {
                throw ExFigError.accessTokenNotFound
            }

            // Create output directory if needed
            let outputURL = URL(fileURLWithPath: outputPath, isDirectory: true)
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

            ui.info("Downloading images from Figma...")
            ui.debug("File ID: \(fileId)")
            ui.debug("Frame: \(frameName)")
            ui.debug("Output: \(outputURL.path)")
            ui.debug("Format: \(options.effectiveFormat.rawValue)")
            if !options.isVectorFormat {
                ui.debug("Scale: \(options.effectiveScale)x")
            }

            // Create Figma client with fault tolerance
            let baseClient = FigmaClient(accessToken: accessToken, timeout: TimeInterval(options.timeout))
            let rateLimiter = faultToleranceOptions.createRateLimiter()
            let maxRetries = faultToleranceOptions.maxRetries
            let client = faultToleranceOptions.createRateLimitedClient(
                wrapping: baseClient,
                rateLimiter: rateLimiter,
                onRetry: { attempt, error in
                    let warning = ExFigWarning.retrying(
                        attempt: attempt,
                        maxAttempts: maxRetries,
                        error: error.localizedDescription,
                        delay: "..."
                    )
                    ui.warning(warning)
                }
            )

            // Create loader
            let loader = DownloadImageLoader(
                client: client,
                logger: ExFigCommand.logger
            )

            // Snapshot options for use in @Sendable closures
            let resolvedOptions = options

            // Load images from Figma
            let imagePacks = try await ui.withSpinnerProgress("Fetching images from Figma...") { onProgress in
                try await loadImages(
                    using: loader,
                    fileId: fileId,
                    frameName: frameName,
                    pageName: resolvedOptions.pageName,
                    format: resolvedOptions.effectiveFormat,
                    effectiveScale: resolvedOptions.effectiveScale,
                    filter: resolvedOptions.filter,
                    onBatchProgress: onProgress
                )
            }

            guard !imagePacks.isEmpty else {
                ui.warning(.noAssetsFound(
                    assetType: "images",
                    frameName: frameName,
                    pageName: resolvedOptions.pageName
                ))
                return
            }

            ui.info("Found \(imagePacks.count) images")

            // Process names using extracted processor
            let processedPacks = DownloadImageProcessor.processNames(
                imagePacks,
                validateRegexp: resolvedOptions.nameValidateRegexp,
                replaceRegexp: resolvedOptions.nameReplaceRegexp,
                nameStyle: resolvedOptions.nameStyle
            )

            // Handle dark mode if suffix is specified
            let (lightPacks, darkPacks) = DownloadImageProcessor.splitByDarkMode(
                processedPacks,
                darkSuffix: resolvedOptions.darkModeSuffix
            )

            // Create file contents for download
            var allFiles = DownloadImageProcessor.createFileContents(
                from: lightPacks,
                outputURL: outputURL,
                format: resolvedOptions.effectiveFormat,
                dark: false,
                darkModeSuffix: resolvedOptions.darkModeSuffix
            )
            if let darkPacks {
                allFiles += DownloadImageProcessor.createFileContents(
                    from: darkPacks,
                    outputURL: outputURL,
                    format: resolvedOptions.effectiveFormat,
                    dark: true,
                    darkModeSuffix: resolvedOptions.darkModeSuffix
                )
            }
            let filesToDownload = allFiles

            // Download files with progress
            ui.info("Downloading \(filesToDownload.count) files...")
            let fileDownloader = faultToleranceOptions.createFileDownloader()
            let downloadedFiles = try await ui.withProgress(
                "Downloading",
                total: filesToDownload.count
            ) { progress in
                try await fileDownloader.fetch(files: filesToDownload) { current, _ in
                    progress.update(current: current)
                }
            }

            // Convert to WebP if needed
            let finalFiles: [FileContents] = if resolvedOptions.effectiveFormat == .webp {
                try await convertToWebP(downloadedFiles, options: resolvedOptions, ui: ui)
            } else {
                downloadedFiles
            }

            // Write files to disk
            try await ui.withSpinner("Writing files...") {
                try await ExFigCommand.fileWriter.writeParallel(files: finalFiles)
            }

            ui.success("Downloaded \(finalFiles.count) images to \(outputURL.path)")
        }

        // swiftlint:enable function_body_length cyclomatic_complexity

        // MARK: - Private Methods

        // swiftlint:disable function_parameter_count

        private func loadImages(
            using loader: DownloadImageLoader,
            fileId: String,
            frameName: String,
            pageName: String?,
            format: ImageFormat,
            effectiveScale: Double,
            filter: String?,
            onBatchProgress: @escaping BatchProgressCallback = { _, _ in }
        ) async throws -> [ImagePack] {
            let isVector = format == .svg || format == .pdf
            if isVector {
                let params: FormatParams = format == .svg ? SVGParams() : PDFParams()
                return try await loader.loadVectorImages(
                    fileId: fileId,
                    frameName: frameName,
                    pageName: pageName,
                    params: params,
                    filter: filter,
                    onBatchProgress: onBatchProgress
                )
            } else {
                return try await loader.loadRasterImages(
                    fileId: fileId,
                    frameName: frameName,
                    pageName: pageName,
                    scale: effectiveScale,
                    format: format.rawValue,
                    filter: filter,
                    onBatchProgress: onBatchProgress
                )
            }
        }

        // swiftlint:enable function_parameter_count

        // MARK: - Penpot Fetch

        // swiftlint:disable function_body_length cyclomatic_complexity
        private func runPenpotFetch(
            options: DownloadOptions,
            penpotBaseURL: String?,
            ui: TerminalUI
        ) async throws {
            guard let fileId = options.fileId else {
                throw ValidationError("--file-id is required")
            }
            guard let frameName = options.frameName else {
                throw ValidationError("--frame is required")
            }
            guard let outputPath = options.outputPath else {
                throw ValidationError("--output is required")
            }

            // Validate format early — Penpot supports svg and png (via SVG reconstruction)
            let format = options.format ?? .svg
            switch format {
            case .svg, .png:
                break // supported
            default:
                throw ExFigError.custom(
                    errorString: "Format '\(format.rawValue)' is not yet supported for Penpot export. " +
                        "Supported formats: svg, png"
                )
            }

            let baseURL = penpotBaseURL ?? BasePenpotClient.defaultBaseURL
            let client = try PenpotClientFactory.makeClient(baseURL: baseURL)

            let outputURL = URL(fileURLWithPath: outputPath, isDirectory: true)
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

            ui.info("Downloading components from Penpot...")

            // Fetch file data
            let fileResponse = try await ui.withSpinner("Fetching Penpot file...") {
                try await client.request(GetFileEndpoint(fileId: fileId))
            }

            guard let components = fileResponse.data.components else {
                ui.warning("No components found in Penpot file")
                return
            }

            // Filter by path prefix
            let matched = components.values
                .filter { comp in
                    guard let path = comp.path else { return false }
                    return path.hasPrefix(frameName)
                }
                .sorted { $0.name < $1.name }

            guard !matched.isEmpty else {
                ui.warning("No components matching path '\(frameName)' found")
                return
            }

            ui.info("Found \(matched.count) components")

            // Reconstruct SVG from shape tree (format already validated above)
            var exportedCount = 0

            for component in matched {
                guard let pageId = component.mainInstancePage,
                      let instanceId = component.mainInstanceId,
                      let page = fileResponse.data.pagesIndex?[pageId],
                      let objects = page.objects
                else {
                    ui.warning("Component '\(component.name)' has no shape data — skipping")
                    continue
                }

                let renderResult = PenpotShapeRenderer.renderSVGResult(
                    objects: objects, rootId: instanceId
                )
                let svgString: String
                switch renderResult {
                case let .success(result):
                    svgString = result.svg
                    if !result.skippedShapeTypes.isEmpty {
                        ui.warning(
                            "Component '\(component.name)' — unsupported shape types skipped: " +
                                result.skippedShapeTypes.sorted().joined(separator: ", ")
                        )
                    }
                case let .failure(reason):
                    switch reason {
                    case let .rootNotFound(id):
                        ui.warning("Component '\(component.name)' — root shape '\(id)' not found, skipping")
                    case let .missingSelrect(id):
                        ui.warning("Component '\(component.name)' — root shape '\(id)' has no bounds, skipping")
                    }
                    continue
                }

                let svgData = Data(svgString.utf8)
                let safeName = component.name
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: " ", with: "_")

                switch format {
                case .svg:
                    let fileURL = outputURL.appendingPathComponent("\(safeName).svg")
                    try svgData.write(to: fileURL)
                case .png:
                    let scale = options.scale ?? 3.0
                    let converter = SvgToPngConverter()
                    let pngData = try converter.convert(svgData: svgData, scale: scale, fileName: safeName)
                    let fileURL = outputURL.appendingPathComponent("\(safeName).png")
                    try pngData.write(to: fileURL)
                default:
                    // Unreachable — format validated at method start
                    fatalError("Unsupported format '\(format.rawValue)' should have been caught earlier")
                }

                exportedCount += 1
            }

            if exportedCount > 0 {
                ui
                    .success(
                        "Exported \(exportedCount) components as \(format.rawValue.uppercased()) to \(outputURL.path)"
                    )
            } else {
                ui.warning(
                    "No components could be exported. Components may lack mainInstanceId (not opened in Penpot editor)."
                )
            }
        }

        // swiftlint:enable function_body_length cyclomatic_complexity

        private func convertToWebP(
            _ files: [FileContents],
            options: DownloadOptions,
            ui: TerminalUI
        ) async throws -> [FileContents] {
            let encoding: WebpConverter.Encoding = switch options.webpEncoding {
            case .lossy:
                .lossy(quality: options.webpQuality)
            case .lossless:
                .lossless
            }

            let converter = WebpConverter(encoding: encoding)

            // Get list of downloaded PNG files to convert
            let pngFiles = files.compactMap(\.dataFile)

            guard !pngFiles.isEmpty else {
                return files
            }

            try await ui.withSpinner("Converting to WebP...") {
                try await converter.convertBatch(files: pngFiles)
            }

            // Update file contents with WebP extension
            return files.map { file in
                file.changingExtension(newExtension: "webp")
            }
        }
    }
}
