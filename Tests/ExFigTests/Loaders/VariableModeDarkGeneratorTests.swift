// swiftlint:disable file_length
@testable import ExFigCLI
import ExFigCore
import FigmaAPI
import Logging
import XCTest

// MARK: - Mock Client

private final class MockFigmaClient: Client, @unchecked Sendable {
    var requestCount = 0

    func request<T: Endpoint>(_: T) async throws -> T.Content {
        requestCount += 1
        fatalError("MockFigmaClient should not make real requests in unit tests")
    }
}

private func makeGenerator() -> VariableModeDarkGenerator {
    VariableModeDarkGenerator(
        client: MockFigmaClient(),
        logger: Logger(label: "test")
    )
}

// MARK: - findModeIds & resolveDarkColor Tests

final class VariableModeDarkGeneratorResolutionTests: XCTestCase {
    private var generator: VariableModeDarkGenerator!

    override func setUp() {
        super.setUp()
        generator = makeGenerator()
    }

    // MARK: - findModeIds

    func testFindModeIdsMatchesCollectionAndModes() {
        let meta = VariablesMeta.make(
            collectionName: "Theme",
            modes: [("m1", "Light"), ("m2", "Dark")],
            variables: []
        )
        let config = VariableModeDarkGenerator.Config(
            fileId: "file1",
            collectionName: "Theme",
            lightModeName: "Light",
            darkModeName: "Dark"
        )

        let result = generator.findModeIds(in: meta, config: config)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.lightModeId, "m1")
        XCTAssertEqual(result?.darkModeId, "m2")
        XCTAssertNil(result?.primitivesModeId)
    }

    func testFindModeIdsReturnsNilWhenCollectionMissing() {
        let meta = VariablesMeta.make(
            collectionName: "Theme",
            modes: [("m1", "Light"), ("m2", "Dark")],
            variables: []
        )
        let config = VariableModeDarkGenerator.Config(
            fileId: "file1",
            collectionName: "NonExistent",
            lightModeName: "Light",
            darkModeName: "Dark"
        )

        XCTAssertNil(generator.findModeIds(in: meta, config: config))
    }

    func testFindModeIdsReturnsNilWhenModeMissing() {
        let meta = VariablesMeta.make(
            collectionName: "Theme",
            modes: [("m1", "Light"), ("m2", "Dim")],
            variables: []
        )
        let config = VariableModeDarkGenerator.Config(
            fileId: "file1",
            collectionName: "Theme",
            lightModeName: "Light",
            darkModeName: "Dark"
        )

        XCTAssertNil(generator.findModeIds(in: meta, config: config))
    }

    func testFindModeIdsWithPrimitivesMode() {
        let meta = VariablesMeta.make(
            collectionName: "Theme",
            modes: [("m1", "Light"), ("m2", "Dark"), ("m3", "Primitives")],
            variables: []
        )
        let config = VariableModeDarkGenerator.Config(
            fileId: "file1",
            collectionName: "Theme",
            lightModeName: "Light",
            darkModeName: "Dark",
            primitivesModeName: "Primitives"
        )

        let result = generator.findModeIds(in: meta, config: config)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.primitivesModeId, "m3")
    }

    // MARK: - resolveDarkColor: Direct color

    func testResolveDarkColorDirectColor() {
        let meta = VariablesMeta.make(
            collectionName: "Theme",
            modes: [("light", "Light"), ("dark", "Dark")],
            variables: [
                (id: "v1", name: "primary", valuesByMode: [
                    "light": (r: 1.0, g: 0.0, b: 0.0, a: 1.0),
                    "dark": (r: 0.0, g: 0.0, b: 1.0, a: 1.0),
                ]),
            ]
        )

        let result = generator.resolveDarkColor(
            variableId: "VariableID:v1",
            modeId: "dark",
            variablesMeta: meta,
            primitivesModeId: nil
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.hex, "0000ff")
        XCTAssertEqual(result?.alpha, 1.0)
    }

    // MARK: - resolveDarkColor: Alias chain

    func testResolveDarkColorFollowsAlias() {
        let meta = VariablesMeta.makeWithAliases(
            collectionName: "Theme",
            modes: [("light", "Light"), ("dark", "Dark")],
            variables: [
                (id: "semantic", name: "primary", collectionId: nil, valuesByMode: [
                    "light": .color(r: 1.0, g: 0.0, b: 0.0, a: 1.0),
                    "dark": .alias("primitive"),
                ]),
                (id: "primitive", name: "blue-500", collectionId: nil, valuesByMode: [
                    "light": .color(r: 0.0, g: 0.0, b: 1.0, a: 1.0),
                    "dark": .color(r: 0.0, g: 0.0, b: 0.8, a: 1.0),
                ]),
            ],
            primitiveCollections: []
        )

        let result = generator.resolveDarkColor(
            variableId: "VariableID:semantic",
            modeId: "dark",
            variablesMeta: meta,
            primitivesModeId: nil
        )

        // Alias target resolves using collection's defaultModeId ("light") since no primitivesModeId set
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.hex, "0000ff")
    }

    func testResolveDarkColorMultiHopAlias() {
        let meta = VariablesMeta.makeWithAliases(
            collectionName: "Theme",
            modes: [("light", "Light"), ("dark", "Dark")],
            variables: [
                (id: "a", name: "a", collectionId: nil, valuesByMode: ["dark": .alias("b")]),
                (id: "b", name: "b", collectionId: nil, valuesByMode: [
                    "light": .alias("c"),
                    "dark": .alias("c"),
                ]),
                (id: "c", name: "c", collectionId: nil, valuesByMode: [
                    "light": .color(r: 0.0, g: 1.0, b: 0.0, a: 0.5),
                ]),
            ],
            primitiveCollections: []
        )

        let result = generator.resolveDarkColor(
            variableId: "VariableID:a",
            modeId: "dark",
            variablesMeta: meta,
            primitivesModeId: nil
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.hex, "00ff00")
        XCTAssertEqual(result?.alpha, 0.5)
    }

    // MARK: - resolveDarkColor: Depth limit

    func testResolveDarkColorDepthLimitReturnsNil() {
        var variables: [(id: String, name: String, collectionId: String?, valuesByMode: [String: TestVariableValue])] =
            []
        for i in 0 ..< 12 {
            let nextId = i < 11 ? "\(i + 1)" : "end"
            variables.append((id: "\(i)", name: "v\(i)", collectionId: nil, valuesByMode: ["dark": .alias(nextId)]))
        }
        variables.append((id: "end", name: "end", collectionId: nil, valuesByMode: [
            "dark": .color(r: 1.0, g: 0.0, b: 0.0, a: 1.0),
        ]))

        let meta = VariablesMeta.makeWithAliases(
            collectionName: "Theme",
            modes: [("light", "Light"), ("dark", "Dark")],
            variables: variables,
            primitiveCollections: []
        )

        let result = generator.resolveDarkColor(
            variableId: "VariableID:0",
            modeId: "dark",
            variablesMeta: meta,
            primitivesModeId: nil
        )

        XCTAssertNil(result, "Should return nil when alias chain exceeds depth limit")
    }

    // MARK: - resolveDarkColor: Deleted variable

    func testResolveDarkColorSkipsDeletedVariable() {
        let meta = VariablesMeta.makeWithAliases(
            collectionName: "Theme",
            modes: [("light", "Light"), ("dark", "Dark")],
            variables: [
                (id: "deleted", name: "old-color", collectionId: nil, valuesByMode: [
                    "dark": .color(r: 1.0, g: 0.0, b: 0.0, a: 1.0),
                ]),
            ],
            primitiveCollections: [],
            deletedVariableIds: ["deleted"]
        )

        let result = generator.resolveDarkColor(
            variableId: "VariableID:deleted",
            modeId: "dark",
            variablesMeta: meta,
            primitivesModeId: nil
        )

        XCTAssertNil(result, "Should skip deleted variables")
    }

    func testResolveDarkColorReturnsNilForUnknownVariable() {
        let meta = VariablesMeta.make(
            collectionName: "Theme",
            modes: [("light", "Light"), ("dark", "Dark")],
            variables: []
        )

        let result = generator.resolveDarkColor(
            variableId: "VariableID:nonexistent",
            modeId: "dark",
            variablesMeta: meta,
            primitivesModeId: nil
        )

        XCTAssertNil(result)
    }

    // MARK: - resolveDarkColor: Fallback to defaultModeId

    func testResolveDarkColorFallsBackToDefaultMode() {
        let meta = VariablesMeta.make(
            collectionName: "Theme",
            modes: [("default", "Light"), ("dark", "Dark")],
            variables: [
                (id: "v1", name: "bg", valuesByMode: [
                    "default": (r: 0.5, g: 0.5, b: 0.5, a: 1.0),
                ]),
            ]
        )

        let result = generator.resolveDarkColor(
            variableId: "VariableID:v1",
            modeId: "dark",
            variablesMeta: meta,
            primitivesModeId: nil
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.hex, "808080")
    }

    // MARK: - resolveDarkColor: Alpha / opacity

    func testResolveDarkColorWithAlpha() {
        let meta = VariablesMeta.make(
            collectionName: "Theme",
            modes: [("light", "Light"), ("dark", "Dark")],
            variables: [
                (id: "v1", name: "transparent-bg", valuesByMode: [
                    "dark": (r: 214.0 / 255.0, g: 251.0 / 255.0, b: 148.0 / 255.0, a: 0.0),
                ]),
            ]
        )

        let result = generator.resolveDarkColor(
            variableId: "VariableID:v1",
            modeId: "dark",
            variablesMeta: meta,
            primitivesModeId: nil
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.hex, "d6fb94")
        XCTAssertEqual(result?.alpha, 0.0)
        XCTAssertTrue(result?.changesOpacity == true)
    }
}

