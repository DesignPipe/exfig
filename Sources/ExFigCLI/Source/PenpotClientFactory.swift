import Foundation
import PenpotAPI

/// Shared factory for creating authenticated Penpot API clients.
enum PenpotClientFactory {
    static func makeClient(baseURL: String) throws -> any PenpotClient {
        guard let token = ProcessInfo.processInfo.environment["PENPOT_ACCESS_TOKEN"], !token.isEmpty else {
            throw ExFigError.configurationError(
                "PENPOT_ACCESS_TOKEN environment variable is required for Penpot source"
            )
        }
        return BasePenpotClient(accessToken: token, baseURL: baseURL)
    }
}
