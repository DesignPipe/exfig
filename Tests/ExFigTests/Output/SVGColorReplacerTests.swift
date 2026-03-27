@testable import ExFigCLI
import XCTest

final class SVGColorReplacerTests: XCTestCase {
    // MARK: - Helpers

    private func opaque(_ hex: String) -> ColorReplacement {
        ColorReplacement(hex: hex, alpha: 1.0)
    }

    private func transparent(_ hex: String, alpha: Double = 0.0) -> ColorReplacement {
        ColorReplacement(hex: hex, alpha: alpha)
    }

    // MARK: - Basic Replacement (opaque)

    func testReplacesHexInFillAttribute() {
        let svg = "<rect fill=\"#ff0000\" />"
        let result = SVGColorReplacer.replaceColors(in: svg, colorMap: ["ff0000": opaque("00ff00")])
        XCTAssertEqual(result, "<rect fill=\"#00ff00\" />")
    }

    func testReplacesHexInStrokeAttribute() {
        let svg = "<path stroke=\"#aabbcc\" />"
        let result = SVGColorReplacer.replaceColors(in: svg, colorMap: ["aabbcc": opaque("112233")])
        XCTAssertEqual(result, "<path stroke=\"#112233\" />")
    }

    func testReplacesHexInStopColorAttribute() {
        let svg = "<stop stop-color=\"#ff00ff\" />"
        let result = SVGColorReplacer.replaceColors(in: svg, colorMap: ["ff00ff": opaque("00ffff")])
        XCTAssertEqual(result, "<stop stop-color=\"#00ffff\" />")
    }

    // MARK: - Case Insensitive

    func testCaseInsensitiveMatch() {
        let svg = "<rect fill=\"#AABBCC\" />"
        let result = SVGColorReplacer.replaceColors(in: svg, colorMap: ["aabbcc": opaque("112233")])
        XCTAssertEqual(result, "<rect fill=\"#112233\" />")
    }

    // MARK: - CSS Style Properties

    func testReplacesCSSFillProperty() {
        let svg = "<rect style=\"fill:#ff0000;stroke:#00ff00\" />"
        let result = SVGColorReplacer.replaceColors(
            in: svg,
            colorMap: ["ff0000": opaque("111111"), "00ff00": opaque("222222")]
        )
        XCTAssertTrue(result.contains("fill:#111111"))
        XCTAssertTrue(result.contains("stroke:#222222"))
    }

    // MARK: - Multiple Colors

    func testReplacesMultipleColors() {
        let svg = """
        <svg>
          <rect fill="#ff0000" />
          <circle fill="#00ff00" />
          <path stroke="#0000ff" />
        </svg>
        """
        let result = SVGColorReplacer.replaceColors(
            in: svg,
            colorMap: ["ff0000": opaque("111111"), "00ff00": opaque("222222"), "0000ff": opaque("333333")]
        )
        XCTAssertTrue(result.contains("#111111"))
        XCTAssertTrue(result.contains("#222222"))
        XCTAssertTrue(result.contains("#333333"))
        XCTAssertFalse(result.contains("#ff0000"))
        XCTAssertFalse(result.contains("#00ff00"))
        XCTAssertFalse(result.contains("#0000ff"))
    }

    // MARK: - No Match

    func testEmptyColorMapReturnsOriginal() {
        let svg = "<rect fill=\"#ff0000\" />"
        let result = SVGColorReplacer.replaceColors(in: svg, colorMap: [:])
        XCTAssertEqual(result, svg)
    }

    func testNoMatchingColorsReturnsOriginal() {
        let svg = "<rect fill=\"#ff0000\" />"
        let result = SVGColorReplacer.replaceColors(in: svg, colorMap: ["aabbcc": opaque("112233")])
        XCTAssertEqual(result, svg)
    }

    // MARK: - Color Normalization

    func testNormalizeColorFromRGBA() {
        XCTAssertEqual(SVGColorReplacer.normalizeColor(r: 1.0, g: 0.0, b: 0.0), "ff0000")
        XCTAssertEqual(SVGColorReplacer.normalizeColor(r: 0.0, g: 1.0, b: 0.0), "00ff00")
        XCTAssertEqual(SVGColorReplacer.normalizeColor(r: 0.0, g: 0.0, b: 1.0), "0000ff")
        XCTAssertEqual(SVGColorReplacer.normalizeColor(r: 0.0, g: 0.0, b: 0.0), "000000")
        XCTAssertEqual(SVGColorReplacer.normalizeColor(r: 1.0, g: 1.0, b: 1.0), "ffffff")
    }

    func testNormalizeColorClampsValues() {
        XCTAssertEqual(SVGColorReplacer.normalizeColor(r: 1.5, g: -0.1, b: 0.5), "ff0080")
    }

    func testNormalizeColorFractionalValues() {
        // 0.2 * 255 = 51 = 0x33
        XCTAssertEqual(SVGColorReplacer.normalizeColor(r: 0.2, g: 0.2, b: 0.2), "333333")
    }

