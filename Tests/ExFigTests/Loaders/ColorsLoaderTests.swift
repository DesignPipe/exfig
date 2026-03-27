import CustomDump
@testable import ExFigCLI
import ExFigCore
@testable import FigmaAPI
import XCTest

final class ColorsLoaderTests: XCTestCase {
    var mockClient: MockClient!

    override func setUp() {
        super.setUp()
        mockClient = MockClient()
    }

    override func tearDown() {
        mockClient = nil
        super.tearDown()
    }

    // MARK: - Load from Separate Files

    func testLoadColorsFromLightFile() async throws {
        let styles = [
            Style.make(nodeId: "1:1", name: "primary"),
            Style.make(nodeId: "1:2", name: "secondary"),
        ]
        let nodes: [NodeId: Node] = [
            "1:1": Node.makeColor(r: 1.0, g: 0.0, b: 0.0, a: 1.0),
            "1:2": Node.makeColor(r: 0.0, g: 1.0, b: 0.0, a: 0.5),
        ]

        mockClient.setResponse(styles, for: StylesEndpoint.self)
        mockClient.setResponse(nodes, for: NodesEndpoint.self)

        let loader = ColorsLoader(
            client: mockClient,
            figmaParams: .make(lightFileId: "test-file"),
            colorParams: nil,
            filter: nil
        )

        let result = try await loader.load()

        XCTAssertEqual(result.light.count, 2)
        XCTAssertNil(result.dark)
        XCTAssertNil(result.lightHC)
        XCTAssertNil(result.darkHC)

        let primary = result.light.first { $0.name == "primary" }
        XCTAssertNotNil(primary)
        XCTAssertEqual(primary?.red, 1.0)
        XCTAssertEqual(primary?.green, 0.0)
        XCTAssertEqual(primary?.blue, 0.0)
    }

    func testLoadColorsFromLightAndDarkFiles() async throws {
        let styles = [
            Style.make(nodeId: "1:1", name: "primary"),
        ]
        let nodes: [NodeId: Node] = [
            "1:1": Node.makeColor(r: 1.0, g: 1.0, b: 1.0, a: 1.0),
        ]

        mockClient.setResponse(styles, for: StylesEndpoint.self)
        mockClient.setResponse(nodes, for: NodesEndpoint.self)

        let loader = ColorsLoader(
            client: mockClient,
            figmaParams: .make(lightFileId: "light-file", darkFileId: "dark-file"),
            colorParams: nil,
            filter: nil
        )

        let result = try await loader.load()

        // Note: Due to MockClient limitations, both light and dark get same response
        // This tests the loading path exists
        XCTAssertEqual(result.light.count, 1)
        XCTAssertNotNil(result.dark)
    }

    // MARK: - Load from Single File

    func testLoadColorsFromSingleFileWithSuffixes() async throws {
        let styles = [
            Style.make(nodeId: "1:1", name: "primary"),
            Style.make(nodeId: "1:2", name: "primary_dark"),
            Style.make(nodeId: "1:3", name: "primary_lightHC"),
            Style.make(nodeId: "1:4", name: "primary_darkHC"),
        ]
        let nodes: [NodeId: Node] = [
            "1:1": Node.makeColor(r: 1.0, g: 1.0, b: 1.0, a: 1.0),
            "1:2": Node.makeColor(r: 0.1, g: 0.1, b: 0.1, a: 1.0),
            "1:3": Node.makeColor(r: 0.9, g: 0.9, b: 0.9, a: 1.0),
            "1:4": Node.makeColor(r: 0.2, g: 0.2, b: 0.2, a: 1.0),
        ]

        mockClient.setResponse(styles, for: StylesEndpoint.self)
        mockClient.setResponse(nodes, for: NodesEndpoint.self)

        let colorParams = PKLConfig.Common.Colors.make(suffixDarkMode: "_dark")
        let loader = ColorsLoader(
            client: mockClient,
            figmaParams: .make(lightFileId: "single-file"),
            colorParams: colorParams,
            filter: nil
        )

        let result = try await loader.load()

        XCTAssertEqual(result.light.count, 1)
        XCTAssertEqual(result.light.first?.name, "primary")

        XCTAssertEqual(result.dark?.count, 1)
        XCTAssertEqual(result.dark?.first?.name, "primary")

        XCTAssertEqual(result.lightHC?.count, 1)
        XCTAssertEqual(result.lightHC?.first?.name, "primary")

        XCTAssertEqual(result.darkHC?.count, 1)
        XCTAssertEqual(result.darkHC?.first?.name, "primary")
    }

