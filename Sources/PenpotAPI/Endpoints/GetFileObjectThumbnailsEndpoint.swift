import Foundation
import YYJSON

/// Retrieves thumbnail media IDs for file objects (components).
///
/// Command: `get-file-object-thumbnails`
/// Body: `{"file-id": "<uuid>", "object-ids": ["<uuid>", ...]}`
/// Response: Dictionary mapping object UUIDs to thumbnail URLs/media IDs.
public struct GetFileObjectThumbnailsEndpoint: PenpotEndpoint {
    public typealias Content = [String: String]

    public let commandName = "get-file-object-thumbnails"
    private let fileId: String
    private let objectIds: [String]

    public init(fileId: String, objectIds: [String]) {
        self.fileId = fileId
        self.objectIds = objectIds
    }

    public func body() throws -> Data? {
        // Penpot RPC uses kebab-case keys in request bodies
        let bodyDict: [String: Any] = [
            "file-id": fileId,
            "object-ids": objectIds,
        ]
        return try JSONSerialization.data(withJSONObject: bodyDict)
    }

    public func content(from data: Data) throws -> [String: String] {
        // Response is a flat object: { "<object-uuid>": "<thumbnail-url-or-media-id>" }
        try YYJSONDecoder().decode([String: String].self, from: data)
    }
}
