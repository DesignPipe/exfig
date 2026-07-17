// swiftlint:disable file_length type_body_length

import CustomDump
@testable import ExFigCLI
import ExFigCore
@testable import FigmaAPI
import XCTest

final class ColorsVariablesLoaderTests: XCTestCase {
    var mockClient: MockClient!

    override func setUp() {
        super.setUp()
        mockClient = MockClient()
    }

    override func tearDown() {
        mockClient = nil
        super.tearDown()
    }

    // MARK: - Basic Loading

    func testLoadVariablesColorsBasic() async throws {
        let variablesMeta = VariablesMeta.make(
            collectionName: "Colors",
            modes: [("1:0", "Light"), ("1:1", "Dark")],
            variables: [
                (
                    id: "1:2",
                    name: "primary/background",
                    valuesByMode: [
                        "1:0": (r: 1.0, g: 1.0, b: 1.0, a: 1.0),
                        "1:1": (r: 0.1, g: 0.1, b: 0.1, a: 1.0),
                    ]
                ),
            ]
        )

        mockClient.setResponse(variablesMeta, for: VariablesEndpoint.self)

        let variablesParams = PKLConfig.Common.VariablesColors.make(
            tokensFileId: "test-file",
            tokensCollectionName: "Colors",
            lightModeName: "Light",
            darkModeName: "Dark"
        )

        let loader = ColorsVariablesLoader(
            client: mockClient,
            variableParams: variablesParams,
            filter: nil
        )

        let result = try await loader.load()

        XCTAssertEqual(result.output.light.count, 1)
        XCTAssertEqual(result.output.light.first?.name, "primary/background")
        XCTAssertEqual(result.output.light.first?.red, 1.0)

        XCTAssertEqual(result.output.dark?.count, 1)
        XCTAssertEqual(result.output.dark?.first?.red, 0.1)
    }

    func testLoadVariablesColorsWithMultipleColors() async throws {
        let variablesMeta = VariablesMeta.make(
            collectionName: "Colors",
            modes: [("1:0", "Light"), ("1:1", "Dark")],
            variables: [
                (
                    id: "1:2",
                    name: "primary/background",
                    valuesByMode: [
                        "1:0": (r: 1.0, g: 1.0, b: 1.0, a: 1.0),
                        "1:1": (r: 0.0, g: 0.0, b: 0.0, a: 1.0),
                    ]
                ),
                (
                    id: "1:3",
                    name: "primary/text",
                    valuesByMode: [
                        "1:0": (r: 0.0, g: 0.0, b: 0.0, a: 1.0),
                        "1:1": (r: 1.0, g: 1.0, b: 1.0, a: 1.0),
                    ]
                ),
            ]
        )

        mockClient.setResponse(variablesMeta, for: VariablesEndpoint.self)

        let variablesParams = PKLConfig.Common.VariablesColors.make(
            tokensFileId: "test-file",
            tokensCollectionName: "Colors"
        )

        let loader = ColorsVariablesLoader(
            client: mockClient,
            variableParams: variablesParams,
            filter: nil
        )

        let result = try await loader.load()

        XCTAssertEqual(result.output.light.count, 2)
        XCTAssertEqual(result.output.dark?.count, 2)

        let bgLight = result.output.light.first { $0.name == "primary/background" }
        let textLight = result.output.light.first { $0.name == "primary/text" }

        XCTAssertEqual(bgLight?.red, 1.0)
        XCTAssertEqual(textLight?.red, 0.0)
    }

    // MARK: - Filtering

    func testLoadVariablesColorsWithFilter() async throws {
        let variablesMeta = VariablesMeta.make(
            collectionName: "Colors",
            modes: [("1:0", "Light"), ("1:1", "Dark")],
            variables: [
                (
                    id: "1:2",
                    name: "button/primary",
                    valuesByMode: [
                        "1:0": (r: 1.0, g: 0.0, b: 0.0, a: 1.0),
                        "1:1": (r: 0.8, g: 0.0, b: 0.0, a: 1.0),
                    ]
                ),
                (
                    id: "1:3",
                    name: "text/primary",
                    valuesByMode: [
                        "1:0": (r: 0.0, g: 0.0, b: 0.0, a: 1.0),
                        "1:1": (r: 1.0, g: 1.0, b: 1.0, a: 1.0),
                    ]
                ),
            ]
        )

        mockClient.setResponse(variablesMeta, for: VariablesEndpoint.self)

        let variablesParams = PKLConfig.Common.VariablesColors.make(
            tokensFileId: "test-file",
            tokensCollectionName: "Colors"
        )

        let loader = ColorsVariablesLoader(
            client: mockClient,
            variableParams: variablesParams,
            filter: "button/*"
        )

        let result = try await loader.load()

        XCTAssertEqual(result.output.light.count, 1)
        XCTAssertEqual(result.output.light.first?.name, "button/primary")
    }

