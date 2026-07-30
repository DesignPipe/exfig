@testable import ExFigCLI
import ExFigCore
@testable import FigmaAPI
import Logging
import XCTest

/// Tests for granular cache light/dark pairing logic in ImagesLoader.
///
/// Mirrors `IconsLoaderGranularCachePairingTests`: in single-file + `suffixDarkMode` mode a changed
/// dark node must drag its light sibling into the export, otherwise `ImagesProcessor.process(light:dark:)`
/// rejects the unpaired asset with `countMismatch(light:dark:)` and the whole config fails.
final class ImagesLoaderGranularCachePairingTests: XCTestCase {
    var mockClient: MockClient!
    var logger: Logger!

    override func setUp() {
        super.setUp()
        mockClient = MockClient()
        logger = Logger(label: "test")
    }

    override func tearDown() {
        mockClient = nil
        super.tearDown()
    }

    /// iOS illustrations — the PNG branch of `loadFromSingleFileWithGranularCache`.
    func testOnlyDarkChanged_pngBranch_includesBothVersions() async throws {
        let secondResult = try await runOnlyDarkChangedScenario(platform: .ios)

        XCTAssertFalse(secondResult.allSkipped)
        XCTAssertEqual(
            secondResult.light.count, 1,
            "light sibling must be re-exported together with the changed dark node"
        )
        XCTAssertEqual(secondResult.dark?.count, 1)
        XCTAssertEqual(secondResult.light.first?.name, "illuHome")

        assertProcessorAccepts(secondResult, platform: .ios)
    }

    /// Web illustrations — the SVG/vector branch of `loadFromSingleFileWithGranularCache`.
    func testOnlyDarkChanged_vectorBranch_includesBothVersions() async throws {
        let secondResult = try await runOnlyDarkChangedScenario(platform: .web)

        XCTAssertFalse(secondResult.allSkipped)
        XCTAssertEqual(
            secondResult.light.count, 1,
            "light sibling must be re-exported together with the changed dark node"
        )
        XCTAssertEqual(secondResult.dark?.count, 1)

        assertProcessorAccepts(secondResult, platform: .web)
    }

    // MARK: - Scenario

    /// Exports twice: cold cache, then with only the dark node of `illuHome` modified.
    private func runOnlyDarkChangedScenario(platform: Platform) async throws -> ImagesLoaderResultWithHashes {
        let components = [
            Component.make(nodeId: "1:1", name: "illuHome", frameName: "InDrive"),
            Component.make(nodeId: "1:2", name: "illuHome-dark", frameName: "InDrive"),
            Component.make(nodeId: "1:3", name: "illuCar", frameName: "InDrive"),
            Component.make(nodeId: "1:4", name: "illuCar-dark", frameName: "InDrive"),
        ]

        let nodes = makeNodeResponse(for: components)
        mockClient.setResponse(nodes, for: NodesEndpoint.self)
        mockClient.setResponse(components, for: ComponentsEndpoint.self)
        mockClient.setResponse(makeImageURLs(for: components), for: ImageEndpoint.self)

        var cache = ImageTrackingCache()
        cache.updateFileVersion(fileId: "file123", version: "v1")

        let params = PKLConfig.make(
            lightFileId: "file123", imagesFrameName: "InDrive",
            imagesSuffixDarkMode: "-dark"
        )

        let loader = ImagesLoader(client: mockClient, params: params, platform: platform, logger: logger)
        loader.granularCacheManager = GranularCacheManager(client: mockClient, cache: cache)

        let firstResult = try await loader.loadWithGranularCache()
        XCTAssertFalse(firstResult.allSkipped)
        XCTAssertEqual(firstResult.light.count, 2)
        XCTAssertEqual(firstResult.dark?.count, 2)

        for (fileId, hashes) in firstResult.computedHashes {
            cache.updateNodeHashes(fileId: fileId, hashes: hashes)
        }

        // Modify ONLY the dark version of illuHome — a designer tweak to the dark variant.
        var modifiedNodes = nodes
        modifiedNodes["1:2"] = Node.makeWithFill(
            id: "1:2", name: "illuHome-dark",
            fillColor: PaintColor(r: 1.0, g: 0.0, b: 0.0, a: 1.0)
        )
        mockClient.setResponse(modifiedNodes, for: NodesEndpoint.self)

        let loader2 = ImagesLoader(client: mockClient, params: params, platform: platform, logger: logger)
        loader2.granularCacheManager = GranularCacheManager(client: mockClient, cache: cache)

        return try await loader2.loadWithGranularCache()
    }

    // MARK: - Helpers

    /// The downstream consequence of missing pairing: `ImagesProcessor` rejects an unpaired dark asset.
    private func assertProcessorAccepts(_ result: ImagesLoaderResultWithHashes, platform: Platform) {
        let processor = ImagesProcessor(platform: platform, nameStyle: .camelCase)
        let processed = processor.process(light: result.light, dark: result.dark)
        if case let .failure(error) = processed.result {
            XCTFail("ImagesProcessor validation failed: \(error.localizedDescription)")
        }
    }

    private func makeNodeResponse(for components: [Component]) -> [NodeId: Node] {
        var nodes: [NodeId: Node] = [:]
        for component in components {
            nodes[component.nodeId] = Node.makeWithFill(
                id: component.nodeId,
                name: component.name,
                fillColor: PaintColor(r: 0.5, g: 0.5, b: 0.5, a: 1.0)
            )
        }
        return nodes
    }

    private func makeImageURLs(for components: [Component]) -> [NodeId: ImagePath?] {
        var urls: [NodeId: ImagePath?] = [:]
        for component in components {
            urls[component.nodeId] = "https://figma.com/\(component.name).png"
        }
        return urls
    }
}
