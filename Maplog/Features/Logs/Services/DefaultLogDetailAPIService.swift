import Foundation

final class DefaultLogDetailAPIService: LogDetailAPIService {
    private let authenticatedAPIClient: AuthenticatedAPIClient

    init(
        authenticatedAPIClient: AuthenticatedAPIClient
    ) {
        self.authenticatedAPIClient = authenticatedAPIClient
    }

    func fetchLogDetail(
        logID: Int64
    ) async throws -> LogDetailResponseDTO {
        var request = URLRequest(url: try logEndpoint(logID: logID))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let response: APIResponse<LogDetailResponseDTO> =
            try await authenticatedAPIClient.request(
                request,
                responseType: APIResponse<LogDetailResponseDTO>.self
            )

        guard response.successFlag,
              response.code == "SUCCESS-002"
        else {
            throw APIError.unexpectedResponse(
                code: response.code,
                message: response.message
            )
        }

        guard let detail = response.data else {
            throw APIError.missingData
        }

        return detail
    }

    func updateLogCaption(
        logID: Int64,
        request: UpdateLogRequestDTO
    ) async throws -> LogBasicResponseDTO {
        var urlRequest = URLRequest(url: try logEndpoint(logID: logID))
        urlRequest.httpMethod = "PATCH"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let response: APIResponse<LogBasicResponseDTO> =
            try await authenticatedAPIClient.request(
                urlRequest,
                responseType: APIResponse<LogBasicResponseDTO>.self
            )

        guard response.successFlag,
              response.code == "SUCCESS-003"
        else {
            throw APIError.unexpectedResponse(
                code: response.code,
                message: response.message
            )
        }

        guard let updatedLog = response.data else {
            throw APIError.missingData
        }

        return updatedLog
    }

    func deleteLog(
        logID: Int64
    ) async throws {
        var request = URLRequest(url: try logEndpoint(logID: logID))
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let response: APIResponse<EmptyLogDetailResponseDTO> =
            try await authenticatedAPIClient.request(
                request,
                responseType: APIResponse<EmptyLogDetailResponseDTO>.self
            )

        guard response.successFlag,
              response.code == "SUCCESS-004"
        else {
            throw APIError.unexpectedResponse(
                code: response.code,
                message: response.message
            )
        }
    }

    private func logEndpoint(
        logID: Int64
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
    }
}

private struct EmptyLogDetailResponseDTO: Decodable {}
