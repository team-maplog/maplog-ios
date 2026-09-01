import Foundation

final class DefaultSessionValidationAPIService: SessionValidationAPIService {
    private let authenticatedAPIClient: AuthenticatedAPIClient

    init(authenticatedAPIClient: AuthenticatedAPIClient) {
        self.authenticatedAPIClient = authenticatedAPIClient
    }

    func validateCurrentSession() async throws -> SessionValidationResponseDTO {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let response: APIResponse<SessionValidationResponseDTO> = try await authenticatedAPIClient.request(
            request,
            responseType: APIResponse<SessionValidationResponseDTO>.self
        )

        guard response.successFlag else {
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

    private var endpoint: URL {
        APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("users")
            .appendingPathComponent("me")
    }
}
