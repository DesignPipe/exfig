import Foundation
@testable import PenpotAPI
import Testing

@Suite("PenpotAPIError")
struct PenpotAPIErrorTests {
    @Test("401 error suggests checking PENPOT_ACCESS_TOKEN")
    func authError() {
        let error = PenpotAPIError(statusCode: 401, message: "Unauthorized", endpoint: "get-profile")
        #expect(error.recoverySuggestion?.contains("PENPOT_ACCESS_TOKEN") == true)
        #expect(error.errorDescription?.contains("get-profile") == true)
    }

    @Test("404 error suggests checking file UUID")
    func notFoundError() {
        let error = PenpotAPIError(statusCode: 404, message: "Not found", endpoint: "get-file")
        #expect(error.recoverySuggestion?.contains("UUID") == true)
    }

    @Test("429 error mentions rate limiting")
    func rateLimitError() {
        let error = PenpotAPIError(statusCode: 429, message: nil, endpoint: "get-file")
        #expect(error.recoverySuggestion?.contains("Rate") == true)
    }

    @Test("500 error suggests server-side issue")
    func serverError() {
        let error = PenpotAPIError(statusCode: 500, message: "Internal error", endpoint: "get-file")
        #expect(error.recoverySuggestion?.contains("server error") == true)
    }

    @Test("0 status code suggests network error")
    func networkError() {
        let error = PenpotAPIError(statusCode: 0, message: nil, endpoint: "get-file")
        #expect(error.recoverySuggestion?.contains("network") == true)
    }

    @Test("Error description includes endpoint and status code")
    func errorDescription() {
        let error = PenpotAPIError(statusCode: 403, message: "Forbidden", endpoint: "get-file")
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("403"))
        #expect(desc.contains("get-file"))
        #expect(desc.contains("Forbidden"))
    }
}
