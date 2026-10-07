import XCTest
@testable import Maplog

@MainActor
final class AuthSessionGenerationTests: XCTestCase {
    func testLateRefreshDoesNotRestoreLogout() async throws {
        let session = GenerationSession()
        let repository = ControlledRefreshRepository()
        let refresher = DefaultAccessTokenRefresher(authRepository: repository, authSession: session)
        let pending = Task { try await refresher.refreshAccessToken() }
        await repository.waitForRequest()
        try session.endSession()
        repository.finish(with: .success(.init(accessToken: "rotated", refreshToken: "rotated-refresh")))
        await assertCancelled(pending)
        XCTAssertNil(try session.currentAccessToken())
        XCTAssertEqual(session.replacementCount, 0)
    }

    func testLateRefreshDoesNotOverwriteNewLogin() async throws {
        let session = GenerationSession()
        let repository = ControlledRefreshRepository()
        let refresher = DefaultAccessTokenRefresher(authRepository: repository, authSession: session)
        let pending = Task { try await refresher.refreshAccessToken() }
        await repository.waitForRequest()
        try session.startSession(with: .init(accessToken: "account-b", refreshToken: "refresh-b"))
        repository.finish(with: .success(.init(accessToken: "rotated-a", refreshToken: "refresh-a")))
        await assertCancelled(pending)
        XCTAssertEqual(try session.currentAccessToken(), "account-b")
        XCTAssertEqual(repository.credentials, ["refresh-a"])
    }

    func testLateRefreshFailureBecomesCancellation() async throws {
        let session = GenerationSession()
        let repository = ControlledRefreshRepository()
        let refresher = DefaultAccessTokenRefresher(authRepository: repository, authSession: session)
        let pending = Task { try await refresher.refreshAccessToken() }
        await repository.waitForRequest()
        try session.startSession(with: .init(accessToken: "account-b", refreshToken: "refresh-b"))
        repository.finish(with: .failure(APIError.missingRefreshToken))
        await assertCancelled(pending)
        XCTAssertEqual(try session.currentAccessToken(), "account-b")
    }

    func testNewSessionRefreshDoesNotJoinOldSessionTask() async throws {
        let session = GenerationSession()
        let repository = ControlledRefreshRepository()
        let refresher = DefaultAccessTokenRefresher(authRepository: repository, authSession: session)
        let old = Task { try await refresher.refreshAccessToken() }
        await repository.waitForRequest()
        try session.startSession(with: .init(accessToken: "account-b", refreshToken: "refresh-b"))
        let current = Task { try await refresher.refreshAccessToken() }
        await repository.waitForRequest(count: 2)
        repository.finish(with: .success(.init(accessToken: "rotated-a", refreshToken: "refresh-a")), index: 0)
        await assertCancelled(old)
        let joined = Task { try await refresher.refreshAccessToken() }
        await Task.yield()
        repository.finish(with: .success(.init(accessToken: "rotated-b", refreshToken: "new-refresh-b")), index: 1)
        try await current.value
        try await joined.value
        XCTAssertEqual(repository.credentials, ["refresh-a", "refresh-b"])
        XCTAssertEqual(try session.currentAccessToken(), "rotated-b")
        XCTAssertEqual(session.replacementCount, 1)
    }

    private func assertCancelled(_ task: Task<Void, Error>) async {
        do { try await task.value; XCTFail("Expected obsolete session cancellation") }
        catch is CancellationError { }
        catch { XCTFail("Unexpected error: \(error)") }
    }
}

@MainActor
final class GenerationSession: AuthSessionManaging {
    var sessionGeneration = UUID()
    private var token: AuthToken? = .init(accessToken: "account-a", refreshToken: "refresh-a")
    private(set) var replacementCount = 0
    private(set) var endCount = 0
    func currentAccessToken() throws -> String? { token?.accessToken }
    func currentRefreshToken() throws -> String? { token?.refreshToken }
    func startSession(with token: AuthToken) throws { sessionGeneration = UUID(); self.token = token }
    func replaceTokens(with token: AuthToken) throws { replacementCount += 1; self.token = token }
    func endSession() throws { sessionGeneration = UUID(); token = nil; endCount += 1 }
}

@MainActor
private final class ControlledRefreshRepository: AuthRepository {
    private(set) var credentials: [String] = []
    private var completions: [CheckedContinuation<AuthToken, Error>] = []
    private var requestWaiter: (count: Int, continuation: CheckedContinuation<Void, Never>)?
    func reissueToken(refreshToken: String) async throws -> AuthToken {
        try await withCheckedThrowingContinuation { continuation in
            credentials.append(refreshToken)
            completions.append(continuation)
            if let waiter = requestWaiter, credentials.count >= waiter.count {
                requestWaiter = nil
                waiter.continuation.resume()
            }
        }
    }
    func waitForRequest(count: Int = 1) async {
        if credentials.count >= count { return }
        await withCheckedContinuation { requestWaiter = (count, $0) }
    }
    func finish(with result: Result<AuthToken, Error>, index: Int = 0) {
        completions[index].resume(with: result)
    }
    func signUp(credentials: SignUpCredentials) async throws -> AuthToken { throw APIError.invalidResponse }
    func signIn(credentials: SignInCredentials) async throws -> AuthToken { throw APIError.invalidResponse }
    func signOut() async throws { }
}
