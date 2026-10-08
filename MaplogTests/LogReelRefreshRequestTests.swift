import XCTest
@testable import Maplog

@MainActor
final class LogReelRefreshRequestTests: XCTestCase {
    override func tearDown() {
        ReelRefreshURLProtocol.handler = nil
        super.tearDown()
    }

    func testMutableListsBypassLocalHTTPCacheAndKeepQueryContract() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ReelRefreshURLProtocol.self]
        let client = AuthenticatedAPIClient(apiClient: APIClient(session: URLSession(configuration: configuration)),
                                            authSession: GenerationSession(), tokenRefresher: UnusedReelRefresher())
        let service = DefaultLogReelAPIService(authenticatedAPIClient: client)
        var requests: [URLRequest] = []
        ReelRefreshURLProtocol.handler = { instance in
            Task { @MainActor in
                requests.append(instance.request)
                instance.reply(body: "{\"successFlag\":true,\"code\":\"SUCCESS-002\",\"message\":\"ok\",\"data\":{\"content\":[],\"hasNext\":false,\"nextCursor\":null}}")
            }
        }
        let reels = try await service.fetchReels(cursor: nil, size: 20)
        let saves = try await service.fetchSavedLogs(cursor: "cursor-fixture", size: 10)
        XCTAssertTrue(reels.content.isEmpty)
        XCTAssertTrue(saves.content.isEmpty)
        XCTAssertEqual(requests.map(\.cachePolicy), [.reloadIgnoringLocalCacheData, .reloadIgnoringLocalCacheData])
        XCTAssertEqual(requests.map(\.httpMethod), ["GET", "GET"])
        XCTAssertEqual(requests.map { $0.url!.path }, ["/api/v1/logs/reels", "/api/v1/logs/saves"])
        XCTAssertEqual(URLComponents(url: requests[0].url!, resolvingAgainstBaseURL: false)?.queryItems,
                       [URLQueryItem(name: "size", value: "20")])
        XCTAssertEqual(URLComponents(url: requests[1].url!, resolvingAgainstBaseURL: false)?.queryItems,
                       [URLQueryItem(name: "size", value: "10"), URLQueryItem(name: "cursor", value: "cursor-fixture")])
    }
}

@MainActor
private final class UnusedReelRefresher: AccessTokenRefreshing {
    func refreshAccessToken() async throws { XCTFail("Unexpected refresh") }
}

private final class ReelRefreshURLProtocol: URLProtocol {
    static var handler: ((ReelRefreshURLProtocol) -> Void)?
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
