import Foundation

/// Protocol for Penpot RPC API endpoints.
///
/// All Penpot API calls are `POST /api/main/methods/<commandName>`
/// with a JSON body. The legacy path `/api/rpc/command/<commandName>`
/// is preserved for backward compatibility.
public protocol PenpotEndpoint: Sendable {
    associatedtype Content: Sendable

    /// The RPC command name (e.g., "get-file", "get-profile").
    var commandName: String { get }

    /// Serializes the request body. Returns `nil` for body-less commands.
    func body() throws -> Data?

    /// Deserializes the response data into the expected content type.
    func content(from data: Data) throws -> Content
}
