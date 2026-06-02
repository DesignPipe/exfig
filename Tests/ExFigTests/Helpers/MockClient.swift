import FigmaAPI
import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Thread-safe mock client for testing FigmaAPI interactions.
/// Uses a serial queue for thread-safe synchronous access within async context.
public final class MockClient: Client, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.exfig.tests.mockclient")
    private var _responses: [String: Any] = [:]
    private var _errors: [String: any Error] = [:]
    private var _requestLog: [URLRequest] = []
    private var _requestTimestamps: [Date] = []
    private var _requestDelay: TimeInterval = 0

    public init() {}

    // MARK: - Keys

    /// Per-endpoint-type key (file-agnostic). Used as the fallback when no file-specific
    /// response is configured.
    private func key(forType endpointType: Any.Type) -> String {
        String(describing: endpointType)
    }

    /// File-specific key. Lets a single mock return different responses for different file IDs
    /// (e.g. cross-file variable resolution), which the type-only key cannot express.
    private func key(forType endpointType: Any.Type, fileId: String) -> String {
        "\(endpointType)#\(fileId)"
    }

    /// Extracts the `{fileId}` path segment from a Figma `…/v1/files/{fileId}/…` request URL.
    private func fileId(from request: URLRequest) -> String? {
        guard let segments = request.url?.pathComponents,
              let filesIndex = segments.firstIndex(of: "files"),
              segments.index(after: filesIndex) < segments.endIndex
        else { return nil }
        return segments[segments.index(after: filesIndex)]
    }

    // MARK: - Configuration

    /// Sets a successful response for a specific endpoint type (any file ID).
    public func setResponse<T: Endpoint>(_ response: T.Content, for endpointType: T.Type) {
        let key = key(forType: endpointType)
        queue.sync {
            self._responses[key] = response
            self._errors.removeValue(forKey: key)
        }
    }

    /// Sets a successful response for a specific endpoint type scoped to a single file ID.
    /// Takes precedence over the file-agnostic response when the request targets `fileId`.
    public func setResponse<T: Endpoint>(_ response: T.Content, for endpointType: T.Type, fileId: String) {
        let key = key(forType: endpointType, fileId: fileId)
        queue.sync {
            self._responses[key] = response
            self._errors.removeValue(forKey: key)
        }
    }

    /// Sets an error to throw for a specific endpoint type (any file ID).
    public func setError(_ error: any Error, for endpointType: (some Endpoint).Type) {
        let key = key(forType: endpointType)
        queue.sync {
            self._errors[key] = error
            self._responses.removeValue(forKey: key)
        }
    }

    /// Sets an error to throw for a specific endpoint type scoped to a single file ID.
    /// Takes precedence over the file-agnostic configuration when the request targets `fileId`.
    public func setError(_ error: any Error, for endpointType: (some Endpoint).Type, fileId: String) {
        let key = key(forType: endpointType, fileId: fileId)
        queue.sync {
            self._errors[key] = error
            self._responses.removeValue(forKey: key)
        }
    }

    /// Clears all configured responses and errors.
    public func reset() {
        queue.sync {
            self._responses.removeAll()
            self._errors.removeAll()
            self._requestLog.removeAll()
            self._requestTimestamps.removeAll()
            self._requestDelay = 0
        }
    }

    /// Sets artificial delay for each request (for testing parallel execution).
    public func setRequestDelay(_ delay: TimeInterval) {
        queue.sync { self._requestDelay = delay }
    }

    // MARK: - Client Protocol

    public func request<T: Endpoint>(_ endpoint: T) async throws -> T.Content {
        let typeKey = key(forType: type(of: endpoint))
        let baseURL = FigmaClient.baseURL
        let request = try endpoint.makeRequest(baseURL: baseURL)
        // File-specific configuration (if any) takes precedence over the file-agnostic one.
        let fileKey = fileId(from: request).map { key(forType: type(of: endpoint), fileId: $0) }

        // Record timestamp and get delay (thread-safe)
        let delay = queue.sync { () -> TimeInterval in
            self._requestLog.append(request)
            self._requestTimestamps.append(Date())
            return self._requestDelay
        }

        // Apply delay outside of sync block to allow parallel execution
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        return try queue.sync {
            // Resolve in precedence order: file-specific, then file-agnostic.
            for candidate in [fileKey, typeKey].compactMap({ $0 }) {
                if let error = self._errors[candidate] { throw error }
                if let response = self._responses[candidate] as? T.Content { return response }
            }
            throw MockClientError.noResponseConfigured(endpoint: typeKey)
        }
    }

    // MARK: - Inspection

    /// All requests made to this mock client.
    public var requestLog: [URLRequest] {
        queue.sync { _requestLog }
    }

    /// Number of requests made.
    public var requestCount: Int {
        queue.sync { _requestLog.count }
    }

    /// Returns the last request made, if any.
    public var lastRequest: URLRequest? {
        queue.sync { _requestLog.last }
    }

    /// Returns requests matching a specific URL path component.
    public func requests(containing path: String) -> [URLRequest] {
        queue.sync {
            _requestLog.filter { $0.url?.absoluteString.contains(path) ?? false }
        }
    }

    /// Timestamps when each request was made.
    public var requestTimestamps: [Date] {
        queue.sync { _requestTimestamps }
    }

    /// Returns true if all requests started within the given time window.
    /// Useful for verifying parallel execution.
    public func requestsStartedWithin(seconds: TimeInterval) -> Bool {
        let timestamps = queue.sync { _requestTimestamps }
        guard timestamps.count >= 2 else { return true }
        let sorted = timestamps.sorted()
        // swiftlint:disable:next force_unwrapping
        return sorted.last!.timeIntervalSince(sorted.first!) < seconds
    }
}

// MARK: - Errors

public enum MockClientError: Error, LocalizedError, Sendable {
    case noResponseConfigured(endpoint: String)

    public var errorDescription: String? {
        switch self {
        case let .noResponseConfigured(endpoint):
            "No mock response configured for endpoint: \(endpoint)"
        }
    }
}
