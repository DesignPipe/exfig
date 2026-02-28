// swiftlint:disable file_length type_body_length

@testable import ExFigCLI
import XCTest

final class TokensFileSourceTests: XCTestCase {
    // MARK: - Flat Tokens (Task 8.1)

    func testParseFlatColorToken() throws {
        let json = """
        {
            "Brand": {
                "Primary": {
                    "$type": "color",
                    "$value": {
                        "colorSpace": "srgb",
                        "components": [0.231, 0.510, 0.965],
                        "hex": "#3b82f6"
                    }
                }
            }
        }
        """.utf8

        let source = try TokensFileSource.parse(data: Data(json))
        let token = source.tokens["Brand.Primary"]
        XCTAssertNotNil(token)
        XCTAssertEqual(token?.type, "color")

        if case let .color(color) = token?.value {
            XCTAssertEqual(color.colorSpace, "srgb")
            XCTAssertEqual(color.components.count, 3)
            XCTAssertEqual(color.components[0], 0.231, accuracy: 0.001)
            XCTAssertEqual(color.alpha, 1.0)
            XCTAssertEqual(color.hex, "#3b82f6")
        } else {
            XCTFail("Expected color value")
        }
    }

    func testParseColorWithAlpha() throws {
        let json = """
        {
            "Overlay": {
                "$type": "color",
                "$value": {
                    "colorSpace": "srgb",
                    "components": [0, 0, 0],
                    "alpha": 0.5
                }
            }
        }
        """.utf8

        let source = try TokensFileSource.parse(data: Data(json))
        if case let .color(color) = source.tokens["Overlay"]?.value {
            XCTAssertEqual(color.alpha, 0.5)
        } else {
            XCTFail("Expected color value")
        }
    }

    // MARK: - Nested Groups (Task 8.2)

    func testParseNestedGroups() throws {
        let json = """
        {
            "Colors": {
                "$type": "color",
                "Brand": {
                    "Primary": {
                        "$value": {
                            "colorSpace": "srgb",
                            "components": [1, 0, 0]
                        }
                    },
                    "Secondary": {
                        "$value": {
                            "colorSpace": "srgb",
                            "components": [0, 1, 0]
                        }
                    }
                }
            }
        }
        """.utf8

        let source = try TokensFileSource.parse(data: Data(json))
        XCTAssertNotNil(source.tokens["Colors.Brand.Primary"])
        XCTAssertNotNil(source.tokens["Colors.Brand.Secondary"])
        XCTAssertEqual(source.tokens["Colors.Brand.Primary"]?.type, "color")
        XCTAssertEqual(source.tokens["Colors.Brand.Secondary"]?.type, "color")
    }

    func testTypeInheritanceFromParentGroup() throws {
        let json = """
        {
            "Spacing": {
                "$type": "dimension",
                "Small": {
                    "$value": { "value": 4, "unit": "px" }
                },
                "Medium": {
                    "$value": { "value": 16, "unit": "px" }
                }
            }
        }
        """.utf8

        let source = try TokensFileSource.parse(data: Data(json))
        XCTAssertEqual(source.tokens["Spacing.Small"]?.type, "dimension")
        XCTAssertEqual(source.tokens["Spacing.Medium"]?.type, "dimension")
    }

    // MARK: - Dimension Parsing (Task 8.4)

    func testParseDimensionToken() throws {
        let json = """
        {
            "Size": {
                "$type": "dimension",
                "$value": { "value": 16, "unit": "px" }
            }
        }
        """.utf8

        let source = try TokensFileSource.parse(data: Data(json))
        if case let .dimension(dim) = source.tokens["Size"]?.value {
            XCTAssertEqual(dim.value, 16)
            XCTAssertEqual(dim.unit, "px")
        } else {
            XCTFail("Expected dimension value")
        }
    }

    // MARK: - Number Parsing

    func testParseNumberToken() throws {
        let json = """
        {
            "Weight": {
                "$type": "number",
                "$value": 700
            }
        }
        """.utf8

        let source = try TokensFileSource.parse(data: Data(json))
        if case let .number(num) = source.tokens["Weight"]?.value {
            XCTAssertEqual(num, 700)
        } else {
            XCTFail("Expected number value")
        }
    }

    // MARK: - Typography Parsing (Task 8.5)

    func testParseTypographyToken() throws {
        let json = """
        {
            "Heading": {
                "$type": "typography",
                "$value": {
                    "fontFamily": ["Inter"],
                    "fontSize": { "value": 32, "unit": "px" },
                    "fontWeight": 700,
                    "lineHeight": 1.25
                }
            }
        }
        """.utf8

        let source = try TokensFileSource.parse(data: Data(json))
        if case let .typography(typo) = source.tokens["Heading"]?.value {
            XCTAssertEqual(typo.fontFamily, ["Inter"])
            XCTAssertEqual(typo.fontSize?.value, 32)
            XCTAssertEqual(typo.fontSize?.unit, "px")
            XCTAssertEqual(typo.fontWeight, 700)
            XCTAssertEqual(typo.lineHeight, 1.25)
        } else {
            XCTFail("Expected typography value")
        }
    }

