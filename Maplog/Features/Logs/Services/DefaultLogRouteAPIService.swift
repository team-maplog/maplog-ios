//
//  DefaultLogRouteAPIService.swift
//  Maplog
//
//  Created by 한채림 on 8/22/26.
//

import Foundation

final class DefaultLogRouteAPIService: LogRouteAPIService {
    private let authenticatedAPIClient: AuthenticatedAPIClient

    init(
        authenticatedAPIClient: AuthenticatedAPIClient
    ) {
        self.authenticatedAPIClient = authenticatedAPIClient
    }

    func fetchRoute(
        logID: Int64
    ) async throws -> LogRouteResponseDTO {
        guard logID > 0 else {
            throw APIError.invalidRequest(
                reason: "로그 ID는 1 이상이어야 합니다."
            )
        }

        let endpoint = APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("logs")
            .appendingPathComponent(String(logID))
            .appendingPathComponent("route")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let response: APIResponse<LogRouteResponseDTO> =
            try await authenticatedAPIClient.request(
                request,
                responseType: APIResponse<LogRouteResponseDTO>.self
            )

        guard response.successFlag else {
            throw APIError.unexpectedResponse(
                code: response.code,
                message: response.message
            )
        }

        guard response.code == "SUCCESS-002" else {
            throw APIError.unexpectedResponse(
                code: response.code,
                message: response.message
            )
        }

        guard let routeDTO = response.data else {
            throw APIError.missingData
        }

        return routeDTO
    }
}
