import Foundation

@MainActor
final class DefaultAuthSessionLifecycleManager: AuthSessionLifecycleManaging {
    private let authSession: any AuthSessionManaging
    private let sessionValidationRepository: any SessionValidationRepository

    init(
        authSession: any AuthSessionManaging,
        sessionValidationRepository: any SessionValidationRepository
    ) {
        self.authSession = authSession
        self.sessionValidationRepository = sessionValidationRepository
    }

    func establishSession(with token: AuthToken) async throws {
        // Keychain에는 먼저 저장하되, 검증 전 홈 전환 신호는 내보내지 않음
        try authSession.stageSession(with: token)
        let generation = authSession.sessionGeneration

        do {
            _ = try await sessionValidationRepository.validateCurrentSession()
            guard authSession.sessionGeneration == generation else { throw CancellationError() }
            // /users/me까지 성공한 토큰만 앱 전체 로그인 상태로 확정함
            try authSession.activateStagedSession()
        } catch {
            // handoff token이 잘못됐으면 남은 토큰 없이 로그인 화면에 머물러야 함
            if authSession.sessionGeneration == generation { try? authSession.endSession() }
            throw error
        }
    }

    func validateRestoredSession() async -> Bool {
        let generation = authSession.sessionGeneration
        do {
            _ = try await sessionValidationRepository.validateCurrentSession()
            return authSession.sessionGeneration == generation
        } catch {
            // 앱 재실행 시 오래된 Keychain 토큰으로 홈이 열리는 일을 막음
            if authSession.sessionGeneration == generation { try? authSession.endSession() }
            return false
        }
    }
}
