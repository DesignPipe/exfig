// swiftlint:disable file_length
import FigmaAPI
import Foundation
import Logging
import Noora

/// Configuration for pre-fetch operation.
struct PreFetchConfiguration {
    let configs: [ConfigFile]
    let cacheEnabled: Bool
    let noCacheFlag: Bool
    let verbose: Bool
    let rateLimiter: SharedRateLimiter
    let retryPolicy: RetryPolicy

    /// Optional cache for smart component pre-fetch optimization.
    /// When provided, components are only fetched for files with changed versions.
    let cache: ImageTrackingCache?

    init(
        configs: [ConfigFile],
        cacheEnabled: Bool,
        noCacheFlag: Bool,
        verbose: Bool,
        rateLimiter: SharedRateLimiter,
        retryPolicy: RetryPolicy,
        cache: ImageTrackingCache? = nil
    ) {
        self.configs = configs
        self.cacheEnabled = cacheEnabled
        self.noCacheFlag = noCacheFlag
        self.verbose = verbose
        self.rateLimiter = rateLimiter
        self.retryPolicy = retryPolicy
        self.cache = cache
    }
}

/// Result of pre-fetching file versions and components.
struct PreFetchResult {
    let versions: PreFetchedFileVersions?
    let components: PreFetchedComponents?
    let nodes: PreFetchedNodes?
}

/// Pre-fetches file metadata and components for multiple Figma files in parallel.
///
/// Used by batch processing to fetch all unique file versions and components upfront,
/// avoiding redundant API calls when multiple configs reference the same files.
struct FileVersionPreFetcher {
    let client: Client
    let ui: TerminalUI

    private let logger = Logger(label: "com.designpipe.exfig.file-version-prefetcher")

    // MARK: - Static Factory

    /// Pre-fetches file versions for all unique file IDs if cache is enabled.
    ///
    /// This optimization fetches file metadata once per unique fileId before parallel
    /// config processing, avoiding redundant API calls when multiple configs reference
    /// the same Figma files.
    ///
    /// - Parameters:
    ///   - configuration: Pre-fetch configuration.
    ///   - ui: Terminal UI for progress output.
    /// - Returns: PreFetchedFileVersions if successful, nil otherwise.
    static func preFetchIfNeeded(
        configuration: PreFetchConfiguration,
        ui: TerminalUI
    ) async -> PreFetchedFileVersions? {
        // Only pre-fetch when cache is enabled
        guard configuration.cacheEnabled, !configuration.noCacheFlag else {
            return nil
        }

        // Extract unique file IDs from all configs
        let extractor = FileIdExtractor()
        let configURLs = configuration.configs.map(\.url)
        let uniqueFileIds = await extractor.extractUniqueFileIds(from: configURLs)

        guard !uniqueFileIds.isEmpty else {
            return nil
        }

        if configuration.verbose {
            ui.info("Found \(uniqueFileIds.count) unique Figma file(s) to pre-fetch")
        }

        // Get access token
        guard let token = ProcessInfo.processInfo.environment["FIGMA_PERSONAL_TOKEN"] else {
            // Token missing, let individual configs handle this error
            return nil
        }

        // Create rate-limited client for pre-fetch
        let baseClient = FigmaClient(accessToken: token, timeout: nil)
        let client = RateLimitedClient(
            client: baseClient,
            rateLimiter: configuration.rateLimiter,
            configID: ConfigID("prefetch"),
            retryPolicy: configuration.retryPolicy
        )

        // Pre-fetch file versions
        let preFetcher = FileVersionPreFetcher(client: client, ui: ui)
        do {
            return try await preFetcher.preFetch(fileIds: uniqueFileIds)
        } catch {
            // Pre-fetch failed, proceed without optimization
            // Individual configs will fetch their own metadata
            ui.warning("Pre-fetch failed: \(error.bestDescription)")
            return nil
        }
    }

