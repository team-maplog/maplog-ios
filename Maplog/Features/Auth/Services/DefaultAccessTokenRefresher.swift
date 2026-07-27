//
//  DefaultAccessTokenRefresher.swift
//  Maplog
//
//  Created by 한채림 on 7/28/26.
// 새 토큰 저장만 필요

@MainActor
final class DefaultAccessTokenRefresher: AccessTokenRefreshing {
    private let authRepository: any AuthRepository
    private let authSession: any AuthSessionManaging

    init(authRepository: any AuthRepository,
         authSession: any AuthSessionManaging
    ) {
        self.authRepository = authRepository
        self.authSession = authSession
    }

    func refreshAccessToken() async throws {
        let newToken = try await authRepository.reissueToken()
        try authSession.replaceTokens(with: newToken)
    }
}

// 완성본에서는 AuthSessionStore 구체 타입 대신 “토큰 교체 역할 protocol”을 주입