    // MARK: - All Modes

    func testLoadVariablesColorsWithAllModes() async throws {
        let variablesMeta = VariablesMeta.make(
            collectionName: "Tokens",
            modes: [
                ("1:0", "Light"),
                ("1:1", "Dark"),
                ("1:2", "LightHC"),
                ("1:3", "DarkHC"),
            ],
            variables: [
                (
                    id: "1:2",
                    name: "primary",
                    valuesByMode: [
                        "1:0": (r: 1.0, g: 1.0, b: 1.0, a: 1.0),
                        "1:1": (r: 0.1, g: 0.1, b: 0.1, a: 1.0),
                        "1:2": (r: 0.95, g: 0.95, b: 0.95, a: 1.0),
                        "1:3": (r: 0.05, g: 0.05, b: 0.05, a: 1.0),
                    ]
                ),
            ]
        )

        mockClient.setResponse(variablesMeta, for: VariablesEndpoint.self)

        let variablesParams = PKLConfig.Common.VariablesColors.make(
            tokensFileId: "test-file",
            tokensCollectionName: "Tokens",
            lightModeName: "Light",
            darkModeName: "Dark",
            lightHCModeName: "LightHC",
            darkHCModeName: "DarkHC"
        )

        let loader = ColorsVariablesLoader(
            client: mockClient,
            variableParams: variablesParams,
            filter: nil
        )

        let result = try await loader.load()

        XCTAssertEqual(result.output.light.count, 1)
        XCTAssertEqual(result.output.dark?.count, 1)
        XCTAssertEqual(result.output.lightHC?.count, 1)
        XCTAssertEqual(result.output.darkHC?.count, 1)

        XCTAssertEqual(result.output.light.first?.red, 1.0)
        XCTAssertEqual(result.output.dark?.first?.red, 0.1)
        XCTAssertEqual(result.output.lightHC?.first?.red, 0.95)
        XCTAssertEqual(result.output.darkHC?.first?.red, 0.05)
    }

    // MARK: - Error Handling

