@testable import ExFigCLI
import Noora
import XCTest

final class ExFigErrorFormatterTests: XCTestCase {
    private var formatter: ExFigErrorFormatter!

    override func setUp() {
        super.setUp()
        formatter = ExFigErrorFormatter()
    }

    // MARK: - Simple Errors (No Recovery)

    func testSimpleErrorWithoutRecovery() {
        let error = SimpleError(description: "Something went wrong")

        let result = formatter.format(error)

        XCTAssertEqual(result, "Something went wrong")
    }

    // MARK: - Errors With Recovery Suggestions

    func testErrorWithRecoverySuggestion() {
        let error = RecoverableError(
            description: "File not found",
            recovery: "Check the file path exists"
        )

        let result = formatter.format(error)

        XCTAssertEqual(result, "File not found\n  → Check the file path exists")
    }

    func testErrorWithLongRecoverySuggestion() {
        let error = RecoverableError(
            description: "Authentication failed",
            recovery: "Run: export FIGMA_PERSONAL_TOKEN=your_token"
        )

        let result = formatter.format(error)

        XCTAssertTrue(result.contains("Authentication failed"))
        XCTAssertTrue(result.contains("→"))
        XCTAssertTrue(result.contains("FIGMA_PERSONAL_TOKEN"))
    }

    // MARK: - Real Error Types

    func testExFigErrorAccessTokenNotFound() {
        let error = ExFigError.accessTokenNotFound

        let result = formatter.format(error)

        XCTAssertTrue(result.contains("FIGMA_PERSONAL_TOKEN is required"))
        XCTAssertTrue(result.contains("→"))
        XCTAssertTrue(result.contains("export FIGMA_PERSONAL_TOKEN"))
    }

    func testExFigErrorStylesNotFound() {
        let error = ExFigError.stylesNotFound

        let result = formatter.format(error)

        XCTAssertTrue(result.contains("Styles not found"))
        XCTAssertTrue(result.contains("→"))
        XCTAssertTrue(result.contains("Team Library"))
    }

    func testExFigErrorInvalidFileName() {
        let error = ExFigError.invalidFileName("icon@2x")

        let result = formatter.format(error)

        XCTAssertTrue(result.contains("Invalid file name: icon@2x"))
        XCTAssertTrue(result.contains("→"))
    }

    func testExFigErrorCustomWithoutRecovery() {
        let error = ExFigError.custom(errorString: "Custom error message")

        let result = formatter.format(error)

        XCTAssertEqual(result, "Custom error message")
        XCTAssertFalse(result.contains("→"))
    }

    // MARK: - WebP Converter Errors

    func testWebpConverterErrorFileNotFound() {
        let error = WebpConverterError.fileNotFound(path: "/tmp/image.png")

        let result = formatter.format(error)

        XCTAssertTrue(result.contains("File not found"))
        XCTAssertTrue(result.contains("/tmp/image.png"))
        XCTAssertTrue(result.contains("→"))
    }

    func testWebpConverterErrorInvalidFormat() {
        let error = WebpConverterError.invalidInputFormat(path: "corrupt.png")

        let result = formatter.format(error)

        XCTAssertTrue(result.contains("Invalid PNG format"))
        XCTAssertTrue(result.contains("→"))
    }

    // MARK: - Config Discovery Errors

    func testConfigDiscoveryErrorFileNotFound() {
        let url = URL(fileURLWithPath: "/path/to/config.pkl")
        let error = ConfigDiscoveryError.fileNotFound(url)

        let result = formatter.format(error)

        XCTAssertTrue(result.contains("Config file not found"))
        XCTAssertTrue(result.contains("→"))
    }

    // MARK: - Non-LocalizedError

    func testNonLocalizedError() {
        struct GenericError: Error {}
        let error = GenericError()

        let result = formatter.format(error)

        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Recovery Suggestion Formatting

    func testRecoverySuggestionIsOnNewLine() {
        let error = RecoverableError(
            description: "Error message",
            recovery: "Recovery suggestion"
        )

        let result = formatter.format(error)
        let lines = result.split(separator: "\n")

        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(String(lines[0]), "Error message")
        XCTAssertEqual(String(lines[1]), "  → Recovery suggestion")
    }

    func testRecoverySuggestionIndentation() {
        let error = RecoverableError(
            description: "Error",
            recovery: "Fix it"
        )

        let result = formatter.format(error)

        XCTAssertTrue(result.contains("  →"), "Recovery should have 2-space indentation")
    }
}

// MARK: - Test Helpers

private struct SimpleError: LocalizedError {
    let description: String

    var errorDescription: String? {
        description
    }
}

private struct RecoverableError: LocalizedError {
    let description: String
    let recovery: String

    var errorDescription: String? {
        description
    }

    var recoverySuggestion: String? {
        recovery
    }
}

// MARK: - TerminalText API Tests

extension ExFigErrorFormatterTests {
    func testFormatAsTerminalTextSimpleError() {
        let error = SimpleError(description: "Something went wrong")

        let text = formatter.formatAsTerminalText(error)
        let formatted = NooraUI.format(text)

        // Should contain the message
        XCTAssertTrue(formatted.contains("Something went wrong"))
    }

    func testFormatAsTerminalTextWithRecovery() {
        let error = RecoverableError(
            description: "File not found",
            recovery: "Check the file path exists"
        )

        let text = formatter.formatAsTerminalText(error)
        let formatted = NooraUI.format(text)

        // Should contain both error and recovery
        XCTAssertTrue(formatted.contains("File not found"))
        XCTAssertTrue(formatted.contains("Check the file path exists"))
    }

    func testFormatAsTerminalTextRecoveryOnNewLine() {
        let error = RecoverableError(
            description: "Error message",
            recovery: "Recovery suggestion"
        )

        let text = formatter.formatAsTerminalText(error)
        let formatted = NooraUI.format(text)
        let lines = formatted.split(separator: "\n")

        XCTAssertEqual(lines.count, 2, "Should have error and recovery on separate lines")
    }

    func testFormatAsTerminalTextProducesNonEmptyOutput() {
        let error = ExFigError.accessTokenNotFound

        let text = formatter.formatAsTerminalText(error)
        let formatted = NooraUI.format(text)

        XCTAssertFalse(formatted.isEmpty)
    }
}