// MARK: - buildColorMap & resolveViaLibrary Tests

final class VariableModeDarkGeneratorColorMapTests: XCTestCase {
    private var generator: VariableModeDarkGenerator!

    override func setUp() {
        super.setUp()
        generator = makeGenerator()
    }

    func testBuildColorMapExtractsFromBoundVariables() throws {
        let nodeJson = """
        {
            "document": {
                "id": "node1",
                "name": "icon",
                "fills": [
                    {
                        "type": "SOLID",
                        "color": { "r": 1.0, "g": 0.0, "b": 0.0, "a": 1.0 },
                        "boundVariables": {
                            "color": { "id": "VariableID:v1", "type": "VARIABLE_ALIAS" }
                        }
                    }
                ]
            }
        }
        """
        let node = try JSONCodec.decode(Node.self, from: Data(nodeJson.utf8))

        let meta = VariablesMeta.make(
            collectionName: "Theme",
            modes: [("light", "Light"), ("dark", "Dark")],
            variables: [
                (id: "v1", name: "red", valuesByMode: [
                    "light": (r: 1.0, g: 0.0, b: 0.0, a: 1.0),
                    "dark": (r: 0.0, g: 0.0, b: 1.0, a: 1.0),
                ]),
            ]
        )

        let ctx = VariableModeDarkGenerator.ResolutionContext(
            variablesMeta: meta,
            libMeta: nil,
            libNameIndex: nil,
            modes: .init(lightModeId: "light", darkModeId: "dark", primitivesModeId: nil),
            darkModeName: "Dark"
        )

        let colorMap = generator.buildColorMap(node: node, ctx: ctx, iconName: "test-icon")
        XCTAssertEqual(colorMap.count, 1)
        XCTAssertEqual(colorMap["ff0000"]?.hex, "0000ff")
    }