    func testThrowsWhenTokensFileIdMissing() async {
        let loader = ColorsVariablesLoader(
            client: mockClient,
            variableParams: nil,
            filter: nil
        )

        do {
            _ = try await loader.load()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is ExFigError)
        }
    }

    func testThrowsWhenCollectionNotFound() async {
        let variablesMeta = VariablesMeta.make(
            collectionName: "DifferentCollection",
            modes: [("1:0", "Light")],
            variables: [
                (
                    id: "1:2",
                    name: "color",
                    valuesByMode: ["1:0": (r: 1.0, g: 0.0, b: 0.0, a: 1.0)]
                ),
            ]
        )

        mockClient.setResponse(variablesMeta, for: VariablesEndpoint.self)

        let variablesParams = PKLConfig.Common.VariablesColors.make(
            tokensFileId: "test-file",
            tokensCollectionName: "NonExistentCollection"
        )

        let loader = ColorsVariablesLoader(
            client: mockClient,
            variableParams: variablesParams,
            filter: nil
        )

        do {
            _ = try await loader.load()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is ExFigError)
        }
    }

    // MARK: - Variable Alias Resolution

    func testResolvesVariableAliasToColor() async throws {
        // Given: A token variable that references a primitive color via alias
        let variablesMeta = VariablesMeta.makeWithAliases(
            collectionName: "Tokens",
            modes: [("1:0", "Light")],
            variables: [
                // Token that aliases a primitive
                (
                    id: "token:1",
                    name: "background/primary",
                    collectionId: nil,
                    valuesByMode: ["1:0": .alias("prim:red")]
                ),
                // Primitive color
                (
                    id: "prim:red",
                    name: "red/500",
                    collectionId: "VariableCollectionId:primitives",
                    valuesByMode: ["2:0": .color(r: 1.0, g: 0.0, b: 0.0, a: 1.0)]
                ),
            ],
            primitiveCollections: [
                (
                    id: "VariableCollectionId:primitives",
                    name: "Primitives",
                    defaultModeId: "2:0",
                    modes: [("2:0", "Value")],
                    variableIds: ["prim:red"]
                ),
            ]
        )

        mockClient.setResponse(variablesMeta, for: VariablesEndpoint.self)

        let variablesParams = PKLConfig.Common.VariablesColors.make(
            tokensFileId: "test-file",
            tokensCollectionName: "Tokens",
            lightModeName: "Light"
        )

        let loader = ColorsVariablesLoader(
            client: mockClient,
            variableParams: variablesParams,
            filter: nil
        )

        // When: Loading colors
        let result = try await loader.load()

        // Then: Alias should be resolved to the primitive color value
        XCTAssertEqual(result.output.light.count, 1)
        XCTAssertEqual(result.output.light.first?.name, "background/primary")
        XCTAssertEqual(result.output.light.first?.red, 1.0)
        XCTAssertEqual(result.output.light.first?.green, 0.0)
        XCTAssertEqual(result.output.light.first?.blue, 0.0)
    }

    func testResolvesNestedVariableAliases() async throws {
        // Given: A chain of aliases: token -> alias -> primitive
        let variablesMeta = VariablesMeta.makeWithAliases(
            collectionName: "Tokens",
            modes: [("1:0", "Light")],
            variables: [
                // Token aliases another alias
                (
                    id: "token:1",
                    name: "button/primary",
                    collectionId: nil,
                    valuesByMode: ["1:0": .alias("semantic:brand")]
                ),
                // Semantic color that aliases primitive
                (
                    id: "semantic:brand",
                    name: "brand/primary",
                    collectionId: "VariableCollectionId:semantic",
                    valuesByMode: ["2:0": .alias("prim:blue")]
                ),
                // Primitive color
                (
                    id: "prim:blue",
                    name: "blue/600",
                    collectionId: "VariableCollectionId:primitives",
                    valuesByMode: ["3:0": .color(r: 0.0, g: 0.0, b: 1.0, a: 1.0)]
                ),
            ],
            primitiveCollections: [
                (
                    id: "VariableCollectionId:semantic",
                    name: "Semantic",
                    defaultModeId: "2:0",
                    modes: [("2:0", "Value")],
                    variableIds: ["semantic:brand"]
                ),
                (
                    id: "VariableCollectionId:primitives",
                    name: "Primitives",
                    defaultModeId: "3:0",
                    modes: [("3:0", "Value")],
                    variableIds: ["prim:blue"]
                ),
            ]
        )

        mockClient.setResponse(variablesMeta, for: VariablesEndpoint.self)

        let variablesParams = PKLConfig.Common.VariablesColors.make(
            tokensFileId: "test-file",
            tokensCollectionName: "Tokens",
            lightModeName: "Light"
        )

        let loader = ColorsVariablesLoader(
            client: mockClient,
            variableParams: variablesParams,
            filter: nil
        )

        // When: Loading colors
        let result = try await loader.load()

        // Then: Nested aliases should be fully resolved
        XCTAssertEqual(result.output.light.count, 1)
        XCTAssertEqual(result.output.light.first?.name, "button/primary")
        XCTAssertEqual(result.output.light.first?.blue, 1.0)
    }

    func testResolvesAliasWithCustomPrimitivesModeName() async throws {
        // Given: A primitive collection with a custom mode name
        let variablesMeta = VariablesMeta.makeWithAliases(
            collectionName: "Tokens",
            modes: [("1:0", "Light")],
            variables: [
                (
                    id: "token:1",
                    name: "accent",
                    collectionId: nil,
                    valuesByMode: ["1:0": .alias("prim:green")]
                ),
                (
                    id: "prim:green",
                    name: "green/500",
                    collectionId: "VariableCollectionId:primitives",
                    valuesByMode: [
                        "2:0": .color(r: 0.0, g: 0.8, b: 0.0, a: 1.0),
                        "2:1": .color(r: 0.0, g: 1.0, b: 0.0, a: 1.0),
                    ]
                ),
            ],
            primitiveCollections: [
                (
                    id: "VariableCollectionId:primitives",
                    name: "Primitives",
                    defaultModeId: "2:0",
                    modes: [("2:0", "Default"), ("2:1", "Brand")],
                    variableIds: ["prim:green"]
                ),
            ]
        )

        mockClient.setResponse(variablesMeta, for: VariablesEndpoint.self)

        let variablesParams = PKLConfig.Common.VariablesColors.make(
            tokensFileId: "test-file",
            tokensCollectionName: "Tokens",
            lightModeName: "Light",
            primitivesModeName: "Brand" // Use Brand mode instead of default
        )

        let loader = ColorsVariablesLoader(
            client: mockClient,
            variableParams: variablesParams,
            filter: nil
        )

        // When: Loading colors
        let result = try await loader.load()

        // Then: Should use the specified primitives mode
        XCTAssertEqual(result.output.light.count, 1)
        XCTAssertEqual(result.output.light.first?.green, 1.0) // Brand mode has green=1.0
    }

    func testResolvesAliasesAcrossMultipleModes() async throws {
        // Given: A token with aliases for both Light and Dark modes
        let variablesMeta = VariablesMeta.makeWithAliases(
            collectionName: "Tokens",
            modes: [("1:0", "Light"), ("1:1", "Dark")],
            variables: [
                (
                    id: "token:1",
                    name: "surface",
                    collectionId: nil,
                    valuesByMode: [
                        "1:0": .alias("prim:white"),
                        "1:1": .alias("prim:black"),
                    ]
                ),
                (
                    id: "prim:white",
                    name: "white",
                    collectionId: "VariableCollectionId:primitives",
                    valuesByMode: ["2:0": .color(r: 1.0, g: 1.0, b: 1.0, a: 1.0)]
                ),
                (
                    id: "prim:black",
                    name: "black",
                    collectionId: "VariableCollectionId:primitives",
                    valuesByMode: ["2:0": .color(r: 0.0, g: 0.0, b: 0.0, a: 1.0)]
                ),
            ],
            primitiveCollections: [
                (
                    id: "VariableCollectionId:primitives",
                    name: "Primitives",
                    defaultModeId: "2:0",
                    modes: [("2:0", "Value")],
                    variableIds: ["prim:white", "prim:black"]
                ),
            ]
        )

        mockClient.setResponse(variablesMeta, for: VariablesEndpoint.self)

        let variablesParams = PKLConfig.Common.VariablesColors.make(
            tokensFileId: "test-file",
            tokensCollectionName: "Tokens",
            lightModeName: "Light",
            darkModeName: "Dark"
        )

        let loader = ColorsVariablesLoader(
            client: mockClient,
            variableParams: variablesParams,
            filter: nil
        )

        // When: Loading colors
        let result = try await loader.load()

        // Then: Each mode should resolve to correct primitive
        XCTAssertEqual(result.output.light.first?.red, 1.0) // White
        XCTAssertEqual(result.output.dark?.first?.red, 0.0) // Black
    }

    // MARK: - Deleted Variables

    func testSkipsDeletedButReferencedVariables() async throws {
        // Given: One active color and one deleted-but-referenced color
        let variablesMeta = VariablesMeta.makeWithAliases(
            collectionName: "Colors",
            modes: [("1:0", "Light"), ("1:1", "Dark")],
            variables: [
                (
                    id: "1:2",
                    name: "primary/background",
                    collectionId: nil,
                    valuesByMode: [
                        "1:0": .color(r: 1.0, g: 1.0, b: 1.0, a: 1.0),
                        "1:1": .color(r: 0.1, g: 0.1, b: 0.1, a: 1.0),
                    ]
                ),
                (
                    id: "1:3",
                    name: "Background/(!!!DEPRICATED)Float",
                    collectionId: nil,
                    valuesByMode: [
                        "1:0": .color(r: 0.5, g: 0.5, b: 0.5, a: 1.0),
                        "1:1": .color(r: 0.3, g: 0.3, b: 0.3, a: 1.0),
                    ]
                ),
            ],
            deletedVariableIds: ["1:3"]
        )

        mockClient.setResponse(variablesMeta, for: VariablesEndpoint.self)

        let variablesParams = PKLConfig.Common.VariablesColors.make(
            tokensFileId: "test-file",
            tokensCollectionName: "Colors",
            lightModeName: "Light",
            darkModeName: "Dark"
        )

        let loader = ColorsVariablesLoader(
            client: mockClient,
            variableParams: variablesParams,
            filter: nil
        )

        // When: Loading colors
        let result = try await loader.load()

        // Then: Only active variable should be included
        XCTAssertEqual(result.output.light.count, 1)
        XCTAssertEqual(result.output.light.first?.name, "primary/background")
        XCTAssertEqual(result.output.dark?.count, 1)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func testWarnsWhenAliasTargetIsDeletedButReferenced() async throws {
        // Given: A token that aliases a deleted-but-referenced primitive
        let variablesMeta = VariablesMeta.makeWithAliases(
            collectionName: "Tokens",
            modes: [("1:0", "Light")],
            variables: [
                (
                    id: "token:1",
                    name: "surface/primary",
                    collectionId: nil,
                    valuesByMode: ["1:0": .alias("prim:old")]
                ),
                (
                    id: "prim:old",
                    name: "gray/deprecated",
                    collectionId: "VariableCollectionId:primitives",
                    valuesByMode: ["2:0": .color(r: 0.5, g: 0.5, b: 0.5, a: 1.0)]
                ),
            ],
            primitiveCollections: [
                (
                    id: "VariableCollectionId:primitives",
                    name: "Primitives",
                    defaultModeId: "2:0",
                    modes: [("2:0", "Value")],
                    variableIds: ["prim:old"]
                ),
            ],
            deletedVariableIds: ["prim:old"]
        )

        mockClient.setResponse(variablesMeta, for: VariablesEndpoint.self)

        let variablesParams = PKLConfig.Common.VariablesColors.make(
            tokensFileId: "test-file",
            tokensCollectionName: "Tokens",
            lightModeName: "Light"
        )

        let loader = ColorsVariablesLoader(
            client: mockClient,
            variableParams: variablesParams,
            filter: nil
        )

        // When: Loading colors
        let result = try await loader.load()

        // Then: Token should be skipped (alias target is deleted) with a warning
        XCTAssertEqual(result.output.light.count, 0)
        XCTAssertEqual(result.warnings.count, 1)
        XCTAssertEqual(
            result.warnings.first,
            .deletedVariableAlias(tokenName: "surface/primary", referencedName: "gray/deprecated")
        )
    }

    // MARK: - Single API Call Verification

    func testUseSingleAPICall() async throws {
        let variablesMeta = VariablesMeta.make(
            collectionName: "Colors",
            modes: [("1:0", "Light"), ("1:1", "Dark")],
            variables: [
                (
                    id: "1:2",
                    name: "color",
                    valuesByMode: [
                        "1:0": (r: 1.0, g: 0.0, b: 0.0, a: 1.0),
                        "1:1": (r: 0.0, g: 1.0, b: 0.0, a: 1.0),
                    ]
                ),
            ]
        )

        mockClient.setResponse(variablesMeta, for: VariablesEndpoint.self)

        let variablesParams = PKLConfig.Common.VariablesColors.make(
            tokensFileId: "test-file",
            tokensCollectionName: "Colors"
        )

        let loader = ColorsVariablesLoader(
            client: mockClient,
            variableParams: variablesParams,
            filter: nil
        )

        _ = try await loader.load()

        // ColorsVariablesLoader should only make 1 API call
        // (all modes come in single response, no parallelization needed)
        XCTAssertEqual(mockClient.requestCount, 1)
    }

    // MARK: - Duplicate Collection Names

    /// Regression: a Figma file can expose several collections with the same name (a stale/remote
    /// duplicate the editor UI hides). Picking via `Dictionary.first(where:)` was non-deterministic
    /// and silently dropped almost all colors — the folder was then wiped and only the survivors
    /// re-written. The loader must deterministically pick the fullest collection and warn.
    func testPicksFullestCollectionWhenNamesCollide() async throws {
        // Given: two collections named "Base palette" — a full one (2 usable vars) and a stale dupe.
        // The stale collection's variableIds point at a variable that isn't in the response, so it
        // has 0 usable variables and must lose to the 2-var main collection.
        let variablesMeta = VariablesMeta.makeWithAliases(
            collectionName: "Base palette", // main collection (VariableCollectionId:1:1)
            variables: [
                (
                    id: "1:2", name: "backgroundPrimary", collectionId: nil,
                    valuesByMode: ["1:0": .color(r: 1.0, g: 1.0, b: 1.0, a: 1.0)]
                ),
                (
                    id: "1:3", name: "textPrimary", collectionId: nil,
                    valuesByMode: ["1:0": .color(r: 0.0, g: 0.0, b: 0.0, a: 1.0)]
                ),
            ],
            primitiveCollections: [
                (
                    id: "VariableCollectionId:stale", name: "Base palette",
                    defaultModeId: "9:0", modes: [("9:0", "Light")], variableIds: ["dupe:1"]
                ),
            ]
        )

        mockClient.setResponse(variablesMeta, for: VariablesEndpoint.self)

        let loader = ColorsVariablesLoader(
            client: mockClient,
            variableParams: PKLConfig.Common.VariablesColors.make(
                tokensFileId: "test-file", tokensCollectionName: "Base palette", lightModeName: "Light"
            ),
            filter: nil
        )

        // When: loading colors
        let result = try await loader.load()

        // Then: the full collection (2 vars) is used, not the stale dupe; and a warning surfaces it.
        // otherCounts is [0] — the stale dupe's one variableId resolves to no usable variable.
        XCTAssertEqual(Set(result.output.light.map(\.name)), ["backgroundPrimary", "textPrimary"])
        XCTAssertEqual(
            result.warnings,
            [.duplicateColorCollection(name: "Base palette", selectedCount: 2, otherCounts: [0])]
        )
    }

    /// Regression for the *determinism* half of the fix: when two same-name collections have an
    /// equal usable-variable count, the count comparison gives no signal, so selection falls to the
    /// id tie-break. Without a stable tie-break the pick would depend on dictionary iteration order —
    /// exactly the non-determinism this fix removes. The lower id must always win.
    ///
    /// The dupe is given id "VariableCollectionId:0:0" (sorts *below* the main "VariableCollectionId:1:1"),
    /// so a no-op id comparator would pick the main collection and fail this test — the assertion is
    /// only satisfiable if the id tie-break is actually consulted.
    func testTieBreaksByLowerIdWhenUsableCountsAreEqual() async throws {
        let variablesMeta = VariablesMeta.makeWithAliases(
            collectionName: "Base palette", // main collection id = VariableCollectionId:1:1, 2 usable vars
            variables: [
                (
                    id: "main:1", name: "mainOnly1", collectionId: nil,
                    valuesByMode: ["1:0": .color(r: 1.0, g: 1.0, b: 1.0, a: 1.0)]
                ),
                (
                    id: "main:2", name: "mainOnly2", collectionId: nil,
                    valuesByMode: ["1:0": .color(r: 1.0, g: 1.0, b: 1.0, a: 1.0)]
                ),
                // Two real variables belonging to the lower-id dupe collection (also 2 usable).
                (
                    id: "low:1", name: "lowWins1", collectionId: "VariableCollectionId:0:0",
                    valuesByMode: ["1:0": .color(r: 0.0, g: 0.0, b: 0.0, a: 1.0)]
                ),
                (
                    id: "low:2", name: "lowWins2", collectionId: "VariableCollectionId:0:0",
                    valuesByMode: ["1:0": .color(r: 0.0, g: 0.0, b: 0.0, a: 1.0)]
                ),
            ],
            primitiveCollections: [
                (
                    id: "VariableCollectionId:0:0", name: "Base palette",
                    defaultModeId: "1:0", modes: [("1:0", "Light")], variableIds: ["low:1", "low:2"]
                ),
            ]
        )

        mockClient.setResponse(variablesMeta, for: VariablesEndpoint.self)

        let loader = ColorsVariablesLoader(
            client: mockClient,
            variableParams: PKLConfig.Common.VariablesColors.make(
                tokensFileId: "test-file", tokensCollectionName: "Base palette", lightModeName: "Light"
            ),
            filter: nil
        )

        let result = try await loader.load()

        // The lower-id collection (VariableCollectionId:0:0) wins the tie, regardless of dict order.
        XCTAssertEqual(Set(result.output.light.map(\.name)), ["lowWins1", "lowWins2"])
        XCTAssertEqual(
            result.warnings,
            [.duplicateColorCollection(name: "Base palette", selectedCount: 2, otherCounts: [2])]
        )
    }
}
