import Foundation
import YYJSON

/// Retrieves a complete Penpot file with library assets.
///
/// Command: `get-file`
/// Body: `{"id": "<file-uuid>"}`
public struct GetFileEndpoint: PenpotEndpoint {
    public typealias Content = PenpotFileResponse

    public let commandName = "get-file"
    private let fileId: String

    public init(fileId: String) {
        self.fileId = fileId
    }

    public func body() throws -> Data? {
        try YYJSONEncoder().encode(["id": fileId])
    }

    public func content(from data: Data) throws -> PenpotFileResponse {
        try YYJSONDecoder().decode(PenpotFileResponse.self, from: data)
    }
}
