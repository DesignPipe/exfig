import Foundation

/// Protocol for Penpot RPC API endpoints.
///
/// All Penpot API calls are `POST /api/main/methods/<commandName>` with a JSON body.
/// The official docs path `/api/rpc/command/<commandName>` is equivalent but blocked
/// by Cloudflare on design.penpot.app for programmatic clients.
public protocol PenpotEndpoint: Sendable {
    associatedtype Content: Sendable

    /// The RPC command name (e.g., "get-file", "get-profile").
    var commandName: String { get }

    /// Serializes the request body. Penpot requires at minimum an empty JSON object `{}`.
    func body() throws -> Data?

    /// Deserializes the response data into the expected content type.
    func content(from data: Data) throws -> Content
}
