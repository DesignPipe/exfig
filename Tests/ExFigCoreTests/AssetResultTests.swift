@testable import ExFigCore
import XCTest

final class AssetResultTests: XCTestCase {
    // MARK: - Success Cases

    func testSuccessWithoutWarning() {
        let color = Color(name: "primary", red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)

        let result: AssetResult<Color, Error> = .success(color)

        XCTAssertNoThrow(try result.get())
        XCTAssertNil(result.warning)
    }

    func testSuccessWithWarning() {
        let color = Color(name: "primary", red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let warning = AssetsValidatorWarning.lightAssetsNotFoundInDarkPalette(assets: ["missing"])

        let result: AssetResult<Color, Error> = .success(color, warning: warning)

        XCTAssertNoThrow(try result.get())
        XCTAssertNotNil(result.warning)
    }

    func testGetReturnsSuccessValue() throws {
        let color = Color(name: "test", red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)

        let result: AssetResult<Color, Error> = .success(color)

        let retrieved = try result.get()
        XCTAssertEqual(retrieved.name, "test")
    }

    // MARK: - Failure Cases

    func testFailure() {
        let error = TestError.sampleError

        let result: AssetResult<Color, TestError> = .failure(error)

        XCTAssertThrowsError(try result.get()) { thrownError in
            XCTAssertTrue(thrownError is TestError)
        }
        XCTAssertNil(result.warning)
    }

    func testFailureWithCustomError() {
        struct CustomError: Error, Sendable {
            let message: String
        }

        let error = CustomError(message: "Something went wrong")

        let result: AssetResult<Color, CustomError> = .failure(error)

        XCTAssertThrowsError(try result.get())
    }

    // MARK: - Generic Type Support

    func testWithArrayType() {
        let colors = [
            Color(name: "c1", red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0),
            Color(name: "c2", red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0),
        ]

        let result: AssetResult<[Color], Error> = .success(colors)

        XCTAssertNoThrow {
            let retrieved = try result.get()
            XCTAssertEqual(retrieved.count, 2)
        }
    }

    func testWithAssetPair() throws {
        let light = Color(name: "bg", red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        let pair = AssetPair(light: light, dark: nil)

        let result: AssetResult<AssetPair<Color>, Error> = .success(pair)

        let retrieved = try result.get()
        XCTAssertEqual(retrieved.light.name, "bg")
    }

    // MARK: - Warning Types

    func testWarningLightAssetsNotFoundInDarkPalette() {
        let color = Color(name: "test", red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        let warning = AssetsValidatorWarning.lightAssetsNotFoundInDarkPalette(assets: ["asset1", "asset2"])

        let result: AssetResult<Color, Error> = .success(color, warning: warning)

        if case let .lightAssetsNotFoundInDarkPalette(assets) = result.warning {
            XCTAssertEqual(assets, ["asset1", "asset2"])
        } else {
            XCTFail("Expected lightAssetsNotFoundInDarkPalette warning")
        }
    }

    func testWarningLightHCAssetsNotFoundInLightPalette() {
        let color = Color(name: "test", red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        let warning = AssetsValidatorWarning.lightHCAssetsNotFoundInLightPalette(assets: ["hc1"])

        let result: AssetResult<Color, Error> = .success(color, warning: warning)

        if case let .lightHCAssetsNotFoundInLightPalette(assets) = result.warning {
            XCTAssertEqual(assets, ["hc1"])
        } else {
            XCTFail("Expected lightHCAssetsNotFoundInLightPalette warning")
        }
    }

    func testWarningDarkHCAssetsNotFoundInDarkPalette() {
        let color = Color(name: "test", red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        let warning = AssetsValidatorWarning.darkHCAssetsNotFoundInDarkPalette(assets: ["darkhc1"])

        let result: AssetResult<Color, Error> = .success(color, warning: warning)

        if case let .darkHCAssetsNotFoundInDarkPalette(assets) = result.warning {
            XCTAssertEqual(assets, ["darkhc1"])
        } else {
            XCTFail("Expected darkHCAssetsNotFoundInDarkPalette warning")
        }
    }

    // MARK: - Sendable Conformance

    func testSendableConformance() async {
        let color = Color(name: "async", red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        let result: AssetResult<Color, Error> = .success(color)

        let name = await Task {
            // swiftlint:disable:next force_try
            try! result.get().name
        }.value

        XCTAssertEqual(name, "async")
    }
}

// MARK: - Test Helpers

private enum TestError: Error {
    case sampleError
}
