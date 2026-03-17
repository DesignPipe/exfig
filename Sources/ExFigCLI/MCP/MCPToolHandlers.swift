// swiftlint:disable file_length

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
            default:
                return .init(content: [.text("Unknown tool: \(params.name)")], isError: true)
            }
        } catch let error as ExFigError {
            return errorResult(error)
        } catch let error as TokensFileError {
            return .init(
                content: [.text("Token file error: \(error.errorDescription ?? "\(error)")")],
                isError: true
            )
        } catch {
            return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
        }
    }

    // MARK: - Validate

    private static func handleValidate(params: CallTool.Parameters) async throws -> CallTool.Result {
        let configPath = try resolveConfigPath(from: params.arguments?["config_path"]?.stringValue)
        let configURL = URL(fileURLWithPath: configPath)

        let config = try await PKLEvaluator.evaluate(configPath: configURL)

        var summary: [String: Any] = [
            "config_path": configPath,
            "valid": true,
        ]

        let platforms = buildPlatformSummary(config: config)
        if !platforms.isEmpty { summary["platforms"] = platforms }

        let fileIDs = Array(config.getFileIds())
        if !fileIDs.isEmpty { summary["figma_file_ids"] = fileIDs.sorted() }

        return .init(content: [.text(formatJSON(summary))])
    }

    private static func buildPlatformSummary(config: PKLConfig) -> [String: Any] {
        var platforms: [String: Any] = [:]

        if let ios = config.ios {
            platforms["ios"] = entrySummary(
                colors: ios.colors?.count, icons: ios.icons?.count,
                images: ios.images?.count, hasTypography: ios.typography != nil
            )
        }
        if let android = config.android {
            platforms["android"] = entrySummary(
                colors: android.colors?.count, icons: android.icons?.count,
                images: android.images?.count, hasTypography: android.typography != nil
            )
        }
        if let flutter = config.flutter {
            platforms["flutter"] = entrySummary(
                colors: flutter.colors?.count, icons: flutter.icons?.count,
                images: flutter.images?.count
            )
        }
        if let web = config.web {
            platforms["web"] = entrySummary(
                colors: web.colors?.count, icons: web.icons?.count,
                images: web.images?.count
            )
        }

        return platforms
    }

    private static func entrySummary(
        colors: Int? = nil, icons: Int? = nil,
        images: Int? = nil, hasTypography: Bool = false
    ) -> [String: Any] {
        var info: [String: Any] = [:]
        if let c = colors { info["colors_entries"] = c }
        if let i = icons { info["icons_entries"] = i }
        if let m = images { info["images_entries"] = m }
        if hasTypography { info["typography"] = true }
        return info
    }

    // MARK: - Tokens Info

    private static func handleTokensInfo(params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let filePath = params.arguments?["file_path"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: file_path")], isError: true)
        }

        var source = try TokensFileSource.parse(fileAt: filePath)
        try source.resolveAliases()

        var result: [String: Any] = [
            "file_path": filePath,
            "total_tokens": source.tokens.count,
            "alias_count": source.aliasCount,
        ]

        let byType = source.tokenCountsByType()
        if !byType.isEmpty {
            var typeCounts: [String: Int] = [:]
            for entry in byType {
                typeCounts[entry.type] = entry.count
            }
            result["counts_by_type"] = typeCounts
        }

        let groups = source.topLevelGroups()
        if !groups.isEmpty {
            var groupCounts: [String: Int] = [:]
            for entry in groups {
                groupCounts[entry.name] = entry.count
            }
            result["top_level_groups"] = groupCounts
        }

        if !source.warnings.isEmpty {
            result["warnings"] = source.warnings
        }

        let jsonText = formatJSON(result)
        return .init(content: [.text(jsonText)])
    }

    // MARK: - Inspect

    // swiftlint:disable:next cyclomatic_complexity
    private static func handleInspect(
        params: CallTool.Parameters,
        state: MCPServerState
    ) async throws -> CallTool.Result {
        let configPath = try resolveConfigPath(from: params.arguments?["config_path"]?.stringValue)
        let configURL = URL(fileURLWithPath: configPath)
        let config = try await PKLEvaluator.evaluate(configPath: configURL)
        let client = try await state.getClient()

        guard let resourceType = params.arguments?["resource_type"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: resource_type")], isError: true)
        }

        var results: [String: Any] = ["config_path": configPath]
        let types = resourceType == "all"
            ? ["colors", "icons", "images", "typography"]
            : [resourceType]

        for type in types {
            switch type {
            case "colors":
                results["colors"] = try await inspectColors(config: config, client: client)
            case "icons":
                results["icons"] = try await inspectIcons(config: config, client: client)
            case "images":
                results["images"] = try await inspectImages(config: config, client: client)
            case "typography":
                results["typography"] = try await inspectTypography(config: config, client: client)
            default:
                results[type] = ["error": "Unknown resource type: \(type)"]
            }
        }

        let jsonText = formatJSON(results)
        return .init(content: [.text(jsonText)])
    }

    // MARK: - Inspect Helpers

    private static func inspectColors(
        config: PKLConfig,
        client: FigmaAPI.Client
    ) async throws -> [String: Any] {
        guard let fileId = config.figma?.lightFileId else {
            return ["status": "no_config", "message": "No Figma file ID configured"]
        }

        let styles = try await client.request(StylesEndpoint(fileId: fileId))

        var result: [String: Any] = [
            "file_id": fileId,
            "styles_count": styles.count,
        ]

        // Filter color styles
        let colorStyles = styles.filter { $0.styleType == .fill }
        result["color_styles_count"] = colorStyles.count
        if !colorStyles.isEmpty {
            result["sample_names"] = Array(colorStyles.prefix(20).map(\.name))
            if colorStyles.count > 20 { result["truncated"] = true }
        }

        // Count platform entries
        var entries: [String: Int] = [:]
        if let c = config.ios?.colors { entries["ios"] = c.count }
        if let c = config.android?.colors { entries["android"] = c.count }
        if let c = config.flutter?.colors { entries["flutter"] = c.count }
        if let c = config.web?.colors { entries["web"] = c.count }
        if !entries.isEmpty { result["entries_per_platform"] = entries }

        return result
    }

    private static func inspectIcons(
        config: PKLConfig,
        client: FigmaAPI.Client
    ) async throws -> [String: Any] {
        guard let fileId = config.figma?.lightFileId else {
            return ["status": "no_config", "message": "No Figma file ID configured"]
        }

        let components = try await client.request(ComponentsEndpoint(fileId: fileId))

        var result: [String: Any] = [
            "file_id": fileId,
            "components_count": components.count,
        ]

        if !components.isEmpty {
            result["sample_names"] = Array(components.prefix(20).map(\.name))
            if components.count > 20 { result["truncated"] = true }
        }

        return result
    }

    private static func inspectImages(
        config: PKLConfig,
        client: FigmaAPI.Client
    ) async throws -> [String: Any] {
        // Images share the same file — use lightFileId or a dedicated images file
        guard let fileId = config.figma?.lightFileId else {
            return ["status": "no_config", "message": "No Figma file ID configured"]
        }

        let metadata = try await client.request(FileMetadataEndpoint(fileId: fileId))

        return [
            "file_id": fileId,
            "file_name": metadata.name,
            "last_modified": metadata.lastModified,
            "version": metadata.version,
        ]
    }

    private static func inspectTypography(
        config: PKLConfig,
        client: FigmaAPI.Client
    ) async throws -> [String: Any] {
        guard let fileId = config.figma?.lightFileId else {
            return ["status": "no_config", "message": "No Figma file ID configured"]
        }

        let styles = try await client.request(StylesEndpoint(fileId: fileId))
        let textStyles = styles.filter { $0.styleType == .text }

        var result: [String: Any] = [
            "file_id": fileId,
            "text_styles_count": textStyles.count,
        ]

        if !textStyles.isEmpty {
            result["sample_names"] = Array(textStyles.prefix(20).map(\.name))
            if textStyles.count > 20 { result["truncated"] = true }
        }

        return result
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
        return .init(content: [.text(message)], isError: true)
    }

    /// Formats a dictionary as pretty-printed JSON string.
    private static func formatJSON(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            return "\(dict)"
        }
        return String(data: data, encoding: .utf8) ?? "\(dict)"
    }
}

// swiftlint:enable file_length
