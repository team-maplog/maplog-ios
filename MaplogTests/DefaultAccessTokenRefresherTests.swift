import XCTest

@testable import Maplog

@MainActor
final class DefaultAccessTokenRefresherTests: XCTestCase {
    func test_refreshAccessToken_whenRequestsOverlap_reissuesOnce()
        async throws {
        let authRepository = AuthRepositorySpy()
        let authSession = AuthSessionSpy()

        let refresher = DefaultAccessTokenRefresher(
            authRepository: authRepository,
            authSession: authSession
        )

            // 세 요청을 순서대로 끝낼 때까지 기다리는 게 아니라, 겹치게 시작시킴. 실제 앱에서 썸네일·릴스·관광 API가 동시에 만료되는 상황을 흉내 낼 수 있음
        async let first: Void = refresher.refreshAccessToken()
        async let second: Void = refresher.refreshAccessToken()
        async let third: Void = refresher.refreshAccessToken()

        _ = try await (first, second, third)

        let reissueCallCount = await authRepository
            .recordedReissueCallCount()

        XCTAssertEqual(reissueCallCount, 1)
        XCTAssertEqual(authSession.replacedTokens.count, 1)
    }
}//
//  DefaultAccessTokenRefresherTests.swift
//  Maplog
//
//  Created by 한채림 on 8/16/26.
//


private actor AuthRepositorySpy: AuthRepository {
    private var reissueCallCount = 0

    private let refreshedToken = AuthToken(
        accessToken: "new-access-token",
        refreshToken: "new-refresh-token"
    )

    func signIn(
        credentials: SignInCredentials
    ) async throws -> AuthToken {
        refreshedToken
    }

    func signUp(
        credentials: SignUpCredentials
    ) async throws -> AuthToken {
        refreshedToken
    }

    func signOut() async throws { }

    func reissueToken() async throws -> AuthToken {
        reissueCallCount += 1

        try await Task.sleep(
            nanoseconds: 100_000_000
        )

        return refreshedToken
    }

    func recordedReissueCallCount() -> Int {
        reissueCallCount
    }
}


@MainActor
private final class AuthSessionSpy: AuthSessionManaging {
    private(set) var replacedTokens: [AuthToken] = []

    func currentAccessToken() throws -> String? {
        "old-access-token"
    }

    func currentRefreshToken() throws -> String? {
        "old-refresh-token"
    }

    func replaceTokens(
        with token: AuthToken
    ) throws {
        replacedTokens.append(token)
    }

    func endSession() throws { }
}