    // MARK: - Alpha / Opacity

    func testFillWithZeroAlphaAddsFillOpacity() {
        let svg = "<rect fill=\"#d6fb94\" />"
        let result = SVGColorReplacer.replaceColors(in: svg, colorMap: ["d6fb94": transparent("d6fb94")])
        XCTAssertTrue(result.contains("fill-opacity=\"0\""), "Expected fill-opacity=\"0\" in: \(result)")
    }

    func testStrokeWithZeroAlphaAddsStrokeOpacity() {
        let svg = "<path stroke=\"#aabbcc\" />"
        let result = SVGColorReplacer.replaceColors(in: svg, colorMap: ["aabbcc": transparent("112233")])
        XCTAssertTrue(result.contains("stroke=\"#112233\""), "Hex should be replaced")
        XCTAssertTrue(result.contains("stroke-opacity=\"0\""), "Expected stroke-opacity in: \(result)")
    }

    func testPartialAlphaAddsFillOpacity() {
        let svg = "<rect fill=\"#ff0000\" />"
        let result = SVGColorReplacer.replaceColors(in: svg, colorMap: ["ff0000": transparent("00ff00", alpha: 0.5)])
        XCTAssertTrue(result.contains("fill=\"#00ff00\""))
        XCTAssertTrue(result.contains("fill-opacity=\"0.5\""), "Expected fill-opacity in: \(result)")
    }

    func testStopColorWithZeroAlphaAddsStopOpacity() {
        let svg = "<stop stop-color=\"#ff00ff\" />"
        let result = SVGColorReplacer.replaceColors(in: svg, colorMap: ["ff00ff": transparent("00ffff")])
        XCTAssertTrue(result.contains("stop-color=\"#00ffff\""))
        XCTAssertTrue(result.contains("stop-opacity=\"0\""), "Expected stop-opacity in: \(result)")
    }

    func testCSSFillWithAlphaAddsFillOpacity() {
        let svg = "<rect style=\"fill:#ff0000\" />"
        let result = SVGColorReplacer.replaceColors(in: svg, colorMap: ["ff0000": transparent("00ff00")])
        XCTAssertTrue(result.contains("fill:#00ff00"), "Hex should be replaced")
        XCTAssertTrue(result.contains("fill-opacity:0"), "Expected fill-opacity in CSS: \(result)")
    }

    func testCSSStrokeWithAlphaAddsStrokeOpacity() {
        let svg = "<path style=\"stroke:#aabbcc\" />"
        let result = SVGColorReplacer.replaceColors(in: svg, colorMap: ["aabbcc": transparent("112233")])
        XCTAssertTrue(result.contains("stroke:#112233"))
        XCTAssertTrue(result.contains("stroke-opacity:0"), "Expected stroke-opacity in CSS: \(result)")
    }

    func testOpaqueAlphaDoesNotAddOpacity() {
        let svg = "<rect fill=\"#ff0000\" />"
        let result = SVGColorReplacer.replaceColors(in: svg, colorMap: ["ff0000": opaque("00ff00")])
        XCTAssertEqual(result, "<rect fill=\"#00ff00\" />")
        XCTAssertFalse(result.contains("opacity"))
    }

    func testSameHexDifferentAlphaStillReplaces() {
        // Same hex but dark has alpha=0: should add opacity even though hex matches
        let svg = "<rect fill=\"#d6fb94\" />"
        let result = SVGColorReplacer.replaceColors(in: svg, colorMap: ["d6fb94": transparent("d6fb94")])
        XCTAssertTrue(result.contains("fill-opacity=\"0\""), "Should add opacity even when hex is the same: \(result)")
    }

    // MARK: - flood-color / lighting-color

    func testReplacesFloodColorAttribute() {
        let svg = "<feFlood flood-color=\"#ff0000\" />"
        let result = SVGColorReplacer.replaceColors(in: svg, colorMap: ["ff0000": opaque("00ff00")])
        XCTAssertEqual(result, "<feFlood flood-color=\"#00ff00\" />")
    }

    func testReplacesLightingColorAttribute() {
        let svg = "<feDiffuseLighting lighting-color=\"#aabbcc\" />"
        let result = SVGColorReplacer.replaceColors(in: svg, colorMap: ["aabbcc": opaque("112233")])
        XCTAssertEqual(result, "<feDiffuseLighting lighting-color=\"#112233\" />")
    }

    // MARK: - ColorReplacement

    func testColorReplacementChangesOpacity() {
        XCTAssertTrue(ColorReplacement(hex: "ff0000", alpha: 0.0).changesOpacity)
        XCTAssertTrue(ColorReplacement(hex: "ff0000", alpha: 0.5).changesOpacity)
        XCTAssertFalse(ColorReplacement(hex: "ff0000", alpha: 1.0).changesOpacity)
        XCTAssertFalse(ColorReplacement(hex: "ff0000", alpha: 0.999).changesOpacity)
    }
}
