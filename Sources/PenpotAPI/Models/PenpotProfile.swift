import Foundation

/// User profile returned by the `get-profile` endpoint.
public struct PenpotProfile: Decodable, Sendable {
    /// User ID.
    public let id: String

    /// Full display name.
    public let fullname: String

    /// Email address.
    public let email: String
}
