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
    
    private var refreshTask: Task<Void, Error>? // 재발급 작업은 값은 돌려주지 않고(Void), 성공 또는 오류만 알려준다(Error)

    init(authRepository: any AuthRepository,
         authSession: any AuthSessionManaging
    ) {
        self.authRepository = authRepository
        self.authSession = authSession
    }

    func refreshAccessToken() async throws {
        if let refreshTask { // 이미 누군가 재발급 중이면 새 요청을 만들지 않고, 그 결과를 같이 기다림
            try await refreshTask.value
            return
        }

        let newRefreshTask = Task { @MainActor in // 아무도 재발급 중이 아니면 최초 요청이 재발급 작업을 만들고 공유 보관함에 넣음
            let newToken = try await authRepository.reissueToken()

            try authSession.replaceTokens(with: newToken)
        }

        refreshTask = newRefreshTask

        defer { // 성공·실패와 관계없이 작업이 끝나면 보관함을 비움. 다음 만료 시점에는 새 재발급이 가능
            refreshTask = nil
        }

        try await newRefreshTask.value
    }
}

// 완성본에서는 AuthSessionStore 구체 타입 대신 “토큰 교체 역할 protocol”을 주입
