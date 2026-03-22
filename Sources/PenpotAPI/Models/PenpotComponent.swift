import Foundation

/// A library component from a Penpot file.
public struct PenpotComponent: Decodable, Sendable {
    /// Unique identifier.
    public let id: String

    /// Display name.
    public let name: String

    /// Slash-separated group path (e.g., "Icons/Navigation").
    public let path: String?

    public init(
        id: String,
        name: String,
        path: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
    }
}
