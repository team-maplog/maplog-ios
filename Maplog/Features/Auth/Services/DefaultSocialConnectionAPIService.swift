import Foundation

final class DefaultSocialConnectionAPIService: SocialConnectionAPIService {
    private let authenticatedAPIClient: AuthenticatedAPIClient

    init(authenticatedAPIClient: AuthenticatedAPIClient) {
        self.authenticatedAPIClient = authenticatedAPIClient
    }

    func disconnect(provider: String) async throws -> SocialConnectionResponseDTO {
        guard ["google", "kakao", "naver", "apple"].contains(provider) else {
            throw APIError.invalidRequest(reason: "지원하지 않는 소셜 제공자입니다.")
        }
        let url = APIConfiguration.baseURL.appendingPathComponent("api/v1/auth/oauth")
            .appendingPathComponent(provider).appendingPathComponent("connection")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let response: APIResponse<SocialConnectionResponseDTO> = try await authenticatedAPIClient.request(
            request, responseType: APIResponse<SocialConnectionResponseDTO>.self
        )
        guard response.successFlag, response.code == "SUCCESS-004" else {
            throw APIError.unexpectedResponse(code: response.code, message: response.message)
        }
        guard let data = response.data else { throw APIError.missingData }
        return data
    }

    func fetchConnections() async throws -> [SocialConnectionResponseDTO] {
        let url = APIConfiguration.baseURL.appendingPathComponent("api/v1/auth/oauth/connections")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let response: APIResponse<[SocialConnectionResponseDTO]> = try await authenticatedAPIClient.request(
            request, responseType: APIResponse<[SocialConnectionResponseDTO]>.self
        )
        guard response.successFlag, response.code == "SUCCESS-002" else {
            throw APIError.unexpectedResponse(code: response.code, message: response.message)
        }
        guard let data = response.data else { throw APIError.missingData }
        return data
    }
}
