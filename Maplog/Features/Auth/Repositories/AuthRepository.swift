//
//  AuthRepository.swift
//  Maplog
//
//  Created by 한채림 on 7/24/26.
//

import Foundation

protocol AuthRepository {
    func signIn(
        credentials: SignInCredentials
    ) async throws -> AuthToken

    func signOut() async throws
}

// Repository 밖, 즉 ViewModel은 서버 응답 형식을 몰라야 함
