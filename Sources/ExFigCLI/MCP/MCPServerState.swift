#if canImport(MCP)
    import ExFigCore
    import FigmaAPI
    import Foundation

    /// Shared state for MCP server — lazy FigmaClient, rate limiting across calls.
    actor MCPServerState {
        private var cachedClient: FigmaAPI::Client?
        private var rateLimiter: SharedRateLimiter?

        /// Returns a configured Figma API client, creating one lazily if needed.
        /// Reuses the same client and rate limiter across all MCP tool calls.
        func getClient() throws -> FigmaAPI::Client {
            if let client = cachedClient {
                return client
            }

            guard let token = ProcessInfo.processInfo.environment["FIGMA_PERSONAL_TOKEN"] else {
                throw ExFigError.accessTokenNotFound
            }

            let baseClient = FigmaClient(accessToken: token, timeout: nil)
            let limiter = SharedRateLimiter(requestsPerMinute: 10)
            let retryPolicy = RetryPolicy(maxRetries: 4)

            let client = RateLimitedClient(
                client: baseClient,
                rateLimiter: limiter,
                configID: ConfigID("mcp"),
                retryPolicy: retryPolicy,
                onRetry: nil
            )

            cachedClient = client
            rateLimiter = limiter

            return client
        }
    }
#endif
