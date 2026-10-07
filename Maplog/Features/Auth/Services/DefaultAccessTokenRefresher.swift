import Foundation

@MainActor
final class DefaultAccessTokenRefresher: AccessTokenRefreshing {
    private let authRepository: any AuthRepository
    private let authSession: any AuthSessionManaging
    private var refreshTask: (id: UUID, generation: UUID, task: Task<Void, Error>)?

    init(authRepository: any AuthRepository, authSession: any AuthSessionManaging) {
        self.authRepository = authRepository
        self.authSession = authSession
    }

    func refreshAccessToken() async throws {
        let generation = authSession.sessionGeneration
        if let pending = refreshTask, pending.generation == generation {
            try await pending.task.value
            try checkSession(generation)
            return
        }
        guard let credential = try authSession.currentRefreshToken(), !credential.isEmpty else {
            throw APIError.missingRefreshToken
        }
        let id = UUID()
        let task = Task { @MainActor in
            try self.checkSession(generation)
            let newToken: AuthToken
            do {
                newToken = try await self.authRepository.reissueToken(refreshToken: credential)
            } catch {
                // 오래된 갱신 실패도 현재 세션의 인증 오류로 전달하지 않는다.
                try self.checkSession(generation)
                throw error
            }
            try self.checkSession(generation)
            try self.authSession.replaceTokens(with: newToken)
        }
        refreshTask = (id, generation, task)
        defer {
            // 이전 작업이 새 세션의 진행 중 갱신을 지우지 않게 한다.
            if refreshTask?.id == id { refreshTask = nil }
        }
        try await task.value
        try checkSession(generation)
    }

    private func checkSession(_ generation: UUID) throws {
        guard authSession.sessionGeneration == generation else { throw CancellationError() }
    }
}
