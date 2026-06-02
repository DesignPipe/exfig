import Foundation

/// Extracts bundled PKL schemas to a local directory.
///
/// Used by `exfig init` and `exfig schemas` to provide local schema files
/// that enable `pkl eval` without a published PKL package.
enum SchemaExtractor {
    static let schemaFiles = [
        "ExFig.pkl", "Figma.pkl", "Common.pkl",
        "iOS.pkl", "Android.pkl", "Flutter.pkl", "Web.pkl", "Lint.pkl",
        "PklProject",
    ]

    static let defaultOutputDir = ".exfig/schemas"
    static let versionFileName = ".version"

    /// Extracts all PKL schema files from the app bundle to the specified directory.
    ///
    /// - Parameters:
    ///   - directory: Target directory path (relative or absolute). Defaults to `.exfig/schemas`.
    ///   - force: If `true`, overwrites existing files. If `false`, skips files that already exist.
    /// - Returns: List of extracted file names.
    @discardableResult
    static func extract(to directory: String = defaultOutputDir, force: Bool = false) throws -> [String] {
        let fileManager = FileManager.default

        // Resolve relative paths against current working directory
        let outputURL = if directory.hasPrefix("/") {
            URL(fileURLWithPath: directory)
        } else {
            URL(fileURLWithPath: fileManager.currentDirectoryPath)
                .appendingPathComponent(directory)
        }

        // Create output directory if needed
        try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)

        // Find bundled schemas
        guard let schemasURL = Bundle.module.url(forResource: "Schemas", withExtension: nil) else {
            throw ExFigError.custom(errorString: "PKL schemas not found in application bundle")
        }

        var extracted: [String] = []

        for fileName in schemaFiles {
            let sourceURL = schemasURL.appendingPathComponent(fileName)
            let destURL = outputURL.appendingPathComponent(fileName)

            guard fileManager.fileExists(atPath: sourceURL.path) else {
                throw ExFigError.custom(errorString: "Schema file missing from bundle: \(fileName)")
            }

            if fileManager.fileExists(atPath: destURL.path) {
                if force {
                    try fileManager.removeItem(at: destURL)
                } else {
                    continue
                }
            }

            try fileManager.copyItem(at: sourceURL, to: destURL)
            extracted.append(fileName)
        }

        // Write version file when schemas are extracted
        if !extracted.isEmpty {
            let versionURL = outputURL.appendingPathComponent(versionFileName)
            try Data(ExFigCommand.version.utf8).write(to: versionURL)
        }

        return extracted
    }

    // MARK: - Version Check

    /// Result of comparing extracted schema version with the current CLI version.
    enum VersionCheckResult {
        /// Versions match.
        case matched
        /// Versions don't match.
        case mismatch(schemasVersion: String, cliVersion: String)
        /// No version file found (schemas extracted by older version or manually).
        case noVersionFile
        /// Schemas directory doesn't exist.
        case noSchemasDirectory
    }

    /// Checks whether extracted schemas match the current CLI version.
    ///
    /// - Parameter directory: Path to the schemas directory. Defaults to `.exfig/schemas`.
    /// - Returns: Result of the version comparison.
    static func checkVersion(at directory: String = defaultOutputDir) -> VersionCheckResult {
        let fileManager = FileManager.default

        let dirURL = if directory.hasPrefix("/") {
            URL(fileURLWithPath: directory)
        } else {
            URL(fileURLWithPath: fileManager.currentDirectoryPath)
                .appendingPathComponent(directory)
        }

        guard fileManager.fileExists(atPath: dirURL.path) else {
            return .noSchemasDirectory
        }

        let versionURL = dirURL.appendingPathComponent(versionFileName)
        guard let data = fileManager.contents(atPath: versionURL.path),
              let schemasVersion = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        else {
            return .noVersionFile
        }

        let cliVersion = ExFigCommand.version
        if schemasVersion == cliVersion {
            return .matched
        } else {
            return .mismatch(schemasVersion: schemasVersion, cliVersion: cliVersion)
        }
    }
}
