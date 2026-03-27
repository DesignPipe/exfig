@testable import ExFigCLI
import ExFigCore
@testable import FigmaAPI
import Logging
import XCTest

/// Tests for granular cache light/dark pairing logic in IconsLoader.
final class IconsLoaderGranularCachePairingTests: XCTestCase {
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

    // MARK: - Granular Cache Light/Dark Pairing

    func testOnlyDarkChanged_includesBothVersions() async throws {
        let components = [
            Component.make(nodeId: "1:1", name: "icon_home", frameName: "Icons"),
            Component.make(nodeId: "1:2", name: "icon_home-dark", frameName: "Icons"),
            Component.make(nodeId: "1:3", name: "icon_settings", frameName: "Icons"),
            Component.make(nodeId: "1:4", name: "icon_settings-dark", frameName: "Icons"),
        ]

        let nodes = makeNodeResponse(for: components)
        mockClient.setResponse(nodes, for: NodesEndpoint.self)
        mockClient.setResponse(components, for: ComponentsEndpoint.self)

        let allImageUrls: [NodeId: ImagePath?] = [
            "1:1": "https://figma.com/icon_home.pdf",
            "1:2": "https://figma.com/icon_home-dark.pdf",
            "1:3": "https://figma.com/icon_settings.pdf",
            "1:4": "https://figma.com/icon_settings-dark.pdf",
        ]
        mockClient.setResponse(allImageUrls, for: ImageEndpoint.self)

        var cache = ImageTrackingCache()
        cache.updateFileVersion(fileId: "file123", version: "v1")

        let granularManager = GranularCacheManager(client: mockClient, cache: cache)
        let params = PKLConfig.make(
            lightFileId: "file123", iconsFrameName: "Icons",
            iconsSuffixDarkMode: "-dark"
        )
        let loader = IconsLoader(client: mockClient, params: params, platform: .ios, logger: logger)
        loader.granularCacheManager = granularManager

        let firstResult = try await loader.loadWithGranularCache()
        XCTAssertFalse(firstResult.allSkipped)
        XCTAssertEqual(firstResult.light.count, 2)
        XCTAssertEqual(firstResult.dark?.count, 2)

        for (fileId, hashes) in firstResult.computedHashes {
            cache.updateNodeHashes(fileId: fileId, hashes: hashes)
        }

        // Modify ONLY dark version
        var modifiedNodes = nodes
        modifiedNodes["1:2"] = Node.makeWithFill(
            id: "1:2", name: "icon_home-dark",
            fillColor: PaintColor(r: 1.0, g: 0.0, b: 0.0, a: 1.0)
        )
        mockClient.setResponse(modifiedNodes, for: NodesEndpoint.self)

        let granularManager2 = GranularCacheManager(client: mockClient, cache: cache)
        let loader2 = IconsLoader(client: mockClient, params: params, platform: .ios, logger: logger)
        loader2.granularCacheManager = granularManager2

        let pairedImageUrls: [NodeId: ImagePath?] = [
            "1:1": "https://figma.com/icon_home.pdf",
            "1:2": "https://figma.com/icon_home-dark.pdf",
        ]
        mockClient.setResponse(pairedImageUrls, for: ImageEndpoint.self)

        let secondResult = try await loader2.loadWithGranularCache()

        XCTAssertFalse(secondResult.allSkipped)
        XCTAssertEqual(secondResult.light.count, 1)
        XCTAssertEqual(secondResult.dark?.count, 1)
        XCTAssertEqual(secondResult.light.first?.name, "icon_home")
        XCTAssertEqual(secondResult.dark?.first?.name, "icon_home")
    }

    func testOnlyLightChanged_includesBothVersions() async throws {
        let components = [
            Component.make(nodeId: "1:1", name: "icon_home", frameName: "Icons"),
            Component.make(nodeId: "1:2", name: "icon_home-dark", frameName: "Icons"),
        ]

        let nodes = makeNodeResponse(for: components)
        mockClient.setResponse(nodes, for: NodesEndpoint.self)
        mockClient.setResponse(components, for: ComponentsEndpoint.self)

        let imageUrls: [NodeId: ImagePath?] = [
            "1:1": "https://figma.com/icon_home.pdf",
            "1:2": "https://figma.com/icon_home-dark.pdf",
        ]
        mockClient.setResponse(imageUrls, for: ImageEndpoint.self)

        var cache = ImageTrackingCache()
        cache.updateFileVersion(fileId: "file123", version: "v1")

        let granularManager = GranularCacheManager(client: mockClient, cache: cache)
        let params = PKLConfig.make(
            lightFileId: "file123", iconsFrameName: "Icons",
            iconsSuffixDarkMode: "-dark"
        )
        let loader = IconsLoader(client: mockClient, params: params, platform: .ios, logger: logger)
        loader.granularCacheManager = granularManager

        let firstResult = try await loader.loadWithGranularCache()
        for (fileId, hashes) in firstResult.computedHashes {
            cache.updateNodeHashes(fileId: fileId, hashes: hashes)
        }

        var modifiedNodes = nodes
        modifiedNodes["1:1"] = Node.makeWithFill(
            id: "1:1", name: "icon_home",
            fillColor: PaintColor(r: 0.0, g: 1.0, b: 0.0, a: 1.0)
        )
        mockClient.setResponse(modifiedNodes, for: NodesEndpoint.self)

        let granularManager2 = GranularCacheManager(client: mockClient, cache: cache)
        let loader2 = IconsLoader(client: mockClient, params: params, platform: .ios, logger: logger)
        loader2.granularCacheManager = granularManager2

        let secondResult = try await loader2.loadWithGranularCache()

        XCTAssertFalse(secondResult.allSkipped)
        XCTAssertEqual(secondResult.light.count, 1)
        XCTAssertEqual(secondResult.dark?.count, 1)
    }