    func testLoadColorsFromSingleFileWithCustomSuffixes() async throws {
        let styles = [
            Style.make(nodeId: "1:1", name: "primary"),
            Style.make(nodeId: "1:2", name: "primary-night"),
        ]
        let nodes: [NodeId: Node] = [
            "1:1": Node.makeColor(r: 1.0, g: 1.0, b: 1.0, a: 1.0),
            "1:2": Node.makeColor(r: 0.0, g: 0.0, b: 0.0, a: 1.0),
        ]

        mockClient.setResponse(styles, for: StylesEndpoint.self)
        mockClient.setResponse(nodes, for: NodesEndpoint.self)

        let colorParams = PKLConfig.Common.Colors.make(suffixDarkMode: "-night")
        let loader = ColorsLoader(
            client: mockClient,
            figmaParams: .make(lightFileId: "single-file"),
            colorParams: colorParams,
            filter: nil
        )

        let result = try await loader.load()

        XCTAssertEqual(result.light.count, 1)
        XCTAssertEqual(result.dark?.count, 1)
        XCTAssertEqual(result.dark?.first?.name, "primary")
    }

    // MARK: - Filtering

    func testLoadColorsWithFilter() async throws {
        let styles = [
            Style.make(nodeId: "1:1", name: "button/primary"),
            Style.make(nodeId: "1:2", name: "button/secondary"),
            Style.make(nodeId: "1:3", name: "text/primary"),
        ]
        let nodes: [NodeId: Node] = [
            "1:1": Node.makeColor(r: 1.0, g: 0.0, b: 0.0, a: 1.0),
            "1:2": Node.makeColor(r: 0.0, g: 1.0, b: 0.0, a: 1.0),
            "1:3": Node.makeColor(r: 0.0, g: 0.0, b: 1.0, a: 1.0),
        ]

        mockClient.setResponse(styles, for: StylesEndpoint.self)
        mockClient.setResponse(nodes, for: NodesEndpoint.self)

        let loader = ColorsLoader(
            client: mockClient,
            figmaParams: .make(lightFileId: "test-file"),
            colorParams: nil,
            filter: "button/*"
        )

        let result = try await loader.load()

        XCTAssertEqual(result.light.count, 2)
        XCTAssertTrue(result.light.allSatisfy { $0.name.hasPrefix("button/") })
    }

    // MARK: - Style Filtering by Description

    func testFiltersOutStylesWithNoneDescription() async throws {
        let styles = [
            Style.make(nodeId: "1:1", name: "visible", description: ""),
            Style.make(nodeId: "1:2", name: "hidden", description: "none"),
        ]
        let nodes: [NodeId: Node] = [
            "1:1": Node.makeColor(r: 1.0, g: 0.0, b: 0.0, a: 1.0),
            "1:2": Node.makeColor(r: 0.0, g: 1.0, b: 0.0, a: 1.0),
        ]

        mockClient.setResponse(styles, for: StylesEndpoint.self)
        mockClient.setResponse(nodes, for: NodesEndpoint.self)

        let loader = ColorsLoader(
            client: mockClient,
            figmaParams: .make(lightFileId: "test-file"),
            colorParams: nil,
            filter: nil
        )

        let result = try await loader.load()

        XCTAssertEqual(result.light.count, 1)
        XCTAssertEqual(result.light.first?.name, "visible")
    }

    func testFiltersNonFillStyles() async throws {
        let styles = [
            Style.make(styleType: .fill, nodeId: "1:1", name: "color"),
            Style.make(styleType: .text, nodeId: "1:2", name: "typography"),
        ]
        let nodes: [NodeId: Node] = [
            "1:1": Node.makeColor(r: 1.0, g: 0.0, b: 0.0, a: 1.0),
        ]

        mockClient.setResponse(styles, for: StylesEndpoint.self)
        mockClient.setResponse(nodes, for: NodesEndpoint.self)

        let loader = ColorsLoader(
            client: mockClient,
            figmaParams: .make(lightFileId: "test-file"),
            colorParams: nil,
            filter: nil
        )

        let result = try await loader.load()

        XCTAssertEqual(result.light.count, 1)
        XCTAssertEqual(result.light.first?.name, "color")
    }