    func testBuildColorMapExtractsFromStrokes() throws {
        let nodeJson = """
        {
            "document": {
                "id": "node1",
                "name": "icon",
                "fills": [],
                "strokes": [
                    {
                        "type": "SOLID",
                        "color": { "r": 0.0, "g": 1.0, "b": 0.0, "a": 1.0 },
                        "boundVariables": {
                            "color": { "id": "VariableID:v1", "type": "VARIABLE_ALIAS" }
                        }
                    }
                ]
            }
        }
        """
        let node = try JSONCodec.decode(Node.self, from: Data(nodeJson.utf8))

        let meta = VariablesMeta.make(
            collectionName: "Theme",
            modes: [("light", "Light"), ("dark", "Dark")],
            variables: [
                (id: "v1", name: "green", valuesByMode: [
                    "light": (r: 0.0, g: 1.0, b: 0.0, a: 1.0),
                    "dark": (r: 1.0, g: 1.0, b: 0.0, a: 1.0),
                ]),
            ]
        )

        let ctx = VariableModeDarkGenerator.ResolutionContext(
            variablesMeta: meta,
            libMeta: nil,
            libNameIndex: nil,
            modes: .init(lightModeId: "light", darkModeId: "dark", primitivesModeId: nil),
            darkModeName: "Dark"
        )

        let colorMap = generator.buildColorMap(node: node, ctx: ctx, iconName: "test-icon")
        XCTAssertEqual(colorMap["00ff00"]?.hex, "ffff00")
    }

