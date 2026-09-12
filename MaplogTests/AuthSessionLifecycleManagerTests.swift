import XCTest

@testable import Maplog

@MainActor
final class AuthSessionLifecycleManagerTests: XCTestCase {
    func testEstablishSessionStagesThenActivatesAfterValidation() async throws {
        let session = SessionManagingSpy()
        let validationRepository = SessionValidationRepositorySpy()
        let manager = DefaultAuthSessionLifecycleManager(
            authSession: session,
            sessionValidationRepository: validationRepository
        )
        let token = AuthToken(accessToken: "access", refreshToken: "refresh")

        try await manager.establishSession(with: token)

        XCTAssertEqual(session.stagedTokens, [token])
        XCTAssertTrue(session.didActivateStagedSession)
        XCTAssertFalse(session.didEndSession)
    }

    func testEstablishSessionClearsStagedTokensWhenValidationFails() async throws {
        let session = SessionManagingSpy()
        let validationRepository = SessionValidationRepositorySpy(
            error: APIError.server(
                statusCode: 401,
                response: APIErrorResponse(
                    successFlag: false,
                    code: "WRONG_TOKEN",
                    message: "invalid token",
                    data: nil
                )
            )
        )
        let manager = DefaultAuthSessionLifecycleManager(
            authSession: session,
            sessionValidationRepository: validationRepository
        )

        do {
            try await manager.establishSession(
                with: AuthToken(accessToken: "access", refreshToken: "refresh")
            )
            XCTFail("세션 검증 실패가 전달되어야 함")
        } catch {
            XCTAssertTrue(session.didEndSession)
            XCTAssertFalse(session.didActivateStagedSession)
        }
    }

    func testValidateRestoredSessionClearsInvalidTokens() async {
        let session = SessionManagingSpy()
        let validationRepository = SessionValidationRepositorySpy(
            error: APIError.missingAccessToken
        )
        let manager = DefaultAuthSessionLifecycleManager(
            authSession: session,
            sessionValidationRepository: validationRepository
        )

        let isValid = await manager.validateRestoredSession()

        XCTAssertFalse(isValid)
        XCTAssertTrue(session.didEndSession)
    }
}

@MainActor
private final class SessionManagingSpy: AuthSessionManaging {
    private(set) var stagedTokens: [AuthToken] = []
    private(set) var didActivateStagedSession = false
    private(set) var didEndSession = false

    func startSession(with token: AuthToken) throws { }

    func stageSession(with token: AuthToken) throws {
        stagedTokens.append(token)
    }

    func activateStagedSession() throws {
        didActivateStagedSession = true
    }

    func replaceTokens(with token: AuthToken) throws { }

    func endSession() throws {
        didEndSession = true
    }

    func currentAccessToken() throws -> String? { "access" }

    func currentRefreshToken() throws -> String? { "refresh" }
}

private final class SessionValidationRepositorySpy: SessionValidationRepository {
    private let error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func validateCurrentSession() async throws -> AuthenticatedSession {
        if let error {
            throw error
        }

        return AuthenticatedSession(userID: UUID())
    }
}
