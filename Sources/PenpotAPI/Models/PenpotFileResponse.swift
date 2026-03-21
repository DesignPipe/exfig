import Foundation

/// Top-level response from the `get-file` endpoint.
public struct PenpotFileResponse: Decodable, Sendable {
    /// The file data containing library assets.
    public let data: PenpotFileData

    /// File ID.
    public let id: String

    /// File name.
    public let name: String
}

/// File data with selective decoding of library assets.
public struct PenpotFileData: Decodable, Sendable {
    /// Library colors keyed by UUID.
    public let colors: [String: PenpotColor]?

    /// Library typographies keyed by UUID.
    public let typographies: [String: PenpotTypography]?

    /// Library components keyed by UUID.
    public let components: [String: PenpotComponent]?
}