    /// Pre-fetches file versions AND components for all unique file IDs if cache is enabled.
    ///
    /// Uses **smart two-phase pre-fetch**:
    /// 1. Phase 1: Fetch only FileMetadata (fast, lightweight)
    /// 2. Phase 2: Compare versions with cache — only fetch Components for changed files
    ///
    /// This avoids fetching heavy Components endpoint when file hasn't changed.
    ///
    /// - Parameters:
    ///   - configuration: Pre-fetch configuration (includes optional cache for version check).
    ///   - ui: Terminal UI for progress output.
    /// - Returns: PreFetchResult containing versions and optionally components.
    static func preFetchWithComponents(
        configuration: PreFetchConfiguration,
        ui: TerminalUI
    ) async -> PreFetchResult {
        // Only pre-fetch when cache is enabled
        guard configuration.cacheEnabled, !configuration.noCacheFlag else {
            return PreFetchResult(versions: nil, components: nil, nodes: nil)
        }

        // Extract unique file IDs from all configs
        let uniqueFileIds = await extractUniqueFileIds(from: configuration)
        guard !uniqueFileIds.isEmpty else {
            return PreFetchResult(versions: nil, components: nil, nodes: nil)
        }

        if configuration.verbose {
            ui.info("Found \(uniqueFileIds.count) unique Figma file(s) to pre-fetch")
        }

        // Create pre-fetcher with rate-limited client
        guard let preFetcher = createPreFetcher(configuration: configuration, ui: ui) else {
            return PreFetchResult(versions: nil, components: nil, nodes: nil)
        }

        do {
            return try await performSmartPreFetch(
                preFetcher: preFetcher,
                fileIds: uniqueFileIds,
                cache: configuration.cache,
                verbose: configuration.verbose,
                ui: ui
            )
        } catch {
            ui.warning("Pre-fetch failed: \(error.bestDescription)")
            return PreFetchResult(versions: nil, components: nil, nodes: nil)
        }
    }

    /// Extracts unique file IDs from configuration.
    private static func extractUniqueFileIds(from configuration: PreFetchConfiguration) async -> Set<String> {
        let extractor = FileIdExtractor()
        let configURLs = configuration.configs.map(\.url)
        return await extractor.extractUniqueFileIds(from: configURLs)
    }

    /// Creates a rate-limited pre-fetcher.
    static func createPreFetcher(
        configuration: PreFetchConfiguration,
        ui: TerminalUI
    ) -> FileVersionPreFetcher? {
        guard let token = ProcessInfo.processInfo.environment["FIGMA_PERSONAL_TOKEN"] else {
            return nil
        }

        let baseClient = FigmaClient(accessToken: token, timeout: nil)
        let client = RateLimitedClient(
            client: baseClient,
            rateLimiter: configuration.rateLimiter,
            configID: ConfigID("prefetch"),
            retryPolicy: configuration.retryPolicy
        )

        return FileVersionPreFetcher(client: client, ui: ui)
    }

    /// Performs smart two-phase pre-fetch.
    private static func performSmartPreFetch(
        preFetcher: FileVersionPreFetcher,
        fileIds: Set<String>,
        cache: ImageTrackingCache?,
        verbose: Bool,
        ui: TerminalUI
    ) async throws -> PreFetchResult {
        // Phase 1: Fetch only metadata (fast)
        let versions = try await preFetcher.preFetch(fileIds: fileIds)

        // Phase 2: Determine which files need components
        let filesNeedingComponents = determineFilesNeedingComponents(
            versions: versions,
            cache: cache,
            allFileIds: fileIds,
            verbose: verbose,
            ui: ui
        )

        // Phase 3: Fetch components only for changed files
        guard !filesNeedingComponents.isEmpty else {
            return PreFetchResult(versions: versions, components: nil, nodes: nil)
        }

        let components = try await preFetcher.preFetchComponents(fileIds: filesNeedingComponents)

        // Note: Nodes are fetched separately in Batch.swift when granular cache is enabled
        return PreFetchResult(versions: versions, components: components, nodes: nil)
    }

    /// Determines which files need components based on cache state.
    private static func determineFilesNeedingComponents(
        versions: PreFetchedFileVersions,
        cache: ImageTrackingCache?,
        allFileIds: Set<String>,
        verbose: Bool,
        ui: TerminalUI
    ) -> Set<String> {
        guard let cache else {
            // No cache = need all components (first run)
            return allFileIds
        }

        // Smart mode: only fetch components for changed files
        let changedFiles = Set(
            versions.allFileIds.filter { fileId in
                guard let metadata = versions.metadata(for: fileId) else { return false }
                return cache.needsExport(fileId: fileId, currentVersion: metadata.version)
            }
        )

        if verbose {
            let unchangedCount = allFileIds.count - changedFiles.count
            if unchangedCount > 0 {
                ui.info("\(unchangedCount) file(s) unchanged, skipping components fetch")
            }
        }

        return changedFiles
    }