    func testBuildColorMapRecursesIntoChildren() throws {
        let nodeJson = """
        {
            "document": {
                "id": "parent",
                "name": "group",
                "fills": [],
                "children": [
                    {
                        "id": "child1",
                        "name": "rect",
                        "fills": [
                            {
                                "type": "SOLID",
                                "color": { "r": 1.0, "g": 0.0, "b": 0.0, "a": 1.0 },
                                "boundVariables": {
                                    "color": { "id": "VariableID:v1", "type": "VARIABLE_ALIAS" }
                                }
                            }
                        ]
                    }
                ]
            }
        }
        """
        let node = try JSONCodec.decode(Node.self, from: Data(nodeJson.utf8))

        let meta = VariablesMeta.make(
            collectionName: "Theme",
            modes: [("light", "Light"), ("dark", "Dark")],
            variables: [
                (id: "v1", name: "red", valuesByMode: [
                    "light": (r: 1.0, g: 0.0, b: 0.0, a: 1.0),
                    "dark": (r: 0.5, g: 0.5, b: 0.5, a: 1.0),
                ]),
            ]
        )

        let ctx = VariableModeDarkGenerator.ResolutionContext(
            variablesMeta: meta,
            libMeta: nil,
            libNameIndex: nil,
            modes: .init(lightModeId: "light", darkModeId: "dark", primitivesModeId: nil),
            darkModeName: "Dark"
        )

        let colorMap = generator.buildColorMap(node: node, ctx: ctx, iconName: "test-icon")
        XCTAssertEqual(colorMap.count, 1)
        XCTAssertEqual(colorMap["ff0000"]?.hex, "808080")
    }

    // MARK: - resolveViaLibrary

