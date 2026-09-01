//
//  DefaultOAuthAPIService.swift
//  Maplog
//

import Foundation

final class DefaultOAuthAPIService: OAuthAPIService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchRedirect(provider: OAuthProvider) async throws -> OAuthRedirectResponseDTO {
        // 제공자 URL과 state는 서버가 생성함
        let url = APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("auth")
            .appendingPathComponent("oauth")
            .appendingPathComponent(provider.rawValue)
            .appendingPathComponent("redirect")

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "client", value: "ios")]

        guard let redirectURL = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: redirectURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let response: APIResponse<OAuthRedirectResponseDTO> = try await apiClient.request(
            request,
            responseType: APIResponse<OAuthRedirectResponseDTO>.self
        )

        guard response.successFlag else {
            throw APIError.unexpectedResponse(code: response.code, message: response.message)
        }

        guard let data = response.data else {
            throw APIError.missingData
        }

        return data
    }

    func exchangeHandoffCode(
        request: OAuthHandoffExchangeRequestDTO
    ) async throws -> SignInResponseDTO {
        // handoffCode는 URL 아닌 POST body로만 전달함
        let url = APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("auth")
            .appendingPathComponent("oauth")
            .appendingPathComponent("handoff")
            .appendingPathComponent("exchange")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let response: APIResponse<SignInResponseDTO> = try await apiClient.request(
            urlRequest,
            responseType: APIResponse<SignInResponseDTO>.self
        )

        guard response.successFlag, response.code == "SUCCESS-006" else {
            throw APIError.unexpectedResponse(code: response.code, message: response.message)
        }

        guard let data = response.data else {
            throw APIError.missingData
        }

        return data
    }
}
