//
//  OAuthAPIService.swift
//  Maplog
//

import Foundation

protocol OAuthAPIService {
    func fetchRedirect(provider: OAuthProvider) async throws -> OAuthRedirectResponseDTO
    func exchangeHandoffCode(
        request: OAuthHandoffExchangeRequestDTO
    ) async throws -> SignInResponseDTO
}