    func testResolveViaLibraryMatchesByName() {
        let libMeta = VariablesMeta.make(
            collectionName: "Primitives",
            modes: [("plight", "Light"), ("pdark", "Dark")],
            variables: [
                (id: "lib-v1", name: "brand/primary", valuesByMode: [
                    "plight": (r: 1.0, g: 0.0, b: 0.0, a: 1.0),
                    "pdark": (r: 0.0, g: 1.0, b: 0.0, a: 1.0),
                ]),
            ]
        )

        let libNameIndex = Dictionary(
            libMeta.variables.values.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let result = generator.resolveViaLibrary(
            variableName: "brand/primary",
            libMeta: libMeta,
            libNameIndex: libNameIndex,
            darkModeName: "Dark"
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.hex, "00ff00")
    }

    func testResolveViaLibraryReturnsNilWhenNameNotFound() {
        let libMeta = VariablesMeta.make(
            collectionName: "Primitives",
            modes: [("plight", "Light"), ("pdark", "Dark")],
            variables: []
        )

        let result = generator.resolveViaLibrary(
            variableName: "nonexistent",
            libMeta: libMeta,
            libNameIndex: [:],
            darkModeName: "Dark"
        )

        XCTAssertNil(result)
    }

    func testResolveViaLibraryReturnsNilWhenDarkModeNotFound() {
        let libMeta = VariablesMeta.make(
            collectionName: "Primitives",
            modes: [("plight", "Light"), ("pdim", "Dim")],
            variables: [
                (id: "lib-v1", name: "color", valuesByMode: [
                    "plight": (r: 1.0, g: 0.0, b: 0.0, a: 1.0),
                    "pdim": (r: 0.5, g: 0.5, b: 0.5, a: 1.0),
                ]),
            ]
        )

        let libNameIndex = Dictionary(
            libMeta.variables.values.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let result = generator.resolveViaLibrary(
            variableName: "color",
            libMeta: libMeta,
            libNameIndex: libNameIndex,
            darkModeName: "Dark"
        )

        XCTAssertNil(result, "Should return nil when dark mode name doesn't match")
    }
}

// MARK: - VariablesCache Tests

final class VariablesCacheTests: XCTestCase {
    func testDeduplicatesParallelRequests() async throws {
        let cache = VariablesCache()
        let fetchCount = Lock(0)

        let meta = VariablesMeta.make(
            collectionName: "Test",
            modes: [("m1", "Mode1")],
            variables: []
        )

        try await withThrowingTaskGroup(of: VariablesMeta.self) { group in
            for _ in 0 ..< 5 {
                group.addTask {
                    try await cache.get(fileId: "file1") {
                        fetchCount.withLock { $0 += 1 }
                        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                        return meta
                    }
                }
            }
            for try await _ in group {}
        }

        XCTAssertEqual(fetchCount.withLock { $0 }, 1, "Should only fetch once for the same fileId")
    }

    func testDifferentFileIdsGetSeparateFetches() async throws {
        let cache = VariablesCache()
        let fetchCount = Lock(0)

        let meta = VariablesMeta.make(
            collectionName: "Test",
            modes: [("m1", "Mode1")],
            variables: []
        )

        try await withThrowingTaskGroup(of: VariablesMeta.self) { group in
            for i in 0 ..< 3 {
                group.addTask {
                    try await cache.get(fileId: "file\(i)") {
                        fetchCount.withLock { $0 += 1 }
                        return meta
                    }
                }
            }
            for try await _ in group {}
        }

        XCTAssertEqual(fetchCount.withLock { $0 }, 3, "Each unique fileId should trigger a separate fetch")
    }

    func testFailedTaskIsEvictedForRetry() async throws {
        let cache = VariablesCache()
        let fetchCount = Lock(0)

        struct TestError: Error {}

        do {
            _ = try await cache.get(fileId: "file1") {
                fetchCount.withLock { $0 += 1 }
                throw TestError()
            }
            XCTFail("Should have thrown")
        } catch {
            // Expected
        }

        XCTAssertEqual(fetchCount.withLock { $0 }, 1)

        let meta = VariablesMeta.make(
            collectionName: "Test",
            modes: [("m1", "Mode1")],
            variables: []
        )

        let result = try await cache.get(fileId: "file1") {
            fetchCount.withLock { $0 += 1 }
            return meta
        }

        XCTAssertEqual(fetchCount.withLock { $0 }, 2, "Failed task should be evicted, allowing retry")
        XCTAssertEqual(result.variableCollections.count, 1)
    }
}

// swiftlint:enable file_length
