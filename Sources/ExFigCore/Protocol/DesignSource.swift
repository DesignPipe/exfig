import Foundation

// MARK: - Design Source Kind

/// Identifies the design tool or data source for asset loading.
///
/// Used by `SourceFactory` for dispatch. Source protocols do NOT expose this —
/// consumers call `loadColors()` etc. without knowing the source kind.
public enum DesignSourceKind: String, Sendable, CaseIterable {
    case figma
    case penpot
    case tokensFile
    case tokensStudio
    case sketchFile
}

// MARK: - Source Protocols

/// Loads colors from a design source (Figma Variables, local .tokens.json, etc.).
public protocol ColorsSource: Sendable {
    func loadColors(from input: ColorsSourceInput) async throws -> ColorsLoadOutput
}

/// Loads icons and images from a design source (Figma components, Penpot, etc.).
public protocol ComponentsSource: Sendable {
    func loadIcons(from input: IconsSourceInput) async throws -> IconsLoadOutput
    func loadImages(from input: ImagesSourceInput) async throws -> ImagesLoadOutput
}

/// Loads text styles from a design source (Figma styles, etc.).
public protocol TypographySource: Sendable {
    func loadTypography(from input: TypographySourceInput) async throws -> TypographyLoadOutput
}

// MARK: - Colors Source Config

/// Marker protocol for source-specific colors configuration.
///
/// Each design source has its own config type conforming to this protocol.
/// `ColorsSourceInput` holds `any ColorsSourceConfig`, and source implementations
/// cast it to their expected concrete type.
public protocol ColorsSourceConfig: Sendable {}

/// Figma-specific colors configuration — fields for Variables API.
public struct FigmaColorsConfig: ColorsSourceConfig {
    public let tokensFileId: String
    public let tokensCollectionName: String
    public let lightModeName: String
    public let darkModeName: String?
    public let lightHCModeName: String?
    public let darkHCModeName: String?
    public let primitivesModeName: String?

    public init(
        tokensFileId: String,
        tokensCollectionName: String,
        lightModeName: String,
        darkModeName: String? = nil,
        lightHCModeName: String? = nil,
        darkHCModeName: String? = nil,
        primitivesModeName: String? = nil
    ) {
        self.tokensFileId = tokensFileId
        self.tokensCollectionName = tokensCollectionName
        self.lightModeName = lightModeName
        self.darkModeName = darkModeName
        self.lightHCModeName = lightHCModeName
        self.darkHCModeName = darkHCModeName
        self.primitivesModeName = primitivesModeName
    }
}

/// Penpot-specific colors configuration — file ID, base URL, and path filter.
public struct PenpotColorsConfig: ColorsSourceConfig {
    public let fileId: String
    public let baseURL: String
    public let pathFilter: String?

    public init(
        fileId: String,
        baseURL: String = "https://design.penpot.app/",
        pathFilter: String? = nil
    ) {
        self.fileId = fileId
        self.baseURL = baseURL
        self.pathFilter = pathFilter
    }
}

/// Tokens-file-specific colors configuration — local .tokens.json path + optional group filter.
public struct TokensFileColorsConfig: ColorsSourceConfig {
    public let filePath: String
    public let groupFilter: String?
    /// Mode names from PKL config that will be ignored (tokens file is single-mode).
    /// Populated by validation when user sets darkModeName/lightHCModeName/darkHCModeName.
    public let ignoredModeNames: [String]

    public init(
        filePath: String,
        groupFilter: String? = nil,
        ignoredModeNames: [String] = []
    ) {
        self.filePath = filePath
        self.groupFilter = groupFilter
        self.ignoredModeNames = ignoredModeNames
    }
}
