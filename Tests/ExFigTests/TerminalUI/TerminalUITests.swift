@testable import ExFigCLI
import ExFigCore
import XCTest

final class TerminalUITests: XCTestCase {
    // MARK: - Initialization

    func testInitializationWithNormalMode() {
        let ui = TerminalUI(outputMode: .normal)

        XCTAssertEqual(ui.outputMode, .normal)
    }

    func testInitializationWithVerboseMode() {
        let ui = TerminalUI(outputMode: .verbose)

        XCTAssertEqual(ui.outputMode, .verbose)
    }

    func testInitializationWithQuietMode() {
        let ui = TerminalUI(outputMode: .quiet)

        XCTAssertEqual(ui.outputMode, .quiet)
    }

    func testInitializationWithPlainMode() {
        let ui = TerminalUI(outputMode: .plain)

        XCTAssertEqual(ui.outputMode, .plain)
    }

    // MARK: - Factory Method

    func testCreateWithVerboseFlag() {
        let ui = TerminalUI.create(verbose: true, quiet: false)

        XCTAssertEqual(ui.outputMode, .verbose)
    }

    func testCreateWithQuietFlag() {
        let ui = TerminalUI.create(verbose: false, quiet: true)

        XCTAssertEqual(ui.outputMode, .quiet)
    }

    func testCreateWithBothFlags() {
        // Quiet takes priority
        let ui = TerminalUI.create(verbose: true, quiet: true)

        XCTAssertEqual(ui.outputMode, .quiet)
    }

    func testCreateWithNoFlags() {
        let ui = TerminalUI.create(verbose: false, quiet: false)

        // Should be .normal or .plain depending on TTY
        XCTAssertTrue(ui.outputMode == .normal || ui.outputMode == .plain)
    }

    // MARK: - Simple Output Methods

    func testInfoDoesNotCrash() {
        let ui = TerminalUI(outputMode: .plain)

        ui.info("Test info message")
    }

    func testInfoInQuietModeDoesNotPrint() {
        let ui = TerminalUI(outputMode: .quiet)

        // Should not crash, message is suppressed
        ui.info("This should not print")
    }

    func testSuccessDoesNotCrash() {
        let ui = TerminalUI(outputMode: .plain)

        ui.success("Test success message")
    }

    func testSuccessInQuietModeDoesNotPrint() {
        let ui = TerminalUI(outputMode: .quiet)

        ui.success("This should not print")
    }

    func testWarningDoesNotCrash() {
        let ui = TerminalUI(outputMode: .plain)

        ui.warning("Test warning message")
    }

    func testWarningInQuietModePrints() {
        let ui = TerminalUI(outputMode: .quiet)

        // Warnings should print even in quiet mode
        ui.warning("Warning message")
    }

    func testErrorDoesNotCrash() {
        let ui = TerminalUI(outputMode: .plain)

        ui.error("Test error message")
    }

    func testErrorInQuietModePrints() {
        let ui = TerminalUI(outputMode: .quiet)

        // Errors should print even in quiet mode
        ui.error("Error message")
    }

    func testDebugDoesNotCrash() {
        let ui = TerminalUI(outputMode: .verbose)

        ui.debug("Test debug message")
    }

    func testDebugInNormalModeDoesNotPrint() {
        let ui = TerminalUI(outputMode: .normal)

        // Debug only prints in verbose mode
        ui.debug("This should not print")
    }

    func testDebugInPlainModeDoesNotPrint() {
        let ui = TerminalUI(outputMode: .plain)

        ui.debug("This should not print")
    }

    // MARK: - Spinner Operations

    func testWithSpinnerInPlainMode() async {
        let ui = TerminalUI(outputMode: .plain)

        let result = await ui.withSpinner("Loading") {
            42
        }

        XCTAssertEqual(result, 42)
    }

    func testWithSpinnerInQuietMode() async {
        let ui = TerminalUI(outputMode: .quiet)

        let result = await ui.withSpinner("Loading") {
            "test"
        }

        XCTAssertEqual(result, "test")
    }

    func testWithSpinnerWithSuccessMessage() async {
        let ui = TerminalUI(outputMode: .plain)

        let result = await ui.withSpinner("Loading", successMessage: "Done!") {
            100
        }

        XCTAssertEqual(result, 100)
    }