    func testParseTypographyFontFamilyAsString() throws {
        let json = """
        {
            "Body": {
                "$type": "typography",
                "$value": {
                    "fontFamily": "Roboto",
                    "fontSize": { "value": 16, "unit": "px" }
                }
            }
        }
        """.utf8

        let source = try TokensFileSource.parse(data: Data(json))
        if case let .typography(typo) = source.tokens["Body"]?.value {
            XCTAssertEqual(typo.fontFamily, ["Roboto"])
        } else {
            XCTFail("Expected typography value")
        }
    }

    // MARK: - FontFamily Token

    func testParseFontFamilyToken() throws {
        let json = """
        {
            "Primary": {
                "$type": "fontFamily",
                "$value": ["Inter", "sans-serif"]
            }
        }
        """.utf8

        let source = try TokensFileSource.parse(data: Data(json))
        if case let .fontFamily(families) = source.tokens["Primary"]?.value {
            XCTAssertEqual(families, ["Inter", "sans-serif"])
        } else {
            XCTFail("Expected fontFamily value")
        }
    }

    // MARK: - Alias Resolution (Task 8.7)

    func testAliasResolution() throws {
        let json = """
        {
            "Primitives": {
                "Blue": {
                    "$type": "color",
                    "$value": {
                        "colorSpace": "srgb",
                        "components": [0, 0, 1]
                    }
                }
            },
            "Semantic": {
                "Primary": {
                    "$type": "color",
                    "$value": "{Primitives.Blue}"
                }
            }
        }
        """.utf8

        var source = try TokensFileSource.parse(data: Data(json))
        try source.resolveAliases()

        if case let .color(color) = source.tokens["Semantic.Primary"]?.value {
            XCTAssertEqual(color.components[2], 1.0)
        } else {
            XCTFail("Expected resolved color value")
        }
    }

    func testCircularAliasDetection() throws {
        let json = """
        {
            "A": {
                "$type": "color",
                "$value": "{B}"
            },
            "B": {
                "$type": "color",
                "$value": "{A}"
            }
        }
        """.utf8

        var source = try TokensFileSource.parse(data: Data(json))
        XCTAssertThrowsError(try source.resolveAliases()) { error in
            guard case TokensFileError.circularAlias = error else {
                XCTFail("Expected circularAlias error, got \(error)")
                return
            }
        }
    }

    func testUnresolvedAliasError() throws {
        let json = """
        {
            "Token": {
                "$type": "color",
                "$value": "{NonExistent.Token}"
            }
        }
        """.utf8

        var source = try TokensFileSource.parse(data: Data(json))
        XCTAssertThrowsError(try source.resolveAliases()) { error in
            guard case TokensFileError.unresolvedAlias = error else {
                XCTFail("Expected unresolvedAlias error, got \(error)")
                return
            }
        }
    }

    // MARK: - $root Token (Task 8.8)

    func testRootTokenInGroup() throws {
        let json = """
        {
            "Brand": {
                "$type": "color",
                "$root": {
                    "$value": {
                        "colorSpace": "srgb",
                        "components": [0.5, 0.5, 0.5]
                    }
                },
                "Light": {
                    "$value": {
                        "colorSpace": "srgb",
                        "components": [1, 1, 1]
                    }
                }
            }
        }
        """.utf8

        let source = try TokensFileSource.parse(data: Data(json))
        XCTAssertNotNil(source.tokens["Brand.$root"])
        XCTAssertNotNil(source.tokens["Brand.Light"])

        if case let .color(rootColor) = source.tokens["Brand.$root"]?.value {
            XCTAssertEqual(rootColor.components[0], 0.5)
        } else {
            XCTFail("Expected root color value")
        }
    }

    // MARK: - $deprecated (Task 8.10)

    func testDeprecatedBoolean() throws {
        let json = """
        {
            "OldColor": {
                "$type": "color",
                "$value": { "colorSpace": "srgb", "components": [1, 0, 0] },
                "$deprecated": true
            }
        }
        """.utf8

        let source = try TokensFileSource.parse(data: Data(json))
        if case let .flag(flag) = source.tokens["OldColor"]?.deprecated {
            XCTAssertTrue(flag)
        } else {
            XCTFail("Expected deprecated flag")
        }
    }

