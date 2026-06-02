@testable import ExFigCLI
import XCTest

final class ExtractSchemasTests: XCTestCase {
    var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExtractSchemasTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    // MARK: - Extract Tests

    func testExtractCreatesAllSchemaFiles() throws {
        let outputDir = tempDirectory.appendingPathComponent("schemas").path

        let extracted = try SchemaExtractor.extract(to: outputDir)

        // All schema files should be extracted
        XCTAssertEqual(extracted.count, SchemaExtractor.schemaFiles.count)

        // Verify each file exists
        for fileName in SchemaExtractor.schemaFiles {
            let filePath = tempDirectory
                .appendingPathComponent("schemas")
                .appendingPathComponent(fileName)
                .path
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: filePath),
                "Schema file missing: \(fileName)"
            )
        }
    }

    func testExtractCreatesOutputDirectory() throws {
        let outputDir = tempDirectory
            .appendingPathComponent("deep/nested/schemas")
            .path

        _ = try SchemaExtractor.extract(to: outputDir)

        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputDir, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }

    func testExtractSkipsExistingFilesWithoutForce() throws {
        let outputDir = tempDirectory.appendingPathComponent("schemas").path

        // First extraction
        let firstExtracted = try SchemaExtractor.extract(to: outputDir)
        XCTAssertEqual(firstExtracted.count, SchemaExtractor.schemaFiles.count)

        // Second extraction without force — should skip all
        let secondExtracted = try SchemaExtractor.extract(to: outputDir, force: false)
        XCTAssertEqual(secondExtracted.count, 0)
    }

    func testExtractOverwritesWithForce() throws {
        let outputDir = tempDirectory.appendingPathComponent("schemas").path

        // First extraction
        _ = try SchemaExtractor.extract(to: outputDir)

        // Second extraction with force — should overwrite all
        let extracted = try SchemaExtractor.extract(to: outputDir, force: true)
        XCTAssertEqual(extracted.count, SchemaExtractor.schemaFiles.count)
    }

    func testExtractedFilesAreNonEmpty() throws {
        let outputDir = tempDirectory.appendingPathComponent("schemas").path

        _ = try SchemaExtractor.extract(to: outputDir)

        for fileName in SchemaExtractor.schemaFiles {
            let filePath = tempDirectory
                .appendingPathComponent("schemas")
                .appendingPathComponent(fileName)
                .path
            let attrs = try FileManager.default.attributesOfItem(atPath: filePath)
            let size = attrs[.size] as? Int ?? 0
            XCTAssertGreaterThan(size, 0, "Schema file should not be empty: \(fileName)")
        }
    }

    func testSchemaFilesListIncludesExpectedFiles() {
        // Verify the schema files list contains the expected PKL schemas
        let expected = [
            "ExFig.pkl",
            "Figma.pkl",
            "Common.pkl",
            "iOS.pkl",
            "Android.pkl",
            "Flutter.pkl",
            "Web.pkl",
            "Lint.pkl",
            "PklProject",
        ]
        XCTAssertEqual(SchemaExtractor.schemaFiles.sorted(), expected.sorted())
    }

    func testDefaultOutputDir() {
        XCTAssertEqual(SchemaExtractor.defaultOutputDir, ".exfig/schemas")
    }
}
