import Foundation

final class DefaultLogInteractionAPIService: LogInteractionAPIService {
    private let authenticatedAPIClient: AuthenticatedAPIClient

    init(authenticatedAPIClient: AuthenticatedAPIClient) {
        self.authenticatedAPIClient = authenticatedAPIClient
    }

    func setLike(
        logID: Int64,
        isLiked: Bool
    ) async throws -> LogLikeInteractionResponseDTO {
        var request = URLRequest(
            url: try interactionEndpoint(
                logID: logID,
                pathComponent: "likes"
            )
        )
        request.httpMethod = isLiked ? "PUT" : "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let response: APIResponse<LogLikeInteractionResponseDTO> =
            try await authenticatedAPIClient.request(
                request,
                responseType: APIResponse<LogLikeInteractionResponseDTO>.self
            )

        return try validatedData(
            from: response,
            expectedCode: isLiked ? "SUCCESS-003" : "SUCCESS-004"
        )
    }

    func setSaved(
        logID: Int64,
        isSaved: Bool
    ) async throws -> LogSaveInteractionResponseDTO {
        var request = URLRequest(
            url: try interactionEndpoint(
                logID: logID,
                pathComponent: "save"
            )
        )
        request.httpMethod = isSaved ? "PUT" : "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let response: APIResponse<LogSaveInteractionResponseDTO> =
            try await authenticatedAPIClient.request(
                request,
                responseType: APIResponse<LogSaveInteractionResponseDTO>.self
            )

        return try validatedData(
            from: response,
            expectedCode: isSaved ? "SUCCESS-003" : "SUCCESS-004"
        )
    }

    private func interactionEndpoint(
        logID: Int64,
        pathComponent: String
    ) throws -> URL {
        guard logID > 0 else {
            throw APIError.invalidRequest(
                reason: "로그 식별자가 올바르지 않습니다."
            )
        }

        return APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("logs")
            .appendingPathComponent(String(logID))
            .appendingPathComponent(pathComponent)
    }

    private func validatedData<Payload: Decodable>(
        from response: APIResponse<Payload>,
        expectedCode: String
    ) throws -> Payload {
        guard response.successFlag,
              response.code == expectedCode
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
}
