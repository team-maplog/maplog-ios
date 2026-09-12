//
//  DefaultLogReelAPIService.swift
//  Maplog
//
//  Created by 한채림 on 8/13/26.
//

import Foundation

final class DefaultLogReelAPIService: LogReelAPIService {
    private let authenticatedAPIClient: AuthenticatedAPIClient

    init(
        authenticatedAPIClient: AuthenticatedAPIClient
    ) {
        self.authenticatedAPIClient = authenticatedAPIClient
    }

    func fetchReels(
        cursor: String?,
        size: Int
    ) async throws -> LogReelPageDTO {
        try await fetchLogPage(
            pathComponent: "reels",
            cursor: cursor,
            size: size,
            listName: "릴스"
        )
    }

    func fetchSavedLogs(
        cursor: String?,
        size: Int
    ) async throws -> LogReelPageDTO {
        try await fetchLogPage(
            pathComponent: "saves",
            cursor: cursor,
            size: size,
            listName: "저장한 로그"
        )
    }

    private func fetchLogPage(
        pathComponent: String,
        cursor: String?,
        size: Int,
        listName: String
    ) async throws -> LogReelPageDTO {
        guard (1...100).contains(size) else {
            throw APIError.invalidRequest(
                reason: "\(listName) 목록 크기는 1부터 100 사이여야 합니다."
            )
        }

        let endpoint = APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("logs")
            .appendingPathComponent(pathComponent)

        var queryItems = [
            URLQueryItem(
                name: "size",
                value: String(size)
            )
        ]

        if let cursor {
            queryItems.append(
                URLQueryItem(
                    name: "cursor",
                    value: cursor
                )
            )
        }

        var components = URLComponents(
            url: endpoint,
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let response: APIResponse<LogReelPageDTO> =
        try await authenticatedAPIClient.request(
            urlRequest,
            responseType: APIResponse<LogReelPageDTO>.self
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

        guard let pageDTO = response.data else {
            throw APIError.missingData
        }

        return pageDTO
    }
}
