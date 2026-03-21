import Foundation

/// Callback for spinner-based progress indication.
public typealias SpinnerCallback<T> = @Sendable (String, @escaping @Sendable () async throws -> T) async throws -> T

/// Callback for logging informational messages.
public typealias InfoLogger = @Sendable (String) -> Void

/// Callback for logging warning messages.
public typealias WarningLogger = @Sendable (String) -> Void

/// Callback for logging success messages.
public typealias SuccessLogger = @Sendable (String) -> Void

/// Protocol defining the dependencies needed for asset export operations.
///
/// `ExportContext` provides access to services that exporters need:
/// - Figma API client for fetching data
/// - Terminal UI for progress indication and user feedback
/// - File writer for saving exported files
/// - Batch mode state for coordinating parallel exports
///
/// ## Usage
///
/// Exporters receive a context through their export methods:
///
/// ```swift
/// func exportColors(
///     entries: [iOSColorsEntry],
///     platformConfig: iOSPlatformConfig,
///     context: some ExportContext
/// ) async throws -> Int
/// ```
public protocol ExportContext: Sendable {
    /// Whether the export is running in batch mode.
    var isBatchMode: Bool { get }

    /// Filter string for selective export (e.g., "background/*").
    var filter: String? { get }

    /// Writes files to the filesystem.
    func writeFiles(_ files: [FileContents]) throws

    /// Logs an informational message.
    func info(_ message: String)

    /// Logs a warning message.
    func warning(_ message: String)

    /// Logs a success message.
    func success(_ message: String)

    /// Runs an operation with a spinner indicator.
    func withSpinner<T: Sendable>(
        _ message: String,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T
}

// MARK: - Colors Export Context

/// Context for colors export operations.
///
/// Extends `ExportContext` with colors-specific functionality
/// like loading and processing colors.
public protocol ColorsExportContext: ExportContext {
    /// Loads colors from Figma Variables.
    ///
    /// - Parameters:
    ///   - source: Variables source configuration.
    ///   - filter: Optional filter string.
    /// - Returns: Loaded colors output (light, dark, etc.).
    func loadColors(
        from source: ColorsSourceInput
    ) async throws -> ColorsLoadOutput

    /// Processes colors into platform-specific format.
    ///
    /// - Parameters:
    ///   - colors: Raw colors from Figma.
    ///   - platform: Target platform.
    ///   - nameProcessing: Name validation and replacement config.
    ///   - nameStyle: Naming style for generated code.
    /// - Returns: Processed color pairs.
    func processColors(
        _ colors: ColorsLoadOutput,
        platform: Platform,
        nameValidateRegexp: String?,
        nameReplaceRegexp: String?,
        nameStyle: NameStyle
    ) throws -> ColorsProcessResult
}

/// Input for loading colors from any design source.
///
/// Source-specific fields live in `sourceConfig` (see `ColorsSourceConfig`).
/// Shared fields (`nameValidateRegexp`, `nameReplaceRegexp`) apply to all sources.
/// Dispatch is handled by `SourceFactory` using `sourceKind`.
public struct ColorsSourceInput: Sendable {
    public let sourceKind: DesignSourceKind
    public let sourceConfig: any ColorsSourceConfig
    public let nameValidateRegexp: String?
    public let nameReplaceRegexp: String?

    public init(
        sourceKind: DesignSourceKind,
        sourceConfig: any ColorsSourceConfig,
        nameValidateRegexp: String? = nil,
        nameReplaceRegexp: String? = nil
    ) {
        self.sourceKind = sourceKind
        self.sourceConfig = sourceConfig
        self.nameValidateRegexp = nameValidateRegexp
        self.nameReplaceRegexp = nameReplaceRegexp
    }

    /// Human-readable label for spinner messages (e.g., "Figma Variables (Brand Colors)").
    public var spinnerLabel: String {
        switch sourceKind {
        case .figma:
            if let config = sourceConfig as? FigmaColorsConfig {
                return "Figma Variables (\(config.tokensCollectionName))"
            }
            return "Figma"
        case .tokensFile:
            if let config = sourceConfig as? TokensFileColorsConfig {
                return URL(fileURLWithPath: config.filePath).lastPathComponent
            }
            return "tokens file"
        case .penpot, .tokensStudio, .sketchFile:
            return sourceKind.rawValue
        }
    }
}

/// Error thrown when required colors configuration fields are missing.
public enum ColorsConfigError: LocalizedError {
    case missingTokensFileId
    case missingTokensCollectionName
    case missingLightModeName

    public var errorDescription: String? {
        switch self {
        case .missingTokensFileId:
            "tokensFileId is required for colors export"
        case .missingTokensCollectionName:
            "tokensCollectionName is required for colors export"
        case .missingLightModeName:
            "lightModeName is required for colors export"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .missingTokensFileId:
            "Add 'tokensFileId' to your colors entry, or set common.variablesColors"
        case .missingTokensCollectionName:
            "Add 'tokensCollectionName' to your colors entry, or set common.variablesColors"
        case .missingLightModeName:
            "Add 'lightModeName' to your colors entry, or set common.variablesColors"
        }
    }
}

/// Output from colors loading.
public struct ColorsLoadOutput: Sendable {
    public let light: [Color]
    public let dark: [Color]
    public let lightHC: [Color]
    public let darkHC: [Color]

    public init(
        light: [Color],
        dark: [Color] = [],
        lightHC: [Color] = [],
        darkHC: [Color] = []
    ) {
        self.light = light
        self.dark = dark
        self.lightHC = lightHC
        self.darkHC = darkHC
    }
}

/// Result from colors processing.
public struct ColorsProcessResult: Sendable {
    public let colorPairs: [AssetPair<Color>]
    public let warning: String?

    public init(colorPairs: [AssetPair<Color>], warning: String? = nil) {
        self.colorPairs = colorPairs
        self.warning = warning
    }
}