    func testWithSpinnerWithSuccessMessageInQuietMode() async {
        let ui = TerminalUI(outputMode: .quiet)

        let result = await ui.withSpinner("Loading", successMessage: "Done!") {
            "quiet result"
        }

        XCTAssertEqual(result, "quiet result")
    }

    func testWithSpinnerThrowsError() async {
        let ui = TerminalUI(outputMode: .plain)

        do {
            _ = try await ui.withSpinner("Loading") { () -> Int in
                throw TestError.testFailure
            }
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func testWithSpinnerWithSuccessMessageThrowsError() async {
        let ui = TerminalUI(outputMode: .plain)

        do {
            _ = try await ui.withSpinner("Loading", successMessage: "Done!") { () -> Int in
                throw TestError.testFailure
            }
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    // MARK: - Progress Bar Operations

    func testWithProgressInPlainMode() async {
        let ui = TerminalUI(outputMode: .plain)

        let result = await ui.withProgress("Processing", total: 10) { progressBar in
            for i in 1 ... 10 {
                progressBar.update(current: i)
            }
            return "completed"
        }

        XCTAssertEqual(result, "completed")
    }

    func testWithProgressInQuietMode() async {
        let ui = TerminalUI(outputMode: .quiet)

        let result = await ui.withProgress("Processing", total: 5) { _ in
            42
        }

        XCTAssertEqual(result, 42)
    }

    func testWithProgressZeroTotal() async {
        let ui = TerminalUI(outputMode: .plain)

        let result = await ui.withProgress("Processing", total: 0) { _ in
            "zero total"
        }

        XCTAssertEqual(result, "zero total")
    }

    func testWithProgressThrowsError() async {
        let ui = TerminalUI(outputMode: .plain)

        do {
            _ = try await ui.withProgress("Processing", total: 10) { (_: ProgressBar) -> Int in
                throw TestError.testFailure
            }
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    // MARK: - Multi-Progress

    func testCreateMultiProgress() {
        let ui = TerminalUI(outputMode: .plain)

        let multiProgress = ui.createMultiProgress()

        XCTAssertNotNil(multiProgress)
    }

    // MARK: - Cursor Control

    func testHideCursorDoesNotCrash() {
        let ui = TerminalUI(outputMode: .plain)

        // Should not crash (no-op in plain mode)
        ui.hideCursor()
    }

    func testShowCursorDoesNotCrash() {
        let ui = TerminalUI(outputMode: .plain)

        ui.showCursor()
    }

    func testCleanupDoesNotCrash() {
        let ui = TerminalUI(outputMode: .plain)

        ui.cleanup()
    }

    // MARK: - Signal Handlers

    func testInstallSignalHandlersDoesNotCrash() {
        let ui = TerminalUI(outputMode: .plain)

        // Should be no-op in plain mode (no animations)
        ui.installSignalHandlers()
    }

    // MARK: - Colors

    func testInfoWithColors() {
        let ui = TerminalUI(outputMode: .normal)

        // Should format with colors if terminal supports it
        ui.info("Colored info")
    }

    func testSuccessWithColors() {
        let ui = TerminalUI(outputMode: .normal)

        ui.success("Colored success")
    }

    func testWarningWithColors() {
        let ui = TerminalUI(outputMode: .normal)

        ui.warning("Colored warning")
    }

    func testErrorWithColors() {
        let ui = TerminalUI(outputMode: .normal)

        ui.error("Colored error")
    }

    func testDebugWithColors() {
        let ui = TerminalUI(outputMode: .verbose)

        ui.debug("Colored debug")
    }

    // MARK: - Multi-line Warning Tests

    func testWarningMultilineDoesNotCrash() {
        let ui = TerminalUI(outputMode: .plain)

        // Multi-line warning should be handled properly
        ui.warning("Line 1\nassets[3]: a,b,c\n  item1\n  item2")
    }

    func testWarningWithColorsMultiline() {
        let ui = TerminalUI(outputMode: .normal)

        // Colors should apply to all lines
        ui.warning("Line 1\nLine 2\nLine 3")
    }
}

// MARK: - Test Helpers

private enum TestError: Error {
    case testFailure
}
