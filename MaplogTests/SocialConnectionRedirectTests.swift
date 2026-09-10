import XCTest
@testable import Maplog

final class SocialConnectionRedirectTests: XCTestCase {
    func testAcceptsMatchingHTTPSProviderURL() async throws {
        let service = ConnectionRedirectServiceStub()
        let url = try await DefaultSocialConnectionRepository(apiService: service).connectionRedirectURL(provider: "google")
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(service.requestedProvider, "google")
    }

    func testRejectsInsecureRedirect() async {
        let service = ConnectionRedirectServiceStub()
        service.url = "http://example.com/authorize"
        do {
            _ = try await DefaultSocialConnectionRepository(apiService: service).connectionRedirectURL(provider: "google")
            XCTFail("An insecure redirect must be rejected")
        } catch {}
    }

    func testRejectsDifferentProviderResponse() async {
        let service = ConnectionRedirectServiceStub()
        service.provider = "apple"
        do {
            _ = try await DefaultSocialConnectionRepository(apiService: service).connectionRedirectURL(provider: "google")
            XCTFail("Mismatched provider must be rejected")
        } catch {}
    }
}

private final class ConnectionRedirectServiceStub: SocialConnectionAPIService {
    var url = "https://example.com/authorize"
    var provider = "google"
    var requestedProvider: String?

    func fetchConnectionRedirect(provider: String) async throws -> OAuthRedirectResponseDTO {
        requestedProvider = provider
        return OAuthRedirectResponseDTO(registrationID: self.provider, redirectURL: url)
    }
    func fetchConnections() async throws -> [SocialConnectionResponseDTO] { [] }
    func disconnect(provider: String) async throws -> SocialConnectionResponseDTO {
        throw APIError.invalidResponse
    }
}
