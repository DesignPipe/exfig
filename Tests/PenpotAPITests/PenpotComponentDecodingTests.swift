import Foundation
@testable import PenpotAPI
import Testing
import YYJSON

@Suite("PenpotComponent Decoding")
struct PenpotComponentDecodingTests {
    @Test("Decodes component with camelCase keys")
    func decodeCamelCase() throws {
        let json = Data((
            #"{"id":"c1","name":"arrow-right","path":"Icons/Navigation","# +
                #""mainInstanceId":"inst-123","mainInstancePage":"page-456"}"#
        ).utf8)

        let comp = try YYJSONDecoder().decode(PenpotComponent.self, from: json)
        #expect(comp.id == "c1")
        #expect(comp.name == "arrow-right")
        #expect(comp.path == "Icons/Navigation")
        #expect(comp.mainInstanceId == "inst-123")
        #expect(comp.mainInstancePage == "page-456")
    }

    @Test("Component with optional fields nil")
    func decodeMinimal() throws {
        let json = Data("""
        {"id":"c2","name":"star"}
        """.utf8)

        let comp = try YYJSONDecoder().decode(PenpotComponent.self, from: json)
        #expect(comp.id == "c2")
        #expect(comp.name == "star")
        #expect(comp.path == nil)
        #expect(comp.mainInstanceId == nil)
        #expect(comp.mainInstancePage == nil)
    }

    @Test("Components map from file response")
    func decodeFromFixture() throws {
        let url = try #require(Bundle.module.url(
            forResource: "file-response",
            withExtension: "json",
            subdirectory: "Fixtures"
        ))
        let data = try Data(contentsOf: url)
        let response = try YYJSONDecoder().decode(PenpotFileResponse.self, from: data)

        let comps = response.data.components
        #expect(comps != nil)
        #expect(comps?.count == 3)

        let arrow = comps?["comp-uuid-1"]
        #expect(arrow?.name == "arrow-right")
        #expect(arrow?.mainInstanceId == "instance-123")
    }
}