    func testDeprecatedString() throws {
        let json = """
        {
            "Legacy": {
                "$type": "number",
                "$value": 42,
                "$deprecated": "Use NewToken instead"
            }
        }
        """.utf8

        let source = try TokensFileSource.parse(data: Data(json))
        if case let .message(msg) = source.tokens["Legacy"]?.deprecated {
            XCTAssertEqual(msg, "Use NewToken instead")
        } else {
            XCTFail("Expected deprecated message")
        }
    }

    // MARK: - Non-sRGB Color Warning (Task 8.11)

    func testNonSRGBColorWarning() throws {
        let json = """
        {
            "Wide": {
                "$type": "color",
                "$value": {
                    "colorSpace": "display-p3",
                    "components": [1.0, 0.5, 0.0]
                }
            }
        }
        """.utf8

        let source = try TokensFileSource.parse(data: Data(json))
        XCTAssertTrue(source.warnings.contains(where: { $0.contains("display-p3") }))
    }

    // MARK: - Font Weight String Mapping (Task 8.12)

    func testFontWeightStringMapping() {
        XCTAssertEqual(TokensFileSource.fontWeightFromString("thin"), 100)
        XCTAssertEqual(TokensFileSource.fontWeightFromString("normal"), 400)
        XCTAssertEqual(TokensFileSource.fontWeightFromString("bold"), 700)
        XCTAssertEqual(TokensFileSource.fontWeightFromString("black"), 900)
        XCTAssertEqual(TokensFileSource.fontWeightFromString("semi-bold"), 600)
        XCTAssertNil(TokensFileSource.fontWeightFromString("unknown"))
    }

    // MARK: - Validation (Task 8.13)

    func testMalformedJSON() {
        let badData = Data("not json".utf8)
        XCTAssertThrowsError(try TokensFileSource.parse(data: badData))
    }

    func testMissingValueWarning() throws {
        let json = """
        {
            "Broken": {
                "$type": "color"
            }
        }
        """.utf8

        let source = try TokensFileSource.parse(data: Data(json))
        // "Broken" has no $value, so it's treated as a group, not a token
        XCTAssertNil(source.tokens["Broken"])
    }

    func testInvalidColorObjectWarning() throws {
        let json = """
        {
            "Bad": {
                "$type": "color",
                "$value": { "components": [1, 0, 0] }
            }
        }
        """.utf8

        let source = try TokensFileSource.parse(data: Data(json))
        XCTAssertTrue(source.warnings.contains(where: { $0.contains("colorSpace") }))
    }

    // MARK: - Unsupported Types Warning (Task 8.14)

    func testUnsupportedTypeWarning() throws {
        let json = """
        {
            "MyShadow": {
                "$type": "shadow",
                "$value": { "offsetX": 0, "offsetY": 2, "blur": 4, "color": "#000000" }
            }
        }
        """.utf8

        let source = try TokensFileSource.parse(data: Data(json))
        XCTAssertNil(source.tokens["MyShadow"])
        XCTAssertTrue(source.warnings.contains(where: { $0.contains("shadow") }))
    }

    // MARK: - Description

    func testTokenDescription() throws {
        let json = """
        {
            "Token": {
                "$type": "number",
                "$value": 10,
                "$description": "A test token"
            }
        }
        """.utf8

        let source = try TokensFileSource.parse(data: Data(json))
        XCTAssertEqual(source.tokens["Token"]?.description, "A test token")
    }

    // MARK: - Model Mapping (Task 8.6)

    func testToColors() throws {
        let json = """
        {
            "Brand": {
                "Primary": {
                    "$type": "color",
                    "$value": {
                        "colorSpace": "srgb",
                        "components": [0.2, 0.4, 0.8]
                    }
                }
            }
        }
        """.utf8

        var source = try TokensFileSource.parse(data: Data(json))
        try source.resolveAliases()
        let colors = source.toColors()
        XCTAssertEqual(colors.count, 1)
        XCTAssertEqual(colors[0].name, "Brand/Primary")
        XCTAssertEqual(colors[0].red, 0.2, accuracy: 0.001)
    }

    func testToTextStyles() throws {
        let json = """
        {
            "Heading": {
                "$type": "typography",
                "$value": {
                    "fontFamily": ["Inter"],
                    "fontSize": { "value": 24, "unit": "px" },
                    "lineHeight": 1.5
                }
            }
        }
        """.utf8

        var source = try TokensFileSource.parse(data: Data(json))
        try source.resolveAliases()
        let styles = source.toTextStyles()
        XCTAssertEqual(styles.count, 1)
        XCTAssertEqual(styles[0].name, "Heading")
        XCTAssertEqual(styles[0].fontName, "Inter")
        XCTAssertEqual(styles[0].fontSize, 24)
    }

