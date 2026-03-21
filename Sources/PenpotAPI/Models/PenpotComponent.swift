import Foundation

/// A library component from a Penpot file.
public struct PenpotComponent: Decodable, Sendable {
    /// Unique identifier.
    public let id: String

    /// Display name.
    public let name: String

    /// Slash-separated group path (e.g., "Icons/Navigation").
    public let path: String?

    /// ID of the main instance on the canvas.
    public let mainInstanceId: String?

    /// Page UUID where the main instance lives.
    public let mainInstancePage: String?

    public init(
        id: String,
        name: String,
        path: String? = nil,
        mainInstanceId: String? = nil,
        mainInstancePage: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.mainInstanceId = mainInstanceId
        self.mainInstancePage = mainInstancePage
    }
}
