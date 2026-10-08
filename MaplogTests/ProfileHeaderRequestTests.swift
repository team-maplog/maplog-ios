import XCTest
@testable import Maplog

@MainActor
final class ProfileHeaderRequestTests: XCTestCase {
    func testMyProfileRefreshBypassesLocalCacheAndKeepsAPIContract() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ProfileHeaderURLProtocol.self]
        let client = AuthenticatedAPIClient(apiClient: APIClient(session: URLSession(configuration: configuration)),
                                            authSession: GenerationSession(), tokenRefresher: HeaderRefreshUnused())
        let service = DefaultProfileAPIService(authenticatedAPIClient: client, imageDataLoader: HeaderImageLoaderUnused())
        let userID = UUID()
        var requests: [URLRequest] = []
        ProfileHeaderURLProtocol.handler = { instance in
            Task { @MainActor in
                requests.append(instance.request)
                instance.reply(body: "{\"successFlag\":true,\"code\":\"SUCCESS-002\",\"message\":\"ok\",\"data\":{\"userId\":\"\(userID.uuidString)\",\"nickname\":\"fixture\",\"profileImageUrl\":null,\"bio\":\"\",\"followerCount\":12,\"followingCount\":9,\"logCount\":1}}")
            }
        }
        defer { ProfileHeaderURLProtocol.handler = nil }
        let response = try await service.fetchMyProfile()
        XCTAssertEqual(response.userID, userID)
        XCTAssertEqual(response.followingCount, 9)
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.url?.path, "/api/v1/users/me")
        XCTAssertEqual(requests.first?.httpMethod, "GET")
        XCTAssertEqual(requests.first?.cachePolicy, .reloadIgnoringLocalCacheData)
    }
}

@MainActor
private final class HeaderRefreshUnused: AccessTokenRefreshing {
    func refreshAccessToken() async throws { XCTFail("Unexpected refresh") }
}

private final class HeaderImageLoaderUnused: ImageDataLoading {
    func imageData(from url: URL, cacheKey: String, targetSize: MaplogImageTargetSize) async throws -> Data {
        XCTFail("Header refresh must not load images")
        return Data()
    }
}

private final class ProfileHeaderURLProtocol: URLProtocol {
    static var handler: ((ProfileHeaderURLProtocol) -> Void)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.handler?(self) }
    override func stopLoading() {}
    func reply(body: String) {
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