    func testIconWithoutDark_worksCorrectly() async throws {
        let components = [
            Component.make(nodeId: "1:1", name: "icon_solo", frameName: "Icons"),
        ]

        let nodes = makeNodeResponse(for: components)
        mockClient.setResponse(nodes, for: NodesEndpoint.self)
        mockClient.setResponse(components, for: ComponentsEndpoint.self)

        let imageUrls: [NodeId: ImagePath?] = [
            "1:1": "https://figma.com/icon_solo.pdf",
        ]
        mockClient.setResponse(imageUrls, for: ImageEndpoint.self)

        var cache = ImageTrackingCache()
        cache.updateFileVersion(fileId: "file123", version: "v1")

        let granularManager = GranularCacheManager(client: mockClient, cache: cache)
        let params = PKLConfig.make(
            lightFileId: "file123", iconsFrameName: "Icons",
            iconsSuffixDarkMode: "-dark"
        )
        let loader = IconsLoader(client: mockClient, params: params, platform: .ios, logger: logger)
        loader.granularCacheManager = granularManager

        let firstResult = try await loader.loadWithGranularCache()
        XCTAssertEqual(firstResult.light.count, 1)
        XCTAssertTrue(firstResult.dark?.isEmpty ?? true)

        for (fileId, hashes) in firstResult.computedHashes {
            cache.updateNodeHashes(fileId: fileId, hashes: hashes)
        }

        var modifiedNodes = nodes
        modifiedNodes["1:1"] = Node.makeWithFill(
            id: "1:1", name: "icon_solo",
            fillColor: PaintColor(r: 1.0, g: 0.5, b: 0.0, a: 1.0)
        )
        mockClient.setResponse(modifiedNodes, for: NodesEndpoint.self)

        let granularManager2 = GranularCacheManager(client: mockClient, cache: cache)
        let loader2 = IconsLoader(client: mockClient, params: params, platform: .ios, logger: logger)
        loader2.granularCacheManager = granularManager2

        let secondResult = try await loader2.loadWithGranularCache()

        XCTAssertFalse(secondResult.allSkipped)
        XCTAssertEqual(secondResult.light.count, 1)
        XCTAssertTrue(secondResult.dark?.isEmpty ?? true)
    }

    func testNothingChanged_skipsAll() async throws {
        let components = [
            Component.make(nodeId: "1:1", name: "icon_home", frameName: "Icons"),
            Component.make(nodeId: "1:2", name: "icon_home-dark", frameName: "Icons"),
        ]

        let nodes = makeNodeResponse(for: components)
        mockClient.setResponse(nodes, for: NodesEndpoint.self)
        mockClient.setResponse(components, for: ComponentsEndpoint.self)
        mockClient.setResponse([NodeId: ImagePath?](), for: ImageEndpoint.self)

        var cache = ImageTrackingCache()
        cache.updateFileVersion(fileId: "file123", version: "v1")

        let granularManager = GranularCacheManager(client: mockClient, cache: cache)
        let params = PKLConfig.make(
            lightFileId: "file123", iconsFrameName: "Icons",
            iconsSuffixDarkMode: "-dark"
        )
        let loader = IconsLoader(client: mockClient, params: params, platform: .ios, logger: logger)
        loader.granularCacheManager = granularManager

        let firstResult = try await loader.loadWithGranularCache()
        for (fileId, hashes) in firstResult.computedHashes {
            cache.updateNodeHashes(fileId: fileId, hashes: hashes)
        }

        let granularManager2 = GranularCacheManager(client: mockClient, cache: cache)
        let loader2 = IconsLoader(client: mockClient, params: params, platform: .ios, logger: logger)
        loader2.granularCacheManager = granularManager2

        let secondResult = try await loader2.loadWithGranularCache()

        XCTAssertTrue(secondResult.allSkipped)
        XCTAssertEqual(secondResult.light.count, 0)
    }

    // MARK: - Helpers

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
}
