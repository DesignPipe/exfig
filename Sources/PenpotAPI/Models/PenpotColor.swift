import Foundation

/// A library color from a Penpot file.
///
/// Solid colors have a non-nil `color` hex string. Gradient colors
/// have `nil` color and should be filtered out in v1.
public struct PenpotColor: Decodable, Sendable {
    /// Unique identifier.
    public let id: String

    /// Display name.
    public let name: String

    /// Slash-separated group path (e.g., "Brand/Primary").
    public let path: String?

    /// Hex color value (e.g., "#3366FF"). Nil for gradient fills.
    public let color: String?

    /// Opacity (0.0–1.0). Defaults to 1.0 if absent.
    public let opacity: Double?

    public init(id: String, name: String, path: String? = nil, color: String? = nil, opacity: Double? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.color = color
        self.opacity = opacity
    }
}
