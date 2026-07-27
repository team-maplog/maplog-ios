//
//  AuthAPIService.swift
//  Maplog
//
//  Created by 한채림 on 7/24/26.
//

import Foundation

protocol AuthAPIService {
    func signIn(
        request: SignInRequestDTO
    ) async throws -> SignInResponseDTO

    func signOut() async throws

    func reissueToken() async throws -> TokenResponse
}
