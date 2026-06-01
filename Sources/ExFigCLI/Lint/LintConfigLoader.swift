import ExFigConfig
import Foundation

/// Loads optional lint-only overlay configuration for `exfig lint`.
enum LintConfigLoader {
    static let defaultFileName = "lint.pkl"

    static func resolvePath(explicitPath: String?, mainConfigPath: String?) -> URL? {
        if let explicitPath, !explicitPath.isEmpty {
            return URL(fileURLWithPath: explicitPath)
        }

        let mainPath = mainConfigPath ?? ExFigOptions.defaultConfigFilename
        let mainURL = URL(fileURLWithPath: mainPath)
        let lintURL = mainURL.deletingLastPathComponent().appendingPathComponent(defaultFileName)

        guard FileManager.default.fileExists(atPath: lintURL.path) else {
            return nil
        }
        return lintURL
    }

    static func load(explicitPath: String?, mainConfigPath: String?) async throws -> ExFigConfig.Lint.ModuleImpl? {
        guard let path = resolvePath(explicitPath: explicitPath, mainConfigPath: mainConfigPath) else {
            return nil
        }
        return try await PKLEvaluator.evaluateLintConfig(configPath: path)
    }
}
