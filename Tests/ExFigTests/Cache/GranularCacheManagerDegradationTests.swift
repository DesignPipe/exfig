@testable import ExFigCLI
@testable import FigmaAPI
import XCTest

/// Tests for GranularCacheManager graceful degradation when node fetch fails.
final class GranularCacheManagerDegradationTests: XCTestCase {
    var mockClient: MockClient!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        mockClient = MockClient()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        mockClient = nil
        super.tearDown()
    }

    func testNodeFetchErrorReturnsAllComponentsWithoutHashes() async throws {
        // Setup: Components exist but API returns error (e.g. "Access denied")
        let components = [
            Component.make(nodeId: "1:1", name: "icon_home", frameName: "Icons"),
            Component.make(nodeId: "1:2", name: "icon_settings", frameName: "Icons"),
        ]
        mockClient.setError(
            MockClientError.noResponseConfigured(endpoint: "simulated access denied"),
            for: NodesEndpoint.self
        )

        var cache = ImageTrackingCache()
        cache.updateFileVersion(fileId: "file123", version: "v1")

        let manager = GranularCacheManager(client: mockClient, cache: cache)
        let componentDict = Dictionary(uniqueKeysWithValues: components.map { ($0.nodeId, $0) })

        // Should NOT throw — degrade gracefully by returning all components
        let result = try await manager.filterChangedComponents(
            fileId: "file123",
            components: componentDict
        )

        // All components returned (no filtering), no hashes computed
        XCTAssertEqual(result.changedComponents.count, 2)
        XCTAssertTrue(result.computedHashes.isEmpty)
    }

    func testNodeFetchErrorAfterCachePopulatedStillReturnsAll() async throws {
        // Setup: First run succeeds and populates cache
        let components = [
            Component.make(nodeId: "1:1", name: "icon_home", frameName: "Icons"),
        ]
        let nodes = makeNodeResponse(for: components)
        mockClient.setResponse(nodes, for: NodesEndpoint.self)

        var cache = ImageTrackingCache()
        cache.updateFileVersion(fileId: "file123", version: "v1")

        let manager = GranularCacheManager(client: mockClient, cache: cache)
        let componentDict = Dictionary(uniqueKeysWithValues: components.map { ($0.nodeId, $0) })
        let firstResult = try await manager.filterChangedComponents(
            fileId: "file123", components: componentDict
        )
        cache.updateNodeHashes(fileId: "file123", hashes: firstResult.computedHashes)

        // Now API fails on second run
        mockClient.setError(
            MockClientError.noResponseConfigured(endpoint: "simulated access denied"),
            for: NodesEndpoint.self
        )

        let managerWithCache = GranularCacheManager(client: mockClient, cache: cache)
        let result = try await managerWithCache.filterChangedComponents(
            fileId: "file123", components: componentDict
        )

        // Should degrade: return all components, empty hashes
        XCTAssertEqual(result.changedComponents.count, 1)
        XCTAssertTrue(result.computedHashes.isEmpty)
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