    // MARK: - Instance Methods

    /// Pre-fetch file metadata for all unique file IDs.
    ///
    /// - Parameter fileIds: Set of unique file IDs to fetch.
    /// - Returns: PreFetchedFileVersions containing all successfully fetched metadata.
    /// - Throws: Error if all fetches fail. Partial failures are handled gracefully.
    func preFetch(fileIds: Set<String>) async throws -> PreFetchedFileVersions {
        guard !fileIds.isEmpty else {
            return PreFetchedFileVersions(versions: [:])
        }

        let fileIdArray = Array(fileIds)

        let result = try await ui.withSpinner(
            "Pre-fetching file versions (\(fileIdArray.count) unique files)..."
        ) {
            try await fetchAllMetadata(fileIds: fileIdArray)
        }

        // Report partial failures if any
        let failedCount = fileIdArray.count - result.count
        if failedCount > 0 {
            ui.warning(.preFetchPartialFailure(failed: failedCount, total: fileIdArray.count))
        }

        // Display results table
        displayPreFetchResults(result: result, requestedFileIds: fileIdArray)

        return result
    }

    /// Display pre-fetch results as a Noora table.
    private func displayPreFetchResults(result: PreFetchedFileVersions, requestedFileIds: [String]) {
        guard !result.isEmpty else { return }

        let headers: [TableCellStyle] = [
            .plain("Name"),
            .plain("Status"),
        ]

        let rows: [StyledTableRow] = requestedFileIds.map { fileId in
            if let metadata = result.metadata(for: fileId) {
                return [.plain(metadata.name), .success("✓")]
            } else {
                let truncatedId = String(fileId.prefix(12))
                return [.plain(truncatedId), .danger("✗")]
            }
        }

        NooraUI.shared.table(headers: headers, rows: rows)
    }

    /// Pre-fetch components ONLY for specified file IDs (without metadata).
    ///
    /// Used in phase 2 of smart pre-fetch when we already have metadata
    /// and only need components for files with changed versions.
    ///
    /// - Parameter fileIds: Set of file IDs to fetch components for.
    /// - Returns: PreFetchedComponents containing all successfully fetched components.
    /// - Throws: Error if all fetches fail. Partial failures are handled gracefully.
    func preFetchComponents(fileIds: Set<String>) async throws -> PreFetchedComponents {
        guard !fileIds.isEmpty else {
            return PreFetchedComponents(components: [:])
        }

        let fileIdArray = Array(fileIds)

        let result = try await ui.withSpinner(
            "Fetching components for \(fileIdArray.count) changed file(s)..."
        ) {
            try await fetchAllComponents(fileIds: fileIdArray)
        }

        // Report partial failures
        let failedCount = fileIdArray.count - result.count
        if failedCount > 0 {
            ui.warning(.preFetchComponentsPartialFailure(failed: failedCount, total: fileIdArray.count))
        }

        return result
    }

    /// Fetch metadata for all file IDs in parallel.
    private func fetchAllMetadata(fileIds: [String]) async throws -> PreFetchedFileVersions {
        try await withThrowingTaskGroup(of: (String, FileMetadata?).self) { group in
            for fileId in fileIds {
                group.addTask { [client, logger] in
                    do {
                        let endpoint = FileMetadataEndpoint(fileId: fileId)
                        let metadata = try await client.request(endpoint)
                        return (fileId, metadata)
                    } catch {
                        logger.warning("Pre-fetch metadata failed for file \(fileId): \(error.bestDescription)")
                        return (fileId, nil)
                    }
                }
            }

            var versions: [String: FileMetadata] = [:]
            for try await (fileId, metadata) in group {
                if let metadata {
                    versions[fileId] = metadata
                }
            }

            // If all fetches failed, throw error
            if versions.isEmpty, !fileIds.isEmpty {
                throw PreFetchError.allFetchesFailed(count: fileIds.count)
            }

            return PreFetchedFileVersions(versions: versions)
        }
    }

