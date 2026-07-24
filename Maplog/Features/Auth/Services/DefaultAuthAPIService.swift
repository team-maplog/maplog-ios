//
//  DefaultAuthAPIService.swift
//  Maplog
//
//  Created by 한채림 on 7/24/26.
//

import Foundation

final class DefaultAuthAPIService: AuthAPIService {
    private let apiClient: APIClient
    private let accessTokenProvider: any AccessTokenProviding

    init(apiClient: APIClient,
         accessTokenProvider: any AccessTokenProviding
    ) {
        self.apiClient = apiClient
        self.accessTokenProvider = accessTokenProvider

    }

    func signIn(request: SignInRequestDTO) async throws -> SignInResponseDTO {
        let url = APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("auth")
            .appendingPathComponent("signin")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"

        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        urlRequest.httpBody = try JSONEncoder().encode(request)

        let response: APIResponse<SignInResponseDTO> = try await apiClient.request(urlRequest, responseType: APIResponse<SignInResponseDTO>.self)

        guard response.successFlag else {
            throw APIError.unexpectedResponse(code: response.code, message: response.message)
        }

        guard response.code == "SUCCESS-006" else {
            throw APIError.unexpectedResponse(code: response.code, message: response.message)
        }

        guard let signInData = response.data else {
            throw APIError.missingData
        }

        return signInData
    }

    func signOut() async throws {
        let accessToken = try await accessTokenProvider.currentAccessToken()

        guard let accessToken, !accessToken.isEmpty else {
            throw APIError.missingAccessToken
        }

        let url = APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("auth")
            .appendingPathComponent("logout")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"

        urlRequest.setValue(
                "application/json",
                forHTTPHeaderField: "Accept"
            )
            urlRequest.setValue(
                "Bearer \(accessToken)",
                forHTTPHeaderField: "Authorization"
            )

        let response: APIResponse<String> = try await apiClient.request(urlRequest, responseType: APIResponse<String>.self)

        guard response.successFlag else {
            throw APIError.unexpectedResponse(code: response.code, message: response.message)
        }
    }

}
