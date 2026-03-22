@testable import ExFigCLI
import ExFigCore
import FigmaAPI
import Logging
import PenpotAPI
import XCTest

// MARK: - Helpers

private func dummyClient() -> MockClient {
    MockClient()
}

private func dummyPKLConfig() -> PKLConfig {
    // swiftlint:disable:next force_try
    try! JSONCodec.decode(
        PKLConfig.self,
        from: Data("""
        {
            "figma": {
                "lightFileId": "test-file-id"
            }
        }
        """.utf8)
    )
}

// MARK: - HexToRGBA Tests

final class HexToRGBATests: XCTestCase {
    func testValidSixDigitHex() throws {
        let result = try XCTUnwrap(PenpotColorsSource.hexToRGBA(hex: "#3366FF", opacity: 1.0))
        XCTAssertEqual(result.red, 0x33 / 255.0, accuracy: 0.001)
        XCTAssertEqual(result.green, 0x66 / 255.0, accuracy: 0.001)
        XCTAssertEqual(result.blue, 0xFF / 255.0, accuracy: 0.001)
        XCTAssertEqual(result.alpha, 1.0)
    }

    func testValidHexWithoutHashPrefix() throws {
        let result = try XCTUnwrap(PenpotColorsSource.hexToRGBA(hex: "FF0000", opacity: 0.5))
        XCTAssertEqual(result.red, 1.0, accuracy: 0.001)
        XCTAssertEqual(result.green, 0.0, accuracy: 0.001)
        XCTAssertEqual(result.blue, 0.0, accuracy: 0.001)
        XCTAssertEqual(result.alpha, 0.5)
    }

    func testBlackHex() throws {
        let result = try XCTUnwrap(PenpotColorsSource.hexToRGBA(hex: "#000000", opacity: 1.0))
        XCTAssertEqual(result.red, 0.0)
        XCTAssertEqual(result.green, 0.0)
        XCTAssertEqual(result.blue, 0.0)
    }

    func testWhiteHex() throws {
        let result = try XCTUnwrap(PenpotColorsSource.hexToRGBA(hex: "#FFFFFF", opacity: 1.0))
        XCTAssertEqual(result.red, 1.0, accuracy: 0.001)
        XCTAssertEqual(result.green, 1.0, accuracy: 0.001)
        XCTAssertEqual(result.blue, 1.0, accuracy: 0.001)
    }

    func testOpacityPassthrough() throws {
        let result = try XCTUnwrap(PenpotColorsSource.hexToRGBA(hex: "#000000", opacity: 0.75))
        XCTAssertEqual(result.alpha, 0.75)
    }

    func testInvalidHexReturnsNil() {
        XCTAssertNil(PenpotColorsSource.hexToRGBA(hex: "banana", opacity: 1.0))
    }

    func testThreeDigitHexReturnsNil() {
        XCTAssertNil(PenpotColorsSource.hexToRGBA(hex: "#F00", opacity: 1.0))
    }

    func testEightDigitHexReturnsNil() {
        XCTAssertNil(PenpotColorsSource.hexToRGBA(hex: "#3366FFCC", opacity: 1.0))
    }

    func testEmptyStringReturnsNil() {
        XCTAssertNil(PenpotColorsSource.hexToRGBA(hex: "", opacity: 1.0))
    }

    func testHexWithWhitespace() throws {
        let result = try XCTUnwrap(PenpotColorsSource.hexToRGBA(hex: "  #3366FF  ", opacity: 1.0))
        XCTAssertEqual(result.red, 0x33 / 255.0, accuracy: 0.001)
    }

    func testLowercaseHex() throws {
        let result = try XCTUnwrap(PenpotColorsSource.hexToRGBA(hex: "#aabbcc", opacity: 1.0))
        XCTAssertEqual(result.red, 0xAA / 255.0, accuracy: 0.001)
        XCTAssertEqual(result.green, 0xBB / 255.0, accuracy: 0.001)
        XCTAssertEqual(result.blue, 0xCC / 255.0, accuracy: 0.001)
    }
}

// MARK: - SourceFactory Penpot Dispatch Tests

