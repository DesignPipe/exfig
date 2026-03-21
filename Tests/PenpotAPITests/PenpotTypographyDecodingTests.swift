import Foundation
@testable import PenpotAPI
import Testing
import YYJSON

@Suite("PenpotTypography Decoding")
struct PenpotTypographyDecodingTests {
    @Test("String numeric values are parsed as Double")
    func decodeStringNumerics() throws {
        let json = Data((
            #"{"id":"t1","name":"Heading","fontFamily":"Roboto","# +
                #""fontSize":"24","fontWeight":"700","lineHeight":"1.5","letterSpacing":"0.02"}"#
        ).utf8)

        let typo = try YYJSONDecoder().decode(PenpotTypography.self, from: json)
        #expect(typo.fontSize == 24.0)
        #expect(typo.fontWeight == 700.0)
        #expect(typo.lineHeight == 1.5)
        #expect(typo.letterSpacing == 0.02)
    }

    @Test("JSON number values are parsed as Double")
    func decodeNumberValues() throws {
        let json = Data("""
        {"id":"t2","name":"Body","fontFamily":"Inter","fontSize":16,"fontWeight":400,"lineHeight":1.6,"letterSpacing":0}
        """.utf8)

        let typo = try YYJSONDecoder().decode(PenpotTypography.self, from: json)
        #expect(typo.fontSize == 16.0)
        #expect(typo.fontWeight == 400.0)
        #expect(typo.lineHeight == 1.6)
        #expect(typo.letterSpacing == 0.0)
    }

    @Test("Unparseable string values become nil")
    func decodeUnparseableValues() throws {
        let json = Data("""
        {"id":"t3","name":"Auto","fontFamily":"System","fontSize":"auto","fontWeight":"bold"}
        """.utf8)

        let typo = try YYJSONDecoder().decode(PenpotTypography.self, from: json)
        #expect(typo.fontSize == nil)
        #expect(typo.fontWeight == nil)
    }

    @Test("camelCase keys decode without CodingKeys")
    func decodeCamelCaseKeys() throws {
        let json = Data("""
        {"id":"t4","name":"Styled","fontFamily":"Roboto","fontStyle":"italic","textTransform":"uppercase","fontSize":14}
        """.utf8)

        let typo = try YYJSONDecoder().decode(PenpotTypography.self, from: json)
        #expect(typo.fontFamily == "Roboto")
        #expect(typo.fontStyle == "italic")
        #expect(typo.textTransform == "uppercase")
    }

    @Test("Typography map from file response")
    func decodeFromFixture() throws {
        let url = try #require(Bundle.module.url(
            forResource: "file-response",
            withExtension: "json",
            subdirectory: "Fixtures"
        ))
        let data = try Data(contentsOf: url)
        let response = try YYJSONDecoder().decode(PenpotFileResponse.self, from: data)

        let typos = response.data.typographies
        #expect(typos != nil)
        #expect(typos?.count == 2)

        // String numerics
        let heading = typos?["typo-uuid-1"]
        #expect(heading?.fontSize == 24.0)
        #expect(heading?.fontWeight == 700.0)
        #expect(heading?.textTransform == "uppercase")

        // Number values
        let body = typos?["typo-uuid-2"]
        #expect(body?.fontSize == 16.0)
        #expect(body?.fontWeight == 400.0)
    }
}
