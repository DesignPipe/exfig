#if canImport(MCP)

    import ExFigConfig
    import ExFigCore
    import FigmaAPI
    import Foundation
    import MCP
    import YYJSON

    /// Dispatches MCP CallTool requests to ExFig logic.
    enum MCPToolHandlers {
        static func handle(params: CallTool.Parameters, state: MCPServerState) async -> CallTool.Result {
            do {
                switch params.name {
                case "exfig_validate":
                    return try await handleValidate(params: params)
                case "exfig_tokens_info":
                    return try await handleTokensInfo(params: params)
                case "exfig_inspect":
                    return try await handleInspect(params: params, state: state)
                case "exfig_export":
                    return try await handleExport(params: params)
                case "exfig_download":
                    return try await handleDownload(params: params, state: state)
                default:
                    return .init(
                        content: [.text(text: "Unknown tool: \(params.name)", annotations: nil, _meta: nil)],
                        isError: true
                    )
                }
            } catch let error as ExFigError {
                return errorResult(error)
            } catch let error as TokensFileError {
                return .init(
                    content: [.text(
                        text: "Token file error: \(error.errorDescription ?? "\(error)")",
                        annotations: nil,
                        _meta: nil
                    )],
                    isError: true
                )
            } catch {
                return .init(content: [.text(text: "Error: \(error)", annotations: nil, _meta: nil)], isError: true)
            }
        }

        // MARK: - Validate

        private static func handleValidate(params: CallTool.Parameters) async throws -> CallTool.Result {
            let configPath = try resolveConfigPath(from: params.arguments?["config_path"]?.stringValue)
            let configURL = URL(fileURLWithPath: configPath)

            let config = try await PKLEvaluator.evaluate(configPath: configURL)

            let platforms = buildPlatformSummary(config: config)
            let fileIDs = Array(config.getFileIds()).sorted()
            let darkModes = buildDarkModeSummary(config: config)

            let summary = ValidateSummary(
                configPath: configPath,
                valid: true,
                platforms: platforms.isEmpty ? nil : platforms,
                figmaFileIds: fileIDs.isEmpty ? nil : fileIDs,
                darkMode: darkModes.isEmpty ? nil : darkModes
            )

            return try .init(content: [.text(text: encodeJSON(summary), annotations: nil, _meta: nil)])
        }

        private static func buildPlatformSummary(config: PKLConfig) -> [String: EntrySummary] {
            var platforms: [String: EntrySummary] = [:]

            if let ios = config.ios {
                platforms["ios"] = EntrySummary(
                    colorsEntries: ios.colors?.count, iconsEntries: ios.icons?.count,
                    imagesEntries: ios.images?.count, typography: ios.typography != nil ? true : nil
                )
            }
            if let android = config.android {
                platforms["android"] = EntrySummary(
                    colorsEntries: android.colors?.count, iconsEntries: android.icons?.count,
                    imagesEntries: android.images?.count, typography: android.typography != nil ? true : nil
                )
            }
            if let flutter = config.flutter {
                platforms["flutter"] = EntrySummary(
                    colorsEntries: flutter.colors?.count, iconsEntries: flutter.icons?.count,
                    imagesEntries: flutter.images?.count
                )
            }
            if let web = config.web {
                platforms["web"] = EntrySummary(
                    colorsEntries: web.colors?.count, iconsEntries: web.icons?.count,
                    imagesEntries: web.images?.count
                )
            }

            return platforms
        }

        private static func buildDarkModeSummary(config: PKLConfig) -> [String] {
            var approaches: Set<String> = []

            if config.figma?.darkFileId != nil {
                approaches.insert("darkFileId")
            }

            if config.common?.icons?.suffixDarkMode != nil {
                approaches.insert("suffixDarkMode (icons)")
            }
            if config.common?.images?.suffixDarkMode != nil {
                approaches.insert("suffixDarkMode (images)")
            }

            func checkIconEntries(_ entries: [any Common_FrameSource]?) {
                guard let entries else { return }
                for entry in entries where entry.variablesDarkMode != nil {
                    approaches.insert("variablesDarkMode")
                    return
                }
            }

            checkIconEntries(config.ios?.icons)
            checkIconEntries(config.android?.icons)
            checkIconEntries(config.flutter?.icons)
            checkIconEntries(config.web?.icons)

            return approaches.sorted()
        }

        // MARK: - Tokens Info

        private static func handleTokensInfo(params: CallTool.Parameters) async throws -> CallTool.Result {
            guard let filePath = params.arguments?["file_path"]?.stringValue else {
                return .init(
                    content: [.text(text: "Missing required parameter: file_path", annotations: nil, _meta: nil)],
                    isError: true
                )
            }

            var source = try TokensFileSource.parse(fileAt: filePath)
            try source.resolveAliases()

            var countsByType: [String: Int]?
            let byType = source.tokenCountsByType()
            if !byType.isEmpty {
                var typeCounts: [String: Int] = [:]
                for entry in byType {
                    typeCounts[entry.type] = entry.count
                }
                countsByType = typeCounts
            }

            var topLevelGroups: [String: Int]?
            let groups = source.topLevelGroups()
            if !groups.isEmpty {
                var groupCounts: [String: Int] = [:]
                for entry in groups {
                    groupCounts[entry.name] = entry.count
                }
                topLevelGroups = groupCounts
            }

            let result = TokensInfoResult(
                filePath: filePath,
                totalTokens: source.tokens.count,
                aliasCount: source.aliasCount,
                countsByType: countsByType,
                topLevelGroups: topLevelGroups,
                warnings: source.warnings.isEmpty ? nil : source.warnings
            )

            return try .init(content: [.text(text: encodeJSON(result), annotations: nil, _meta: nil)])
        }

        // MARK: - Inspect

        private static func handleInspect(
            params: CallTool.Parameters,
            state: MCPServerState
        ) async throws -> CallTool.Result {
            // Validate inputs before expensive operations (PKL eval, API client)
            guard let resourceType = params.arguments?["resource_type"]?.stringValue else {
                return .init(
                    content: [.text(text: "Missing required parameter: resource_type", annotations: nil, _meta: nil)],
                    isError: true
                )
            }

            let configPath = try resolveConfigPath(from: params.arguments?["config_path"]?.stringValue)
            let configURL = URL(fileURLWithPath: configPath)
            let config = try await PKLEvaluator.evaluate(configPath: configURL)
            let client = try await state.getClient()

            let types = resourceType == "all"
                ? ["colors", "icons", "images", "typography"]
                : [resourceType]

            var results = InspectResult(configPath: configPath)

            for type in types {
                switch type {
                case "colors":
                    results.colors = try await inspectColors(config: config, client: client)
                case "icons":
                    results.icons = try await inspectIcons(config: config, client: client)
                case "images":
                    results.images = try await inspectImages(config: config, client: client)
                case "typography":
                    results.typography = try await inspectTypography(config: config, client: client)
                default:
                    results.unknownTypes[type] = "Unknown resource type: \(type)"
                }
            }

            return try .init(content: [.text(text: encodeJSON(results), annotations: nil, _meta: nil)])
        }

        // MARK: - Inspect Helpers

        private static func requireFileId(config: PKLConfig) throws -> String {
            guard let fileId = config.figma?.lightFileId else {
                throw ExFigError.custom(
                    errorString: "No Figma file ID configured. Set figma.lightFileId in config."
                )
            }
            return fileId
        }

        private static func inspectColors(
            config: PKLConfig,
            client: FigmaAPI::Client
        ) async throws -> ColorsInspectResult {
            let fileId = try requireFileId(config: config)
            let styles = try await client.request(StylesEndpoint(fileId: fileId))
            let colorStyles = styles.filter { $0.styleType == .fill }

            var entriesPerPlatform: [String: Int]?
            var entries: [String: Int] = [:]
            if let c = config.ios?.colors { entries["ios"] = c.count }
            if let c = config.android?.colors { entries["android"] = c.count }
            if let c = config.flutter?.colors { entries["flutter"] = c.count }
            if let c = config.web?.colors { entries["web"] = c.count }
            if !entries.isEmpty { entriesPerPlatform = entries }

            return ColorsInspectResult(
                fileId: fileId,
                stylesCount: styles.count,
                colorStylesCount: colorStyles.count,
                sampleNames: colorStyles.isEmpty ? nil : Array(colorStyles.prefix(20).map(\.name)),
                truncated: colorStyles.count > 20 ? true : nil,
                entriesPerPlatform: entriesPerPlatform
            )
        }

        private static func inspectIcons(
            config: PKLConfig,
            client: FigmaAPI::Client
        ) async throws -> ComponentsInspectResult {
            let fileId = try requireFileId(config: config)
            let components = try await client.request(ComponentsEndpoint(fileId: fileId))

            return ComponentsInspectResult(
                fileId: fileId,
                componentsCount: components.count,
                sampleNames: components.isEmpty ? nil : Array(components.prefix(20).map(\.name)),
                truncated: components.count > 20 ? true : nil
            )
        }

        private static func inspectImages(
            config: PKLConfig,
            client: FigmaAPI::Client
        ) async throws -> FileInspectResult {
            let fileId = try requireFileId(config: config)
            let metadata = try await client.request(FileMetadataEndpoint(fileId: fileId))

            return FileInspectResult(
                fileId: fileId,
                fileName: metadata.name,
                lastModified: metadata.lastModified,
                version: metadata.version
            )
        }

        private static func inspectTypography(
            config: PKLConfig,
            client: FigmaAPI::Client
        ) async throws -> TypographyInspectResult {
            let fileId = try requireFileId(config: config)
            let styles = try await client.request(StylesEndpoint(fileId: fileId))
            let textStyles = styles.filter { $0.styleType == .text }

            return TypographyInspectResult(
                fileId: fileId,
                textStylesCount: textStyles.count,
                sampleNames: textStyles.isEmpty ? nil : Array(textStyles.prefix(20).map(\.name)),
                truncated: textStyles.count > 20 ? true : nil
            )
        }

        // MARK: - Helpers

        private static func resolveConfigPath(from argument: String?) throws -> String {
            if let path = argument {
                guard FileManager.default.fileExists(atPath: path) else {
                    throw ExFigError.custom(errorString: "Config file not found: \(path)")
                }
                return path
            }

            for filename in ExFigOptions.defaultConfigFiles
                where FileManager.default.fileExists(atPath: filename)
            {
                return filename
            }

            throw ExFigError.custom(
                errorString: "No exfig.pkl found in current directory. Specify config_path parameter."
            )
        }

        private static func errorResult(_ error: ExFigError) -> CallTool.Result {
            var message = error.errorDescription ?? "\(error)"
            if let recovery = error.recoverySuggestion {
                message += "\n\nSuggestion: \(recovery)"
            }
            return .init(content: [.text(text: message, annotations: nil, _meta: nil)], isError: true)
        }

        /// Encodes a Codable value as pretty-printed JSON with sorted keys.
        private static func encodeJSON(_ value: some Encodable) throws -> String {
            let data = try JSONCodec.encodePrettySorted(value)
            guard let string = String(data: data, encoding: .utf8) else {
                throw ExFigError.custom(errorString: "JSON encoding produced non-UTF-8 data")
            }
            return string
        }
    }

    // MARK: - Export & Download Handlers

    extension MCPToolHandlers {
        private static func requireResourceType(
            from params: CallTool.Parameters,
            validTypes: Set<String>
        ) throws -> String {
            guard let resourceType = params.arguments?["resource_type"]?.stringValue else {
                throw ExFigError.custom(errorString: "Missing required parameter: resource_type")
            }
            guard validTypes.contains(resourceType) else {
                let valid = validTypes.sorted().joined(separator: ", ")
                throw ExFigError.custom(
                    errorString: "Invalid resource_type: \(resourceType). Must be one of: \(valid)"
                )
            }
            return resourceType
        }

        private static func handleExport(params: CallTool.Parameters) async throws -> CallTool.Result {
            let resourceType = try requireResourceType(
                from: params, validTypes: ["colors", "icons", "images", "typography", "all"]
            )

            let configPath = try resolveConfigPath(from: params.arguments?["config_path"]?.stringValue)

            let reportPath = FileManager.default.temporaryDirectory
                .appendingPathComponent("exfig-report-\(UUID().uuidString).json").path
            defer { try? FileManager.default.removeItem(atPath: reportPath) }

            let exportParams = ExportParams(
                resourceType: resourceType,
                configPath: configPath,
                reportPath: reportPath,
                filter: params.arguments?["filter"]?.stringValue,
                rateLimit: params.arguments?["rate_limit"]?.intValue,
                maxRetries: params.arguments?["max_retries"]?.intValue,
                cache: params.arguments?["cache"]?.boolValue ?? false,
                force: params.arguments?["force"]?.boolValue ?? false,
                granularCache: params.arguments?["granular_cache"]?.boolValue ?? false
            )

            let result = try await runSubprocess(arguments: exportParams.cliArgs)

            if FileManager.default.fileExists(atPath: reportPath),
               let reportData = FileManager.default.contents(atPath: reportPath),
               let reportJSON = String(data: reportData, encoding: .utf8)
            {
                return .init(
                    content: [.text(text: reportJSON, annotations: nil, _meta: nil)],
                    isError: result.exitCode != 0
                )
            }

            if result.exitCode != 0 {
                let message = result.stderr.isEmpty
                    ? "Export failed with exit code \(result.exitCode)"
                    : result.stderr
                return .init(content: [.text(text: message, annotations: nil, _meta: nil)], isError: true)
            }

            return .init(content: [.text(text: "{\"success\": true}", annotations: nil, _meta: nil)])
        }

        private static func handleDownload(
            params: CallTool.Parameters,
            state: MCPServerState
        ) async throws -> CallTool.Result {
            let resourceType = try requireResourceType(
                from: params, validTypes: ["colors", "typography", "tokens"]
            )

            // Validate cheap parameters before expensive PKL eval / API client creation
            let format = params.arguments?["format"]?.stringValue ?? "w3c"
            let validFormats: Set = ["w3c", "raw"]
            guard validFormats.contains(format) else {
                throw ExFigError.custom(
                    errorString: "Invalid format: \(format). Must be one of: w3c, raw"
                )
            }
            let filter = params.arguments?["filter"]?.stringValue

            let configPath = try resolveConfigPath(from: params.arguments?["config_path"]?.stringValue)
            let configURL = URL(fileURLWithPath: configPath)
            let config = try await PKLEvaluator.evaluate(configPath: configURL)
            let client = try await state.getClient()

            switch resourceType {
            case "colors":
                return try await downloadColors(
                    config: config, client: client, format: format, filter: filter
                )
            case "typography":
                return try await downloadTypography(config: config, client: client, format: format)
            case "tokens":
                return try await downloadUnifiedTokens(config: config, client: client)
            default:
                return .init(
                    content: [.text(text: "Unknown resource_type: \(resourceType)", annotations: nil, _meta: nil)],
                    isError: true
                )
            }
        }
    }

    // MARK: - Export Subprocess Helpers

    private struct ExportParams {
        let resourceType: String
        let configPath: String
        let reportPath: String
        let filter: String?
        let rateLimit: Int?
        let maxRetries: Int?
        let cache: Bool
        let force: Bool
        let granularCache: Bool

        var cliArgs: [String] {
            var args: [String] = if resourceType == "all" {
                ["batch", configPath, "--quiet", "--report", reportPath]
            } else {
                [resourceType, "-i", configPath, "--quiet", "--report", reportPath]
            }
            if let filter { args += ["--filter", filter] }
            if let rateLimit { args += ["--rate-limit", "\(rateLimit)"] }
            if let maxRetries { args += ["--max-retries", "\(maxRetries)"] }
            if cache { args.append("--cache") }
            if force { args.append("--force") }
            if granularCache { args.append("--experimental-granular-cache") }
            return args
        }
    }

    private struct SubprocessResult {
        let exitCode: Int
        let stderr: String
    }

    private let subprocessTimeout: Duration = .seconds(300)

    extension MCPToolHandlers {
        private static func runSubprocess(arguments: [String]) async throws -> SubprocessResult {
            let executablePath = ProcessInfo.processInfo.arguments[0]
            let executableURL = URL(fileURLWithPath: executablePath)
            guard FileManager.default.isExecutableFile(atPath: executablePath) else {
                throw ExFigError.custom(
                    errorString: "Cannot find exfig executable at \(executablePath) for subprocess export"
                )
            }

            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments
            process.environment = ProcessInfo.processInfo.environment

            let stderrPipe = Pipe()
            process.standardError = stderrPipe
            process.standardOutput = FileHandle.nullDevice

            // Read stderr concurrently to avoid pipe buffer deadlock.
            // Must start reading BEFORE waiting for termination.
            let stderrTask = Task {
                stderrPipe.fileHandleForReading.readDataToEndOfFile()
            }

            // Set termination handler BEFORE run() to avoid race condition
            // where process exits before handler is installed.
            return try await withThrowingTaskGroup(of: SubprocessResult.self) { group in
                group.addTask {
                    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                        process.terminationHandler = { _ in continuation.resume() }
                        do { try process.run() } catch {
                            continuation.resume()
                        }
                    }
                    let stderrData = await stderrTask.value
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                    return SubprocessResult(exitCode: Int(process.terminationStatus), stderr: stderr)
                }
                group.addTask {
                    try await Task.sleep(for: subprocessTimeout)
                    process.terminate()
                    throw ExFigError.custom(
                        errorString: "Export subprocess timed out after \(subprocessTimeout)"
                    )
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
        }
    }

    // MARK: - Download Helpers

    extension MCPToolHandlers {
        private static func downloadColors(
            config: PKLConfig, client: FigmaAPI::Client,
            format: String, filter: String?
        ) async throws -> CallTool.Result {
            let result: ColorsVariablesLoader.LoadResult

            if let variableParams = config.common?.variablesColors {
                let loader = ColorsVariablesLoader(client: client, variableParams: variableParams, filter: filter)
                result = try await loader.load()
            } else if let figmaParams = config.figma {
                let loader = ColorsLoader(
                    client: client,
                    figmaParams: figmaParams,
                    colorParams: config.common?.colors,
                    filter: filter
                )
                let output = try await loader.load()
                result = ColorsVariablesLoader.LoadResult(
                    output: output, warnings: [], aliases: [:], descriptions: [:], metadata: [:]
                )
            } else {
                throw ExFigError.custom(
                    errorString: "No variablesColors or figma section configured. Check config."
                )
            }

            let warnings = result.warnings.map { ExFigWarningFormatter().format($0) }

            if format == "raw" {
                var content: [Tool.Content] = []
                if !warnings.isEmpty {
                    let meta = DownloadMeta(
                        resourceType: "colors", format: "raw",
                        tokenCount: result.output.light.count, warnings: warnings
                    )
                    try content.append(.text(text: encodeJSON(meta), annotations: nil, _meta: nil))
                }
                try content.append(.text(text: encodeRawColors(result.output), annotations: nil, _meta: nil))
                return .init(content: content)
            }

            let colorsByMode = ColorExportHelper.buildColorsByMode(from: result.output)
            let exporter = W3CTokensExporter(version: .v2025)
            let tokens = exporter.exportColors(
                colorsByMode: colorsByMode,
                descriptions: result.descriptions,
                metadata: result.metadata,
                aliases: result.aliases,
                modeKeyToName: ColorExportHelper.modeKeyToName
            )
            let tokenCount = colorsByMode.values.reduce(0) { $0 + $1.count }

            let meta = DownloadMeta(
                resourceType: "colors", format: format,
                tokenCount: tokenCount,
                warnings: warnings.isEmpty ? nil : warnings
            )
            return try buildDownloadResponse(tokens: tokens, exporter: exporter, meta: meta)
        }

        private static func downloadTypography(
            config: PKLConfig, client: FigmaAPI::Client, format: String
        ) async throws -> CallTool.Result {
            guard let figmaParams = config.figma else {
                throw ExFigError.custom(errorString: "No figma section configured. Check config.")
            }

            let loader = TextStylesLoader(client: client, params: figmaParams)
            let textStyles = try await loader.load()

            if format == "raw" {
                return try .init(content: [.text(
                    text: encodeJSON(textStyles.map { RawTextStyle(from: $0) }),
                    annotations: nil,
                    _meta: nil
                )])
            }

            let exporter = W3CTokensExporter(version: .v2025)
            let tokens = exporter.exportTypography(textStyles: textStyles)

            let meta = DownloadMeta(
                resourceType: "typography", format: format,
                tokenCount: textStyles.count, warnings: nil
            )
            return try buildDownloadResponse(tokens: tokens, exporter: exporter, meta: meta)
        }

        private static func downloadUnifiedTokens(
            config: PKLConfig, client: FigmaAPI::Client
        ) async throws -> CallTool.Result {
            let exporter = W3CTokensExporter(version: .v2025)
            var allTokens: [String: Any] = [:]
            var warnings: [String] = []
            var tokenCount = 0

            let variableParams = config.common?.variablesColors

            if let variableParams {
                let (tokens, count, w) = try await downloadAndMergeColors(
                    client: client, variableParams: variableParams, exporter: exporter
                )
                W3CTokensExporter.mergeTokens(from: tokens, into: &allTokens)
                tokenCount += count
                warnings += w
            } else {
                warnings.append("Skipped colors and numbers: no variablesColors configured")
            }

            if let figmaParams = config.figma {
                let (tokens, count) = try await downloadAndMergeTypography(
                    client: client, figmaParams: figmaParams, exporter: exporter
                )
                W3CTokensExporter.mergeTokens(from: tokens, into: &allTokens)
                tokenCount += count
            } else {
                warnings.append("Skipped typography: no figma section configured")
            }

            if let variableParams {
                let (tokens, count, w) = try await downloadAndMergeNumbers(
                    client: client, variableParams: variableParams, exporter: exporter
                )
                for t in tokens {
                    W3CTokensExporter.mergeTokens(from: t, into: &allTokens)
                }
                tokenCount += count
                warnings += w
            }

            if allTokens.isEmpty {
                return .init(
                    content: [.text(
                        text: "No token sections configured for export. Check your config file.",
                        annotations: nil,
                        _meta: nil
                    )],
                    isError: true
                )
            }

            let meta = DownloadMeta(
                resourceType: "tokens", format: "w3c",
                tokenCount: tokenCount,
                warnings: warnings.isEmpty ? nil : warnings
            )
            return try buildDownloadResponse(tokens: allTokens, exporter: exporter, meta: meta)
        }

        private static func downloadAndMergeColors(
            client: FigmaAPI::Client,
            variableParams: PKLConfig.Common.VariablesColors,
            exporter: W3CTokensExporter
        ) async throws -> (tokens: [String: Any], count: Int, warnings: [String]) {
            let loader = ColorsVariablesLoader(client: client, variableParams: variableParams, filter: nil)
            let colorsResult = try await loader.load()
            let warnings = colorsResult.warnings.map { ExFigWarningFormatter().format($0) }
            let colorsByMode = ColorExportHelper.buildColorsByMode(from: colorsResult.output)
            let colorTokens = exporter.exportColors(
                colorsByMode: colorsByMode,
                descriptions: colorsResult.descriptions,
                metadata: colorsResult.metadata,
                aliases: colorsResult.aliases,
                modeKeyToName: ColorExportHelper.modeKeyToName
            )
            let count = colorsByMode.values.reduce(0) { $0 + $1.count }
            return (colorTokens, count, warnings)
        }

        private static func downloadAndMergeTypography(
            client: FigmaAPI::Client,
            figmaParams: PKLConfig.Figma,
            exporter: W3CTokensExporter
        ) async throws -> (tokens: [String: Any], count: Int) {
            let loader = TextStylesLoader(client: client, params: figmaParams)
            let textStyles = try await loader.load()
            let tokens = exporter.exportTypography(textStyles: textStyles)
            return (tokens, textStyles.count)
        }

        private static func downloadAndMergeNumbers(
            client: FigmaAPI::Client,
            variableParams: PKLConfig.Common.VariablesColors,
            exporter: W3CTokensExporter
        ) async throws -> (tokens: [[String: Any]], count: Int, warnings: [String]) {
            let numLoader = NumberVariablesLoader(
                client: client,
                tokensFileId: variableParams.tokensFileId,
                tokensCollectionName: variableParams.tokensCollectionName
            )
            let numberResult = try await numLoader.load()
            let warnings = numberResult.warnings.map { ExFigWarningFormatter().format($0) }
            var tokens: [[String: Any]] = []
            var count = 0
            if !numberResult.dimensions.isEmpty {
                tokens.append(exporter.exportDimensions(tokens: numberResult.dimensions))
                count += numberResult.dimensions.count
            }
            if !numberResult.numbers.isEmpty {
                tokens.append(exporter.exportNumbers(tokens: numberResult.numbers))
                count += numberResult.numbers.count
            }
            return (tokens, count, warnings)
        }

        private static func buildDownloadResponse(
            tokens: [String: Any], exporter: W3CTokensExporter,
            meta: DownloadMeta
        ) throws -> CallTool.Result {
            let tokensData = try exporter.serializeToJSON(tokens, compact: false)
            guard let tokensJSON = String(data: tokensData, encoding: .utf8) else {
                throw ExFigError.custom(errorString: "Token JSON serialization produced non-UTF-8 data")
            }

            return try .init(content: [
                .text(text: encodeJSON(meta), annotations: nil, _meta: nil),
                .text(text: tokensJSON, annotations: nil, _meta: nil),
            ])
        }

        private static func encodeRawColors(_ output: ColorsLoaderOutput) throws -> String {
            let toRaw: (Color) -> RawColor = { color in
                RawColor(
                    name: color.name,
                    red: color.red, green: color.green,
                    blue: color.blue, alpha: color.alpha
                )
            }
            let raw = RawColorsOutput(
                light: output.light.map(toRaw),
                dark: output.dark.map { $0.map(toRaw) },
                lightHC: output.lightHC.map { $0.map(toRaw) },
                darkHC: output.darkHC.map { $0.map(toRaw) }
            )
            return try encodeJSON(raw)
        }
    }

    // MARK: - Response Types

    private struct ValidateSummary: Codable {
        let configPath: String
        let valid: Bool
        var platforms: [String: EntrySummary]?
        var figmaFileIds: [String]?
        var darkMode: [String]?

        enum CodingKeys: String, CodingKey {
            case configPath = "config_path"
            case valid
            case platforms
            case figmaFileIds = "figma_file_ids"
            case darkMode = "dark_mode"
        }
    }

    private struct EntrySummary: Codable {
        var colorsEntries: Int?
        var iconsEntries: Int?
        var imagesEntries: Int?
        var typography: Bool?

        enum CodingKeys: String, CodingKey {
            case colorsEntries = "colors_entries"
            case iconsEntries = "icons_entries"
            case imagesEntries = "images_entries"
            case typography
        }
    }

    private struct TokensInfoResult: Codable {
        let filePath: String
        let totalTokens: Int
        let aliasCount: Int
        var countsByType: [String: Int]?
        var topLevelGroups: [String: Int]?
        var warnings: [String]?

        enum CodingKeys: String, CodingKey {
            case filePath = "file_path"
            case totalTokens = "total_tokens"
            case aliasCount = "alias_count"
            case countsByType = "counts_by_type"
            case topLevelGroups = "top_level_groups"
            case warnings
        }
    }

    private struct InspectResult: Codable {
        let configPath: String
        var colors: ColorsInspectResult?
        var icons: ComponentsInspectResult?
        var images: FileInspectResult?
        var typography: TypographyInspectResult?
        var unknownTypes: [String: String] = [:]

        enum CodingKeys: String, CodingKey {
            case configPath = "config_path"
            case colors, icons, images, typography
            case unknownTypes = "unknown_types"
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(configPath, forKey: .configPath)
            try container.encodeIfPresent(colors, forKey: .colors)
            try container.encodeIfPresent(icons, forKey: .icons)
            try container.encodeIfPresent(images, forKey: .images)
            try container.encodeIfPresent(typography, forKey: .typography)
            if !unknownTypes.isEmpty {
                try container.encode(unknownTypes, forKey: .unknownTypes)
            }
        }
    }

    private struct ColorsInspectResult: Codable {
        let fileId: String
        let stylesCount: Int
        let colorStylesCount: Int
        var sampleNames: [String]?
        var truncated: Bool?
        var entriesPerPlatform: [String: Int]?

        enum CodingKeys: String, CodingKey {
            case fileId = "file_id"
            case stylesCount = "styles_count"
            case colorStylesCount = "color_styles_count"
            case sampleNames = "sample_names"
            case truncated
            case entriesPerPlatform = "entries_per_platform"
        }
    }

    private struct ComponentsInspectResult: Codable {
        let fileId: String
        let componentsCount: Int
        var sampleNames: [String]?
        var truncated: Bool?

        enum CodingKeys: String, CodingKey {
            case fileId = "file_id"
            case componentsCount = "components_count"
            case sampleNames = "sample_names"
            case truncated
        }
    }

    private struct FileInspectResult: Codable {
        let fileId: String
        let fileName: String
        let lastModified: String
        let version: String

        enum CodingKeys: String, CodingKey {
            case fileId = "file_id"
            case fileName = "file_name"
            case lastModified = "last_modified"
            case version
        }
    }

    private struct TypographyInspectResult: Codable {
        let fileId: String
        let textStylesCount: Int
        var sampleNames: [String]?
        var truncated: Bool?

        enum CodingKeys: String, CodingKey {
            case fileId = "file_id"
            case textStylesCount = "text_styles_count"
            case sampleNames = "sample_names"
            case truncated
        }
    }

    private struct DownloadMeta: Codable {
        let resourceType: String
        let format: String
        let tokenCount: Int
        var warnings: [String]?

        enum CodingKeys: String, CodingKey {
            case resourceType = "resource_type"
            case format
            case tokenCount = "token_count"
            case warnings
        }
    }

    private struct RawColorsOutput: Codable {
        let light: [RawColor]
        let dark: [RawColor]?
        let lightHC: [RawColor]?
        let darkHC: [RawColor]?
    }

    private struct RawColor: Codable {
        let name: String
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
    }

    private struct RawTextStyle: Codable {
        let name: String
        let fontName: String
        let fontSize: Double
        let lineHeight: Double?
        let letterSpacing: Double

        init(from textStyle: TextStyle) {
            name = textStyle.name
            fontName = textStyle.fontName
            fontSize = textStyle.fontSize
            lineHeight = textStyle.lineHeight
            letterSpacing = textStyle.letterSpacing
        }

        enum CodingKeys: String, CodingKey {
            case name
            case fontName = "font_name"
            case fontSize = "font_size"
            case lineHeight = "line_height"
            case letterSpacing = "letter_spacing"
        }
    }

    // swiftlint:enable file_length
#endif
