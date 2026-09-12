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
    private let refreshTokenProvider: any RefreshTokenProviding

    init(apiClient: APIClient,
         accessTokenProvider: any AccessTokenProviding,
         refreshTokenProvider: any RefreshTokenProviding
    ) {
        self.apiClient = apiClient
        self.accessTokenProvider = accessTokenProvider
        self.refreshTokenProvider = refreshTokenProvider
    }

    func signUp(
        request: SignUpRequestDTO
    ) async throws -> SignUpResponseDTO {
        let url = APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("auth")
            .appendingPathComponent("signup")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let response: APIResponse<SignUpResponseDTO> =
            try await apiClient.request(
                urlRequest,
                responseType: APIResponse<SignUpResponseDTO>.self
            )

        guard response.successFlag,
              response.code == "SUCCESS-005"
        else {
            throw APIError.unexpectedResponse(
                code: response.code,
                message: response.message
            )
        }

        guard let data = response.data else {
            throw APIError.missingData
        }

        return data
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

    func reissueToken() async throws -> AuthTokenResponseDTO {
        let refreshToken = try await refreshTokenProvider.currentRefreshToken()

        guard let refreshToken, !refreshToken.isEmpty else {
            throw APIError.missingRefreshToken
        }

        let url = APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("auth")
            .appendingPathComponent("token")
            .appendingPathComponent("refresh")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.setValue(
                "Bearer \(refreshToken)",
                forHTTPHeaderField: "Authorization"
            )

        let response: APIResponse<AuthTokenResponseDTO> = try await apiClient.request(
            urlRequest,
            responseType: APIResponse<AuthTokenResponseDTO>.self
        )

        guard response.successFlag else {
            throw APIError.unexpectedResponse(code: response.code, message: response.message)
        }

        guard response.code == "SUCCESS-007" else {
            throw APIError.unexpectedResponse(code: response.code, message: response.message)
        }

        guard let token = response.data else {
            throw APIError.missingData
        }

        return token
    }

}
