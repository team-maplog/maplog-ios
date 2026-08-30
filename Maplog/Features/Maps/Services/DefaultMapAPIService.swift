//
//  DefaultMapAPIService.swift
//  Maplog
//
//  Created by 한채림 on 8/25/26.
//

import Foundation

final class DefaultMapAPIService: MapAPIService {
    private let authenticatedAPIClient: AuthenticatedAPIClient

    private let logMarkerLimit = 100
    private let tourismMarkerLimit = 50

    init(
        authenticatedAPIClient: AuthenticatedAPIClient
    ) {
        self.authenticatedAPIClient = authenticatedAPIClient
    }

    func fetchViewportContent(
        in viewport: MapViewport,
        tourismCategory: TourismMapCategory
    ) async throws -> MapViewportResponseDTO {
        guard isValid(viewport) else {
            throw APIError.invalidRequest(
                reason: "지도 범위가 올바르지 않습니다."
            )
        }

        let endpoint = APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("maps")

        var components = URLComponents(
            url: endpoint,
            resolvingAgainstBaseURL: false
        )

        components?.queryItems = [
            URLQueryItem(
                name: "southLatitude",
                value: String(viewport.southLatitude)
            ),
            URLQueryItem(
                name: "westLongitude",
                value: String(viewport.westLongitude)
            ),
            URLQueryItem(
                name: "northLatitude",
                value: String(viewport.northLatitude)
            ),
            URLQueryItem(
                name: "eastLongitude",
                value: String(viewport.eastLongitude)
            ),
            URLQueryItem(
                name: "category",
                value: tourismCategory.requestValue
            ),
            URLQueryItem(
                name: "size",
                value: String(logMarkerLimit)
            ),
            URLQueryItem(
                name: "tourismSize",
                value: String(tourismMarkerLimit)
            )
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let response: APIResponse<MapViewportResponseDTO> =
            try await authenticatedAPIClient.request(
                request,
                responseType: APIResponse<MapViewportResponseDTO>.self
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

        guard let data = response.data else {
            throw APIError.missingData
        }

        return data
    }

    private func isValid(
        _ viewport: MapViewport
    ) -> Bool {
        let values = [
            viewport.southLatitude,
            viewport.westLongitude,
            viewport.northLatitude,
            viewport.eastLongitude
        ]

        guard values.allSatisfy(\.isFinite) else {
            return false
        }

        guard (-90...90).contains(viewport.southLatitude),
              (-90...90).contains(viewport.northLatitude),
              (-180...180).contains(viewport.westLongitude),
              (-180...180).contains(viewport.eastLongitude)
        else {
            return false
        }

        return viewport.southLatitude < viewport.northLatitude
            && viewport.westLongitude < viewport.eastLongitude
    }
}
