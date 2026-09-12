//
//  DefaultLogLocationAPIService.swift
//  Maplog
//
//  Created by 한채림 on 8/12/26.
//

import Foundation

final class DefaultLogLocationAPIService: LogLocationAPIService {
    private let authenticatedAPIClient: AuthenticatedAPIClient

    init(
        authenticatedAPIClient: AuthenticatedAPIClient
    ) {
        self.authenticatedAPIClient = authenticatedAPIClient
    }

    func resolveLocation(
        latitude: Double,
        longitude: Double
    ) async throws -> LocationResolveResponseDTO {
        guard (-90...90).contains(latitude) else {
            throw APIError.invalidRequest(
                reason: "위도는 -90부터 90 사이여야 합니다."
            )
        }

        guard (-180...180).contains(longitude) else {
            throw APIError.invalidRequest(
                reason: "경도는 -180부터 180 사이여야 합니다."
            )
        }

        let endpoint = APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("locations")
            .appendingPathComponent("resolve")

        var components = URLComponents(
            url: endpoint,
            resolvingAgainstBaseURL: false
        )

        components?.queryItems = [
            URLQueryItem(
                name: "latitude",
                value: String(latitude)
            ),
            URLQueryItem(
                name: "longitude",
                value: String(longitude)
            )
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let response: APIResponse<LocationResolveResponseDTO> =
            try await authenticatedAPIClient.request(
                urlRequest,
                responseType: APIResponse<LocationResolveResponseDTO>.self
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

        guard let locationDTO = response.data else {
            throw APIError.missingData
        }

        return locationDTO
    }
}
