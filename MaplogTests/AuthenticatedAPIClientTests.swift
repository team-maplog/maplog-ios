import XCTest
@testable import Maplog

@MainActor
final class AuthenticatedAPIClientTests: XCTestCase {
    override func tearDown() {
        SessionURLProtocol.handler = nil
        super.tearDown()
    }

    func testLateAuthenticationFailureCannotEndNewLogin() async throws {
        let session = GenerationSession()
        let refresher = ClientRefreshSpy(session: session)
        let client = makeClient(session, refresher)
        SessionURLProtocol.handler = { protocolInstance in
            Task { @MainActor in
                try session.startSession(with: .init(accessToken: "account-b", refreshToken: "refresh-b"))
                protocolInstance.reply(status: 401, body: Self.errorBody("WRONG_TOKEN"))
            }
        }
        do {
            _ = try await client.data(for: request)
            XCTFail("Expected cancellation")
        } catch is CancellationError { }
        XCTAssertEqual(try session.currentAccessToken(), "account-b")
        XCTAssertEqual(session.endCount, 0)
        XCTAssertEqual(refresher.calls, 0)
    }

    func testLateSuccessCannotReturnDataFromPreviousAccount() async throws {
        let session = GenerationSession()
        let client = makeClient(session, ClientRefreshSpy(session: session))
        SessionURLProtocol.handler = { protocolInstance in
            Task { @MainActor in
                try session.startSession(with: .init(accessToken: "account-b", refreshToken: "refresh-b"))
                protocolInstance.reply(status: 200, body: "{\"value\":1}")
            }
        }
        do {
            let _: ClientTestResponse = try await client.request(request, responseType: ClientTestResponse.self)
            XCTFail("Expected cancellation")
        } catch is CancellationError { }
    }

    func testOldExpiredResponseUsesAlreadyRotatedTokenWithoutRefresh() async throws {
        let session = GenerationSession()
        let refresher = ClientRefreshSpy(session: session)
        let client = makeClient(session, refresher)
        var calls = 0
        SessionURLProtocol.handler = { protocolInstance in
            Task { @MainActor in
                calls += 1
                if calls == 1 {
                    try session.replaceTokens(with: .init(accessToken: "rotated", refreshToken: "new-refresh"))
                    protocolInstance.reply(status: 401, body: Self.errorBody("EXPIRED_TOKEN"))
                } else {
                    XCTAssertEqual(protocolInstance.request.value(forHTTPHeaderField: "Authorization"), "Bearer rotated")
                    protocolInstance.reply(status: 200, body: "ok")
                }
            }
        }
        let data = try await client.data(for: request)
        XCTAssertEqual(data, Data("ok".utf8))
        XCTAssertEqual(refresher.calls, 0)
        XCTAssertEqual(calls, 2)
    }

    func testExpiredRequestRefreshesAndRetriesOnlyOnce() async throws {
        let session = GenerationSession()
        let refresher = ClientRefreshSpy(session: session)
        let client = makeClient(session, refresher)
        var calls = 0
        SessionURLProtocol.handler = { protocolInstance in
            Task { @MainActor in
                calls += 1
                protocolInstance.reply(status: 401, body: Self.errorBody("EXPIRED_TOKEN"))
            }
        }
        do { _ = try await client.data(for: request); XCTFail("Expected error") }
        catch APIError.server { }
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(refresher.calls, 1)
    }

    func testCurrentSessionInvalidTokenStillEndsSession() async throws {
        let session = GenerationSession()
        let client = makeClient(session, ClientRefreshSpy(session: session))
        SessionURLProtocol.handler = { $0.reply(status: 401, body: Self.errorBody("WRONG_TOKEN")) }
        do { _ = try await client.data(for: request); XCTFail("Expected error") }
        catch APIError.server { }
        XCTAssertEqual(session.endCount, 1)
        XCTAssertNil(try session.currentAccessToken())
    }

    private var request: URLRequest { URLRequest(url: URL(string: "https://example.invalid/resource")!) }
    private static func errorBody(_ code: String) -> String {
        "{\"successFlag\":false,\"code\":\"\(code)\",\"message\":\"error\",\"data\":null}"
    }
    private func makeClient(_ session: GenerationSession, _ refresher: ClientRefreshSpy) -> AuthenticatedAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SessionURLProtocol.self]
        return AuthenticatedAPIClient(apiClient: APIClient(session: URLSession(configuration: configuration)),
                                      authSession: session, tokenRefresher: refresher)
    }
}

private struct ClientTestResponse: Decodable { let value: Int }

@MainActor
private final class ClientRefreshSpy: AccessTokenRefreshing {
    let session: GenerationSession
    private(set) var calls = 0
    init(session: GenerationSession) { self.session = session }
    func refreshAccessToken() async throws {
        calls += 1
        try session.replaceTokens(with: .init(accessToken: "rotated", refreshToken: "rotated-refresh"))
    }
}

private final class SessionURLProtocol: URLProtocol {
    static var handler: ((SessionURLProtocol) -> Void)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.handler?(self) }
    override func stopLoading() { }
    func reply(status: Int, body: String) {
        let response = HTTPURLResponse(url: request.url!, statusCode: status,
                                       httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
