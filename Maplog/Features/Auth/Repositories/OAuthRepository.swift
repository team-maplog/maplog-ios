//
//  OAuthRepository.swift
//  Maplog
//

import Foundation

protocol OAuthRepository {
    func signInRedirectURL(for provider: OAuthProvider) async throws -> URL
    func exchange(handoffCode: OAuthHandoffCode) async throws -> AuthToken
}
