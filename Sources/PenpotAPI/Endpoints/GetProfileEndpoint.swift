import Foundation
import YYJSON

/// Retrieves the authenticated user's profile.
///
/// Command: `get-profile`
/// Body: none
public struct GetProfileEndpoint: PenpotEndpoint {
    public typealias Content = PenpotProfile

    public let commandName = "get-profile"

    public init() {}

    public func body() throws -> Data? {
        nil
    }

    public func content(from data: Data) throws -> PenpotProfile {
        try YYJSONDecoder().decode(PenpotProfile.self, from: data)
    }
}
