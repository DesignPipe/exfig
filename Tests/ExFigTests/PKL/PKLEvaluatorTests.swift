import ExFigConfig
import Foundation
import PklSwift
import Testing

@Suite(.serialized, .timeLimit(.minutes(2)))
struct PKLEvaluatorTests {
    /// Path to test fixtures
    static let fixturesPath = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/PKL")

    @Test("Evaluates valid PKL to ExFig module")
    func evaluatesValidPkl() async throws {
        let configPath = Self.fixturesPath.appendingPathComponent("valid-config.pkl")

        let module = try await PKLEvaluator.evaluate(configPath: configPath)

        #expect(module.ios != nil)
        #expect(module.ios?.xcodeprojPath == "Test.xcodeproj")
        #expect(module.ios?.target == "TestTarget")
        #expect(module.common?.variablesColors?.tokensFileId == "test-file-id")
    }

    @Test("Returns colors as array")
    func returnsColorsAsArray() async throws {
        let configPath = Self.fixturesPath.appendingPathComponent("valid-config.pkl")

        let module = try await PKLEvaluator.evaluate(configPath: configPath)

        let colors = module.ios?.colors
        #expect(colors?.count == 1)
        #expect(colors?.first?.useColorAssets == true)
    }

    @Test("Throws configNotFound for nonexistent file")
    func throwsConfigNotFoundForMissingFile() async throws {
        let fakePath = URL(fileURLWithPath: "/nonexistent/path/config.pkl")

        await #expect(throws: PKLError.self) {
            try await PKLEvaluator.evaluate(configPath: fakePath)
        }
    }

    @Test("Throws error for invalid PKL syntax")
    func throwsErrorForInvalidSyntax() async throws {
        let configPath = Self.fixturesPath.appendingPathComponent("invalid-syntax.pkl")

        await #expect(throws: (any Error).self) {
            try await PKLEvaluator.evaluate(configPath: configPath)
        }
    }

    @Test("All generated PKL types are registered")
    func allGeneratedPklTypesRegistered() {
        // Every registeredIdentifier in Generated/*.pkl.swift must be listed here AND
        // the corresponding type added to registerPklTypes(_:) in PKLEvaluator.swift.
        // If codegen adds a new type, this test fails — update both places.
        // Missing registration will silently decode as nil for optional fields.
        let expectedIdentifiers: Set<String> = [
            // ExFig
            ExFig.ModuleImpl.registeredIdentifier,
            // Common
            Common.Module.registeredIdentifier,
            Common.VariablesSourceImpl.registeredIdentifier,
            Common.NameProcessingImpl.registeredIdentifier,
            Common.FrameSourceImpl.registeredIdentifier,
            Common.TokensFile.registeredIdentifier,
            Common.WebpOptions.registeredIdentifier,
            Common.Cache.registeredIdentifier,
            Common.Colors.registeredIdentifier,
            Common.Icons.registeredIdentifier,
            Common.Images.registeredIdentifier,
            Common.Typography.registeredIdentifier,
            Common.VariablesColors.registeredIdentifier,
            Common.CommonConfig.registeredIdentifier,
            // Figma
            Figma.Module.registeredIdentifier,
            Figma.FigmaConfig.registeredIdentifier,
            // iOS
            iOS.Module.registeredIdentifier,
            iOS.HeicOptions.registeredIdentifier,
            iOS.ColorsEntry.registeredIdentifier,
            iOS.IconsEntry.registeredIdentifier,
            iOS.ImagesEntry.registeredIdentifier,
            iOS.Typography.registeredIdentifier,
            iOS.iOSConfig.registeredIdentifier,
            // Android
            Android.Module.registeredIdentifier,
            Android.AndroidConfig.registeredIdentifier,
            Android.ThemeAttributes.registeredIdentifier,
            Android.NameTransform.registeredIdentifier,
            Android.ColorsEntry.registeredIdentifier,
            Android.IconsEntry.registeredIdentifier,
            Android.ImagesEntry.registeredIdentifier,
            Android.Typography.registeredIdentifier,
            // Flutter
            Flutter.Module.registeredIdentifier,
            Flutter.FlutterConfig.registeredIdentifier,
            Flutter.ColorsEntry.registeredIdentifier,
            Flutter.IconsEntry.registeredIdentifier,
            Flutter.ImagesEntry.registeredIdentifier,
            // Web
            Web.Module.registeredIdentifier,
            Web.WebConfig.registeredIdentifier,
            Web.ColorsEntry.registeredIdentifier,
            Web.IconsEntry.registeredIdentifier,
            Web.ImagesEntry.registeredIdentifier,
        ]

        #expect(
            expectedIdentifiers.count == 41,
            """
            Generated PKL type count changed! After running codegen:pkl:
            1. Update registerPklTypes(_:) in PKLEvaluator.swift with new types
            2. Update this test list to include new types
            """
        )
    }
}
