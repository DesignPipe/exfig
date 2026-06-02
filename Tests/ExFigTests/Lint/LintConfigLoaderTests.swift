@testable import ExFigCLI
import Foundation
import Testing

struct LintConfigLoaderTests {
    @Test("returns nil when autodetected lint config is absent")
    func returnsNilWhenAutodetectedLintConfigAbsent() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let mainConfig = tempDir.appendingPathComponent("exfig.pkl")

        let resolved = LintConfigLoader.resolvePath(
            explicitPath: nil,
            mainConfigPath: mainConfig.path
        )

        #expect(resolved == nil)
    }

    @Test("autodetects lint config next to main config")
    func autodetectsLintConfigNextToMainConfig() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let lintConfig = tempDir.appendingPathComponent("lint.pkl")
        try Data().write(to: lintConfig)

        let resolved = LintConfigLoader.resolvePath(
            explicitPath: nil,
            mainConfigPath: tempDir.appendingPathComponent("exfig.pkl").path
        )

        #expect(resolved == lintConfig)
    }

    @Test("explicit lint config path wins over autodetect")
    func explicitLintConfigPathWins() {
        let explicit = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("custom-lint.pkl")

        let resolved = LintConfigLoader.resolvePath(
            explicitPath: explicit.path,
            mainConfigPath: nil
        )

        #expect(resolved == explicit)
    }
}