final class SourceFactoryPenpotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // SourceFactory.createComponentsSource/.createTypographySource use ExFigCommand.terminalUI
        ExFigCommand.terminalUI = TerminalUI(outputMode: .quiet)
    }

    func testCreateColorsSourceForPenpot() throws {
        let input = ColorsSourceInput(
            sourceKind: .penpot,
            sourceConfig: PenpotColorsConfig(
                fileId: "uuid", baseURL: "https://penpot.example.com/", pathFilter: nil
            )
        )
        let ui = TerminalUI(outputMode: .quiet)
        // FigmaAPI.Client is required by the factory signature but not used for Penpot.
        // We pass a dummy client — PenpotColorsSource creates its own PenpotClient internally.
        let source = try SourceFactory.createColorsSource(for: input, client: dummyClient(), ui: ui, filter: nil)
        XCTAssert(source is PenpotColorsSource)
    }

    func testCreateComponentsSourceForPenpot() throws {
        let ui = TerminalUI(outputMode: .quiet)
        let source = try SourceFactory.createComponentsSource(
            for: .penpot,
            client: dummyClient(),
            params: dummyPKLConfig(),
            platform: .ios,
            logger: .init(label: "test"),
            filter: nil,
            ui: ui
        )
        XCTAssert(source is PenpotComponentsSource)
    }

    func testCreateTypographySourceForPenpot() throws {
        let ui = TerminalUI(outputMode: .quiet)
        let source = try SourceFactory.createTypographySource(
            for: .penpot,
            client: dummyClient(),
            ui: ui
        )
        XCTAssert(source is PenpotTypographySource)
    }

    func testUnsupportedSourceKindThrowsForColors() {
        let input = ColorsSourceInput(
            sourceKind: .tokensStudio,
            sourceConfig: PenpotColorsConfig(fileId: "x", baseURL: "x")
        )
        let ui = TerminalUI(outputMode: .quiet)
        XCTAssertThrowsError(
            try SourceFactory.createColorsSource(for: input, client: dummyClient(), ui: ui, filter: nil)
        )
    }

    func testUnsupportedSourceKindThrowsForComponents() {
        let ui = TerminalUI(outputMode: .quiet)
        XCTAssertThrowsError(
            try SourceFactory.createComponentsSource(
                for: .sketchFile,
                client: dummyClient(),
                params: dummyPKLConfig(),
                platform: .ios,
                logger: .init(label: "test"),
                filter: nil,
                ui: ui
            )
        )
    }

    func testUnsupportedSourceKindThrowsForTypography() {
        let ui = TerminalUI(outputMode: .quiet)
        XCTAssertThrowsError(
            try SourceFactory.createTypographySource(for: .tokensStudio, client: dummyClient(), ui: ui)
        )
    }
}

// MARK: - PenpotComponentsSource FileId Validation Tests

final class PenpotComponentsSourceValidationTests: XCTestCase {
    func testLoadIconsThrowsWhenFileIdIsNil() async {
        let source = PenpotComponentsSource(ui: TerminalUI(outputMode: .quiet))
        let input = IconsSourceInput(
            sourceKind: .penpot,
            figmaFileId: nil,
            frameName: "Icons"
        )
        do {
            _ = try await source.loadIcons(from: input)
            XCTFail("Expected error for nil fileId")
        } catch {
            XCTAssertTrue(
                "\(error)".contains("file ID"),
                "Error should mention file ID, got: \(error)"
            )
        }
    }

    func testLoadIconsThrowsWhenFileIdIsEmpty() async {
        let source = PenpotComponentsSource(ui: TerminalUI(outputMode: .quiet))
        let input = IconsSourceInput(
            sourceKind: .penpot,
            figmaFileId: "",
            frameName: "Icons"
        )
        do {
            _ = try await source.loadIcons(from: input)
            XCTFail("Expected error for empty fileId")
        } catch {
            XCTAssertTrue(
                "\(error)".contains("file ID"),
                "Error should mention file ID, got: \(error)"
            )
        }
    }

    func testLoadImagesThrowsWhenFileIdIsNil() async {
        let source = PenpotComponentsSource(ui: TerminalUI(outputMode: .quiet))
        let input = ImagesSourceInput(
            sourceKind: .penpot,
            figmaFileId: nil,
            frameName: "Images"
        )
        do {
            _ = try await source.loadImages(from: input)
            XCTFail("Expected error for nil fileId")
        } catch {
            XCTAssertTrue(
                "\(error)".contains("file ID"),
                "Error should mention file ID, got: \(error)"
            )
        }
    }
}