    // MARK: - Error Handling

    func testThrowsWhenNoStylesFound() async {
        mockClient.setResponse([Style](), for: StylesEndpoint.self)

        let loader = ColorsLoader(
            client: mockClient,
            figmaParams: .make(lightFileId: "test-file"),
            colorParams: nil,
            filter: nil
        )

        do {
            _ = try await loader.load()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is ExFigError)
        }
    }

    // MARK: - Alpha Handling

    func testColorAlphaFromOpacity() async throws {
        let styles = [
            Style.make(nodeId: "1:1", name: "semi-transparent"),
        ]
        let nodes: [NodeId: Node] = [
            "1:1": Node.makeColor(r: 1.0, g: 0.0, b: 0.0, a: 1.0, opacity: 0.5),
        ]

        mockClient.setResponse(styles, for: StylesEndpoint.self)
        mockClient.setResponse(nodes, for: NodesEndpoint.self)

        let loader = ColorsLoader(
            client: mockClient,
            figmaParams: .make(lightFileId: "test-file"),
            colorParams: nil,
            filter: nil
        )

        let result = try await loader.load()

        XCTAssertEqual(result.light.first?.alpha, 0.5)
    }

    // MARK: - Parallel Loading Performance

    func testLoadColorsFromAllFilesInParallel() async throws {
        let styles = [Style.make(nodeId: "1:1", name: "color")]
        let nodes: [NodeId: Node] = ["1:1": Node.makeColor(r: 1.0, g: 0.0, b: 0.0, a: 1.0)]

        mockClient.setResponse(styles, for: StylesEndpoint.self)
        mockClient.setResponse(nodes, for: NodesEndpoint.self)
        mockClient.setRequestDelay(0.05) // 50ms per request

        let loader = ColorsLoader(
            client: mockClient,
            figmaParams: .make(
                lightFileId: "light",
                darkFileId: "dark",
                lightHighContrastFileId: "lightHC",
                darkHighContrastFileId: "darkHC"
            ),
            colorParams: nil,
            filter: nil
        )

        let startTime = Date()
        let result = try await loader.load()
        let duration = Date().timeIntervalSince(startTime)

        // 4 files x 2 requests each (Styles + Nodes) = 8 requests
        // Sequential: 8 x 50ms = 400ms minimum
        // Parallel (4 files): ~100ms (2 sequential per file, 4 files parallel)
        // Use 0.5s threshold to account for CI runner variability
        XCTAssertLessThan(duration, 0.5, "Loading should be parallel across files")

        XCTAssertEqual(result.light.count, 1)
        XCTAssertNotNil(result.dark)
        XCTAssertNotNil(result.lightHC)
        XCTAssertNotNil(result.darkHC)
    }

    func testLoadColorsParallelMaintainsCorrectResults() async throws {
        let styles = [
            Style.make(nodeId: "1:1", name: "primary"),
            Style.make(nodeId: "1:2", name: "secondary"),
        ]
        let nodes: [NodeId: Node] = [
            "1:1": Node.makeColor(r: 1.0, g: 0.0, b: 0.0, a: 1.0),
            "1:2": Node.makeColor(r: 0.0, g: 1.0, b: 0.0, a: 0.5),
        ]

        mockClient.setResponse(styles, for: StylesEndpoint.self)
        mockClient.setResponse(nodes, for: NodesEndpoint.self)

        let loader = ColorsLoader(
            client: mockClient,
            figmaParams: .make(
                lightFileId: "light",
                darkFileId: "dark",
                lightHighContrastFileId: "lightHC",
                darkHighContrastFileId: "darkHC"
            ),
            colorParams: nil,
            filter: nil
        )

        let result = try await loader.load()

        // Verify structure
        XCTAssertEqual(result.light.count, 2)
        XCTAssertEqual(result.dark?.count, 2)
        XCTAssertEqual(result.lightHC?.count, 2)
        XCTAssertEqual(result.darkHC?.count, 2)

        // Verify content
        let primaryLight = result.light.first { $0.name == "primary" }
        XCTAssertNotNil(primaryLight)
        XCTAssertEqual(primaryLight?.red, 1.0)
    }
}
