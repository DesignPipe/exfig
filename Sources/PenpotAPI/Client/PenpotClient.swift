import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import YYJSON

/// Protocol for Penpot API clients.
public protocol PenpotClient: Sendable {
    /// Executes a Penpot RPC endpoint and returns the decoded content.
    func request<T: PenpotEndpoint>(_ endpoint: T) async throws -> T.Content

    /// Downloads raw binary data from a URL path (e.g., asset downloads).
    func download(path: String) async throws -> Data
}

/// Default Penpot API client with authentication and retry logic.
public struct BasePenpotClient: PenpotClient {
    /// Default Penpot cloud base URL.
    public static let defaultBaseURL = "https://design.penpot.app/"

    private let accessToken: String
    private let baseURL: String
    private let session: URLSession
    private let maxRetries: Int

    public init(
        accessToken: String,
        baseURL: String = Self.defaultBaseURL,
        timeout: TimeInterval = 60,
        maxRetries: Int = 3
    ) {
        self.accessToken = accessToken
        self.baseURL = baseURL.hasSuffix("/") ? baseURL : baseURL + "/"
        self.maxRetries = maxRetries

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        session = URLSession(configuration: config)
    }

    public func request<T: PenpotEndpoint>(_ endpoint: T) async throws -> T.Content {
        let url = try buildURL(for: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = try endpoint.body() {
            request.httpBody = body
        }

        let (data, response) = try await performWithRetry(request: request, endpoint: endpoint.commandName)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PenpotAPIError(statusCode: 0, message: "Invalid response type", endpoint: endpoint.commandName)
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw PenpotAPIError(
                statusCode: httpResponse.statusCode,
                message: message,
                endpoint: endpoint.commandName
            )
        }

        return try endpoint.content(from: data)
    }

    public func download(path: String) async throws -> Data {
        guard let url = URL(string: baseURL + path) else {
            throw PenpotAPIError(statusCode: 0, message: "Invalid download URL: \(path)", endpoint: "download")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Token \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await performWithRetry(request: request, endpoint: "download")

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode)
        else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw PenpotAPIError(statusCode: statusCode, message: "Download failed", endpoint: "download")
        }

        return data
    }

    // MARK: - Private

    private func buildURL(for endpoint: some PenpotEndpoint) throws -> URL {
        guard let url = URL(string: "\(baseURL)api/main/methods/\(endpoint.commandName)") else {
            throw PenpotAPIError(
                statusCode: 0,
                message: "Failed to construct URL for command: \(endpoint.commandName)",
                endpoint: endpoint.commandName
            )
        }
        return url
    }

    private func performWithRetry(
        request: URLRequest,
        endpoint: String
    ) async throws -> (Data, URLResponse) {
        var lastError: Error?

        for attempt in 0 ..< maxRetries {
            do {
                let (data, response) = try await session.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    let statusCode = httpResponse.statusCode

                    // Retry on 429 or 5xx
                    if statusCode == 429 || (500 ..< 600).contains(statusCode) {
                        lastError = PenpotAPIError(
                            statusCode: statusCode,
                            message: String(data: data, encoding: .utf8),
                            endpoint: endpoint
                        )

                        if attempt < maxRetries - 1 {
                            let delay = pow(2.0, Double(attempt)) // 1s, 2s, 4s
                            try await Task.sleep(for: .seconds(delay))
                            continue
                        }
                    }
                }

                return (data, response)
            } catch let error as PenpotAPIError {
                throw error
            } catch {
                lastError = error

                if attempt < maxRetries - 1 {
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(for: .seconds(delay))
                    continue
                }
            }
        }

        throw lastError ?? PenpotAPIError(
            statusCode: 0,
            message: "Request failed after \(maxRetries) retries",
            endpoint: endpoint
        )
    }
}
