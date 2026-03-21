import Foundation
@testable import PenpotAPI
import Testing
import YYJSON

@Suite("PenpotColor Decoding")
struct PenpotColorDecodingTests {
    @Test("Decodes solid color with hex and opacity")
    func decodeSolidColor() throws {
        let json = Data("""
        {"id":"uuid-1","name":"Blue","path":"Brand/Primary","color":"#3366FF","opacity":1.0}
        """.utf8)

        let color = try YYJSONDecoder().decode(PenpotColor.self, from: json)
        #expect(color.id == "uuid-1")
        #expect(color.name == "Blue")
        #expect(color.path == "Brand/Primary")
        #expect(color.color == "#3366FF")
        #expect(color.opacity == 1.0)
    }

    @Test("Gradient color has nil hex")
    func decodeGradientColor() throws {
        let json = Data("""
        {"id":"uuid-2","name":"Gradient","path":"Effects","opacity":1.0}
        """.utf8)

        let color = try YYJSONDecoder().decode(PenpotColor.self, from: json)
        #expect(color.id == "uuid-2")
        #expect(color.name == "Gradient")
        #expect(color.color == nil)
    }

    @Test("Color without path")
    func decodeColorWithoutPath() throws {
        let json = Data("""
        {"id":"uuid-3","name":"Plain","color":"#000000"}
        """.utf8)

        let color = try YYJSONDecoder().decode(PenpotColor.self, from: json)
        #expect(color.path == nil)
        #expect(color.opacity == nil)
    }

    @Test("Color map from file response")
    func decodeColorMap() throws {
        let url = try #require(Bundle.module.url(
            forResource: "file-response",
            withExtension: "json",
            subdirectory: "Fixtures"
        ))
        let data = try Data(contentsOf: url)
        let response = try YYJSONDecoder().decode(PenpotFileResponse.self, from: data)

        let colors = response.data.colors
        #expect(colors != nil)
        #expect(colors?.count == 3)

        let blue = colors?["color-uuid-1"]
        #expect(blue?.name == "Blue")
        #expect(blue?.color == "#3366FF")

        // Gradient has no solid color
        let gradient = colors?["color-uuid-3"]
        #expect(gradient?.color == nil)
    }
}
