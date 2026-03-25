@testable import ExFigCore
import XCTest

final class ErrorGroupTests: XCTestCase {
    func testInitWithEmptyArray() {
        let group = ErrorGroup()

        XCTAssertTrue(group.all.isEmpty)
        XCTAssertEqual(group.errorDescription, "")
    }

    func testInitWithErrors() {
        let errors: [any Error & Sendable] = [
            TestError.first,
            TestError.second,
        ]
        let group = ErrorGroup(all: errors)

        XCTAssertEqual(group.all.count, 2)
    }

    func testAppendAddsError() {
        var group = ErrorGroup()

        group.append(TestError.first)

        XCTAssertEqual(group.all.count, 1)
    }

    func testAppendMultipleErrors() {
        var group = ErrorGroup()

        group.append(TestError.first)
        group.append(TestError.second)
        group.append(TestError.third)

        XCTAssertEqual(group.all.count, 3)
    }

    func testErrorDescriptionWithLocalizedErrors() {
        var group = ErrorGroup()
        group.append(LocalizedTestError.customMessage)
        group.append(LocalizedTestError.anotherMessage)

        let description = group.errorDescription

        XCTAssertTrue(description?.contains("Custom error message") == true)
        XCTAssertTrue(description?.contains("Another error") == true)
    }

    func testErrorDescriptionJoinsWithNewlines() {
        var group = ErrorGroup()
        group.append(LocalizedTestError.customMessage)
        group.append(LocalizedTestError.anotherMessage)

        let description = group.errorDescription ?? ""
        let lines = description.components(separatedBy: "\n")

        XCTAssertEqual(lines.count, 2)
    }

    func testErrorDescriptionWithNonLocalizedError() {
        var group = ErrorGroup()
        group.append(TestError.first)

        let description = group.errorDescription

        XCTAssertNotNil(description)
        XCTAssertFalse(description?.isEmpty == true)
    }
}

// MARK: - Test Helpers

private enum TestError: Error {
    case first
    case second
    case third
}

private enum LocalizedTestError: LocalizedError {
    case customMessage
    case anotherMessage

    var errorDescription: String? {
        switch self {
        case .customMessage:
            "Custom error message"
        case .anotherMessage:
            "Another error"
        }
    }
}
