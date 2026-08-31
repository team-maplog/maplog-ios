//
//  DefaultOAuthRepository.swift
//  Maplog
//

import Foundation

enum OAuthRepositoryError: Error {
    case invalidRedirectURL
}

final class DefaultOAuthRepository: OAuthRepository {
    private let apiService: any OAuthAPIService

    init(apiService: any OAuthAPIService) {
        self.apiService = apiService
    }

    func signInRedirectURL(for provider: OAuthProvider) async throws -> URL {
        let response = try await apiService.fetchRedirect(provider: provider)

        guard let redirectURL = URL(string: response.redirectURL) else {
            throw OAuthRepositoryError.invalidRedirectURL
        }

        return redirectURL
    }

    func exchange(handoffCode: OAuthHandoffCode) async throws -> AuthToken {
        let response = try await apiService.exchangeHandoffCode(
            request: OAuthHandoffExchangeRequestDTO(handoffCode: handoffCode.value)
        )

        return AuthToken(
            accessToken: response.token.accessToken,
            refreshToken: response.token.refreshToken
        )
    }
}