    func testToDimensionTokens() throws {
        let json = """
        {
            "Spacing": {
                "$type": "dimension",
                "$value": { "value": 8, "unit": "px" },
                "$description": "Small spacing"
            }
        }
        """.utf8

        var source = try TokensFileSource.parse(data: Data(json))
        try source.resolveAliases()
        let tokens = source.toDimensionTokens()
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].name, "Spacing")
        XCTAssertEqual(tokens[0].value, 8)
        XCTAssertEqual(tokens[0].tokenType, .dimension)
    }

    func testToNumberTokens() throws {
        let json = """
        {
            "Opacity": {
                "$type": "number",
                "$value": 0.5
            }
        }
        """.utf8

        var source = try TokensFileSource.parse(data: Data(json))
        try source.resolveAliases()
        let tokens = source.toNumberTokens()
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].value, 0.5)
        XCTAssertEqual(tokens[0].tokenType, .number)
    }

    // MARK: - Typography Font Weight as String

    func testTypographyFontWeightString() throws {
        let json = """
        {
            "Bold": {
                "$type": "typography",
                "$value": {
                    "fontFamily": ["Inter"],
                    "fontSize": { "value": 16, "unit": "px" },
                    "fontWeight": "bold"
                }
            }
        }
        """.utf8

        let source = try TokensFileSource.parse(data: Data(json))
        if case let .typography(typo) = source.tokens["Bold"]?.value {
            XCTAssertEqual(typo.fontWeight, 700)
        } else {
            XCTFail("Expected typography value")
        }
    }

    // MARK: - Integration: Export Colors from .tokens.json (Task 9.6)

    func testExportColorsFromLocalTokensFile() throws {
        // Create a temporary .tokens.json file
        let json = """
        {
            "Brand": {
                "$type": "color",
                "Primary": {
                    "$value": {
                        "colorSpace": "srgb",
                        "components": [0.2, 0.4, 0.8],
                        "alpha": 1.0,
                        "hex": "#3366CC"
                    },
                    "$description": "Brand primary color"
                },
                "Secondary": {
                    "$value": {
                        "colorSpace": "srgb",
                        "components": [0.8, 0.2, 0.4],
                        "alpha": 0.9
                    }
                }
            },
            "Semantic": {
                "$type": "color",
                "Background": {
                    "$value": "{Brand.Primary}"
                }
            }
        }
        """

        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test-colors-\(UUID().uuidString).tokens.json")
        try Data(json.utf8).write(to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        // Parse and resolve aliases — no Figma API needed
        var source = try TokensFileSource.parse(fileAt: tempFile.path)
        try source.resolveAliases()

        // Convert to ExFigCore Color models
        let colors = source.toColors()

        XCTAssertEqual(colors.count, 3)

        let primary = try XCTUnwrap(colors.first(where: { $0.name == "Brand/Primary" }))
        XCTAssertEqual(primary.red, 0.2, accuracy: 0.001)
        XCTAssertEqual(primary.green, 0.4, accuracy: 0.001)
        XCTAssertEqual(primary.blue, 0.8, accuracy: 0.001)
        XCTAssertEqual(primary.alpha, 1.0)

        let secondary = try XCTUnwrap(colors.first(where: { $0.name == "Brand/Secondary" }))
        XCTAssertEqual(secondary.alpha, 0.9, accuracy: 0.001)

        // Alias resolved to Brand.Primary's color value
        let background = try XCTUnwrap(colors.first(where: { $0.name == "Semantic/Background" }))
        XCTAssertEqual(background.red, 0.2, accuracy: 0.001)
        XCTAssertEqual(background.green, 0.4, accuracy: 0.001)
        XCTAssertEqual(background.blue, 0.8, accuracy: 0.001)
    }

    func testExportColorsWithGroupFilter() throws {
        let json = """
        {
            "Brand": {
                "$type": "color",
                "Primary": {
                    "$value": { "colorSpace": "srgb", "components": [1, 0, 0] }
                }
            },
            "System": {
                "$type": "color",
                "Error": {
                    "$value": { "colorSpace": "srgb", "components": [0.8, 0, 0] }
                }
            }
        }
        """

        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test-filter-\(UUID().uuidString).tokens.json")
        try Data(json.utf8).write(to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        var source = try TokensFileSource.parse(fileAt: tempFile.path)
        try source.resolveAliases()

        let allColors = source.toColors()
        XCTAssertEqual(allColors.count, 2)

        // Apply group filter — only "Brand" group
        let prefix = "Brand".replacingOccurrences(of: ".", with: "/") + "/"
        let filtered = allColors.filter { $0.name.hasPrefix(prefix) }
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.name, "Brand/Primary")
    }
}

// swiftlint:enable file_length type_body_length
