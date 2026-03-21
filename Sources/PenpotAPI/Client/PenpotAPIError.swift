import Foundation

/// Error type for Penpot API failures.
public struct PenpotAPIError: LocalizedError, Sendable {
    /// HTTP status code (0 for non-HTTP errors).
    public let statusCode: Int

    /// Error message from the API or client.
    public let message: String?

    /// The endpoint command name that failed.
    public let endpoint: String

    public init(statusCode: Int, message: String?, endpoint: String) {
        self.statusCode = statusCode
        self.message = message
        self.endpoint = endpoint
    }

    public var errorDescription: String? {
        if let message {
            "Penpot API error (\(endpoint)): \(statusCode) — \(message)"
        } else {
            "Penpot API error (\(endpoint)): HTTP \(statusCode)"
        }
    }

    public var recoverySuggestion: String? {
        switch statusCode {
        case 401:
            "Check that PENPOT_ACCESS_TOKEN environment variable is set with a valid access token. " +
                "Generate one at Settings → Access Tokens in your Penpot instance."
        case 403:
            "You don't have permission to access this resource. Check file sharing settings."
        case 404:
            "The requested resource was not found. Verify the file UUID is correct."
        case 429:
            "Rate limited by Penpot API. The request was retried but still failed. Try again later."
        default:
            nil
        }
    }
}
