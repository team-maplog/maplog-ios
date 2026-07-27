//
//  DefaultAuthRepository.swift
//  Maplog
//
//  Created by 한채림 on 7/24/26.
//

import Foundation

final class DefaultAuthRepository: AuthRepository {
    private let apiService: any AuthAPIService // 특정 DefaultAuthAPIService만 받는 게 아니라, AuthAPIService 약속을 지키는 어떤 서비스든 받을 수 있음

    init(apiService: any AuthAPIService) {
        self.apiService = apiService
    }

    func signIn(credentials: SignInCredentials) async throws -> AuthToken {
        let request = SignInRequestDTO(email: credentials.email, password: credentials.password)

        let response = try await apiService.signIn(request: request)

        return makeAuthToken(from: response.token)
    }

    private func makeAuthToken(from tokenResponse: TokenResponse) -> AuthToken {
        AuthToken(accessToken: tokenResponse.accessToken, refreshToken: tokenResponse.refreshToken)
    }

    func signOut() async throws {
        try await apiService.signOut()
    }

    func reissueToken() async throws -> AuthToken {
        let tokenResponse = try await apiService.reissueToken()

        return makeAuthToken(from: tokenResponse)
    }
}
