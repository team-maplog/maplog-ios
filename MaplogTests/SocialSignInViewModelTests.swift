import XCTest

@testable import Maplog

@MainActor
final class SocialSignInViewModelTests: XCTestCase {
    func testSignInExchangesHandoffCodeAndEstablishesValidatedSession() async throws {
        let repository = OAuthRepositorySpy()
        let webSession = OAuthWebAuthenticationSessionSpy(
            callbackURL: try XCTUnwrap(
                URL(string: "https://maplog.millenniumrhino.com/auth/ios?handoffCode=one-time-code")
            )
        )
        let sessionLifecycle = AuthSessionLifecycleSpy()
        let viewModel = SocialSignInViewModel(
            oauthRepository: repository,
            webAuthenticationSession: webSession,
            sessionLifecycle: sessionLifecycle
        )

        await viewModel.signIn(provider: .kakao)

        let requestedProvider = await repository.requestedProvider()
        let exchangedHandoffCode = await repository.exchangedHandoffCode()
        XCTAssertEqual(requestedProvider, .kakao)
        XCTAssertEqual(exchangedHandoffCode, "one-time-code")
        XCTAssertEqual(sessionLifecycle.establishedTokens.count, 1)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testCancelledWebAuthenticationDoesNotShowError() async throws {
        let repository = OAuthRepositorySpy()
        let webSession = OAuthWebAuthenticationSessionSpy(
            callbackURL: try XCTUnwrap(URL(string: "https://maplog.millenniumrhino.com/auth/ios")),
            error: OAuthWebAuthenticationSessionError.cancelled
        )
        let sessionLifecycle = AuthSessionLifecycleSpy()
        let viewModel = SocialSignInViewModel(
            oauthRepository: repository,
            webAuthenticationSession: webSession,
            sessionLifecycle: sessionLifecycle
        )

        await viewModel.signIn(provider: .apple)

        let exchangedHandoffCode = await repository.exchangedHandoffCode()
        XCTAssertNil(exchangedHandoffCode)
        XCTAssertTrue(sessionLifecycle.establishedTokens.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testExpiredHandoffShowsRestartMessage() async throws {
        let repository = OAuthRepositorySpy(
            exchangeError: APIError.server(
                statusCode: 400,
                response: APIErrorResponse(
                    successFlag: false,
                    code: "OAUTH-014",
                    message: "invalid handoff",
                    data: nil
                )
            )
        )
        let webSession = OAuthWebAuthenticationSessionSpy(
            callbackURL: try XCTUnwrap(
                URL(string: "https://maplog.millenniumrhino.com/auth/ios?handoffCode=expired-code")
            )
        )
        let sessionLifecycle = AuthSessionLifecycleSpy()
        let viewModel = SocialSignInViewModel(
            oauthRepository: repository,
            webAuthenticationSession: webSession,
            sessionLifecycle: sessionLifecycle
        )

        await viewModel.signIn(provider: .google)

        XCTAssertEqual(viewModel.errorMessage, "로그인 시간이 만료되었어요. 처음부터 다시 시도해 주세요.")
        XCTAssertTrue(sessionLifecycle.establishedTokens.isEmpty)
    }

    func testInvalidValidatedSessionShowsRestartMessage() async throws {
        let repository = OAuthRepositorySpy()
        let webSession = OAuthWebAuthenticationSessionSpy(
            callbackURL: try XCTUnwrap(
                URL(string: "https://maplog.millenniumrhino.com/auth/ios?handoffCode=one-time-code")
            )
        )
        let sessionLifecycle = AuthSessionLifecycleSpy(
            establishError: APIError.server(
                statusCode: 401,
                response: APIErrorResponse(
                    successFlag: false,
                    code: "WRONG_TOKEN",
                    message: "invalid token",
                    data: nil
                )
            )
        )
        let viewModel = SocialSignInViewModel(
            oauthRepository: repository,
            webAuthenticationSession: webSession,
            sessionLifecycle: sessionLifecycle
        )

        await viewModel.signIn(provider: .kakao)

        XCTAssertEqual(
            viewModel.errorMessage,
            "로그인 정보를 확인하지 못했어요. 처음부터 다시 시도해 주세요."
        )
        XCTAssertEqual(sessionLifecycle.establishedTokens.count, 1)
    }
}

private actor OAuthRepositorySpy: OAuthRepository {
    private var provider: OAuthProvider?
    private var handoffCode: String?
    private let exchangeError: Error?

    init(exchangeError: Error? = nil) {
        self.exchangeError = exchangeError
    }

    func signInRedirectURL(for provider: OAuthProvider) async throws -> URL {
        self.provider = provider
        return URL(string: "https://accounts.example.com/oauth")!
    }

    func exchange(handoffCode: OAuthHandoffCode) async throws -> AuthToken {
        self.handoffCode = handoffCode.value

        if let exchangeError {
            throw exchangeError
        }

        return AuthToken(accessToken: "access", refreshToken: "refresh")
    }

    func requestedProvider() -> OAuthProvider? {
        provider
    }

    func exchangedHandoffCode() -> String? {
        handoffCode
    }
}

@MainActor
private final class OAuthWebAuthenticationSessionSpy: OAuthWebAuthenticationSession {
    private let callbackURL: URL
    private let error: Error?

    init(callbackURL: URL, error: Error? = nil) {
        self.callbackURL = callbackURL
        self.error = error
    }

    func authenticate(at url: URL) async throws -> URL {
        if let error {
            throw error
        }
        return callbackURL
    }
}

@MainActor
private final class AuthSessionLifecycleSpy: AuthSessionLifecycleManaging {
    private(set) var establishedTokens: [AuthToken] = []
    private let establishError: Error?

    init(establishError: Error? = nil) {
        self.establishError = establishError
    }

    func establishSession(with token: AuthToken) async throws {
        establishedTokens.append(token)

        if let establishError {
            throw establishError
        }
    }

    func validateRestoredSession() async -> Bool { true }
}