    /// Pre-fetch nodes for granular cache optimization.
    ///
    /// Collects ALL nodeIds from pre-fetched components and fetches node documents
    /// in a single API call per file. This avoids redundant Nodes API calls when
    /// multiple configs reference the same Figma file.
    ///
    /// - Parameters:
    ///   - components: Pre-fetched components containing nodeIds.
    ///   - changedFileIds: Set of file IDs that have changed versions.
    /// - Returns: PreFetchedNodes containing all node documents.
    func preFetchNodes(
        components: PreFetchedComponents,
        changedFileIds: Set<String>
    ) async throws -> PreFetchedNodes {
        guard !changedFileIds.isEmpty else {
            return PreFetchedNodes(nodes: [:])
        }

        // Collect all nodeIds per file from components
        var nodeIdsByFile: [String: [NodeId]] = [:]
        for fileId in changedFileIds {
            if let fileComponents = components.components(for: fileId) {
                nodeIdsByFile[fileId] = fileComponents.map(\.nodeId)
            }
        }

        let totalNodes = nodeIdsByFile.values.reduce(0) { $0 + $1.count }
        guard totalNodes > 0 else {
            return PreFetchedNodes(nodes: [:])
        }

        // Capture into let for concurrent access
        let nodeIdsByFileSnapshot = nodeIdsByFile

        return try await ui.withSpinner(
            "Pre-fetching nodes for granular cache (\(totalNodes) nodes)..."
        ) {
            try await fetchAllNodes(nodeIdsByFile: nodeIdsByFileSnapshot)
        }
    }

    /// Fetch node documents for all files in parallel.
    private func fetchAllNodes(
        nodeIdsByFile: [String: [NodeId]]
    ) async throws -> PreFetchedNodes {
        // Batch size for NodesEndpoint (Figma API limit)
        let batchSize = 100

        return try await withThrowingTaskGroup(of: (String, [NodeId: Node]).self) { group in
            for (fileId, nodeIds) in nodeIdsByFile {
                group.addTask { [client] in
                    // Split into batches and fetch in parallel
                    let batches = nodeIds.chunked(into: batchSize)
                    var allNodes: [NodeId: Node] = [:]

                    for batch in batches {
                        let endpoint = NodesEndpoint(fileId: fileId, nodeIds: batch)
                        let nodes = try await client.request(endpoint)
                        allNodes.merge(nodes) { _, new in new }
                    }

                    return (fileId, allNodes)
                }
            }

            var nodesByFile: [String: [NodeId: Node]] = [:]
            for try await (fileId, nodes) in group {
                nodesByFile[fileId] = nodes
            }

            return PreFetchedNodes(nodes: nodesByFile)
        }
    }

    /// Fetch components ONLY for all file IDs in parallel (no metadata).
    private func fetchAllComponents(fileIds: [String]) async throws -> PreFetchedComponents {
        try await withThrowingTaskGroup(of: (String, [Component]?).self) { group in
            for fileId in fileIds {
                group.addTask { [client, logger] in
                    do {
                        let endpoint = ComponentsEndpoint(fileId: fileId)
                        let components = try await client.request(endpoint)
                        return (fileId, components)
                    } catch {
                        logger.warning("Pre-fetch components failed for file \(fileId): \(error.bestDescription)")
                        return (fileId, nil)
                    }
                }
            }

            var components: [String: [Component]] = [:]
            for try await (fileId, comps) in group {
                if let comps {
                    components[fileId] = comps
                }
            }

            // If all fetches failed, throw error
            if components.isEmpty, !fileIds.isEmpty {
                throw PreFetchError.allFetchesFailed(count: fileIds.count)
            }

            return PreFetchedComponents(components: components)
        }
    }
}

// MARK: - Errors

/// Errors that can occur during pre-fetching.
enum PreFetchError: Error, LocalizedError {
    /// All file metadata fetches failed.
    case allFetchesFailed(count: Int)

    var errorDescription: String? {
        switch self {
        case let .allFetchesFailed(count):
            "Failed to pre-fetch all \(count) file versions"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .allFetchesFailed:
            "Check your FIGMA_PERSONAL_TOKEN and network connection"
        }
    }
}
