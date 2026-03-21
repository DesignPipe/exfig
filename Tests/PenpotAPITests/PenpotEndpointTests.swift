import Foundation
@testable import PenpotAPI
import Testing
import YYJSON

@Suite("Penpot Endpoint")
struct PenpotEndpointTests {
    @Test("GetFileEndpoint produces correct command name")
    func getFileCommandName() {
        let endpoint = GetFileEndpoint(fileId: "test-uuid")
        #expect(endpoint.commandName == "get-file")
    }

    @Test("GetFileEndpoint body contains file ID")
    func getFileBody() throws {
        let endpoint = GetFileEndpoint(fileId: "abc-123")
        let body = try #require(try endpoint.body())
        let json = try JSONSerialization.jsonObject(with: body) as? [String: String]
        #expect(json?["id"] == "abc-123")
    }

    @Test("GetProfileEndpoint has no body")
    func getProfileNoBody() throws {
        let endpoint = GetProfileEndpoint()
        #expect(endpoint.commandName == "get-profile")
        let body = try endpoint.body()
        #expect(body == nil)
    }

    @Test("GetFileObjectThumbnailsEndpoint body has kebab-case keys")
    func thumbnailsBody() throws {
        let endpoint = GetFileObjectThumbnailsEndpoint(
            fileId: "file-uuid",
            objectIds: ["obj-1", "obj-2"]
        )
        #expect(endpoint.commandName == "get-file-object-thumbnails")

        let body = try #require(try endpoint.body())
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(json?["file-id"] as? String == "file-uuid")
        #expect((json?["object-ids"] as? [String])?.count == 2)
    }
}
