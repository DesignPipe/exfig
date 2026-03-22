import Foundation

/// A library component from a Penpot file.
public struct PenpotComponent: Decodable, Sendable {
    /// Unique identifier.
    public let id: String

    /// Display name.
    public let name: String

    /// Slash-separated group path (e.g., "Icons/Navigation").
    public let path: String?

    /// Main instance location on the canvas (both or neither present).
    /// Needed for SVG reconstruction from the shape tree.
    public let mainInstance: MainInstance?

    /// Convenience accessors for backward compatibility.
    public var mainInstanceId: String? {
        mainInstance?.id
    }

    public var mainInstancePage: String? {
        mainInstance?.page
    }

    /// Paired instance ID and page UUID for shape tree lookup.
    public struct MainInstance: Sendable, Equatable {
        public let id: String
        public let page: String

        public init(id: String, page: String) {
            self.id = id
            self.page = page
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, path, mainInstanceId, mainInstancePage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decodeIfPresent(String.self, forKey: .path)
        let instanceId = try container.decodeIfPresent(String.self, forKey: .mainInstanceId)
        let instancePage = try container.decodeIfPresent(String.self, forKey: .mainInstancePage)
        if let instanceId, let instancePage {
            mainInstance = MainInstance(id: instanceId, page: instancePage)
        } else {
            mainInstance = nil
        }
    }

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
        if let mainInstanceId, let mainInstancePage {
            mainInstance = MainInstance(id: mainInstanceId, page: mainInstancePage)
        } else {
            mainInstance = nil
        }
    }
}
