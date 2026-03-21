import Foundation

/// A library typography style from a Penpot file.
///
/// Numeric fields (`fontSize`, `fontWeight`, `lineHeight`, `letterSpacing`)
/// may arrive as either JSON strings (e.g., `"24"`) or JSON numbers (e.g., `24`)
/// due to Penpot's Clojure→JSON serialization. Custom `init(from:)` handles both.
public struct PenpotTypography: Sendable {
    /// Unique identifier.
    public let id: String

    /// Display name.
    public let name: String

    /// Slash-separated group path.
    public let path: String?

    /// Font family name (e.g., "Roboto").
    public let fontFamily: String

    /// Font style (e.g., "italic", "normal").
    public let fontStyle: String?

    /// Text transform (e.g., "uppercase", "lowercase", "none").
    public let textTransform: String?

    /// Font size in points.
    public var fontSize: Double?

    /// Font weight (e.g., 400, 700).
    public var fontWeight: Double?

    /// Line height multiplier.
    public var lineHeight: Double?

    /// Letter spacing in em.
    public var letterSpacing: Double?

    public init(
        id: String,
        name: String,
        path: String? = nil,
        fontFamily: String,
        fontStyle: String? = nil,
        textTransform: String? = nil,
        fontSize: Double? = nil,
        fontWeight: Double? = nil,
        lineHeight: Double? = nil,
        letterSpacing: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.fontFamily = fontFamily
        self.fontStyle = fontStyle
        self.textTransform = textTransform
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.lineHeight = lineHeight
        self.letterSpacing = letterSpacing
    }
}

extension PenpotTypography: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, name, path, fontFamily, fontStyle, textTransform
        case fontSize, fontWeight, lineHeight, letterSpacing
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decodeIfPresent(String.self, forKey: .path)
        fontFamily = try container.decode(String.self, forKey: .fontFamily)
        fontStyle = try container.decodeIfPresent(String.self, forKey: .fontStyle)
        textTransform = try container.decodeIfPresent(String.self, forKey: .textTransform)

        fontSize = Self.decodeFlexibleDouble(from: container, forKey: .fontSize)
        fontWeight = Self.decodeFlexibleDouble(from: container, forKey: .fontWeight)
        lineHeight = Self.decodeFlexibleDouble(from: container, forKey: .lineHeight)
        letterSpacing = Self.decodeFlexibleDouble(from: container, forKey: .letterSpacing)
    }

    /// Decodes a value that may be a JSON number or a JSON string containing a number.
    private static func decodeFlexibleDouble(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Double? {
        // Try as number first
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        // Try as string → Double
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
            return Double(stringValue)
        }
        return nil
    }
}
