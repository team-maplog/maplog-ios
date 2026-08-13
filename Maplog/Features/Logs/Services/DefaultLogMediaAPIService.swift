//
//  DefaultLogMediaAPIService.swift
//  Maplog
//
//  Created by 한채림 on 8/14/26.
//

import Foundation

final class DefaultLogMediaAPIService: LogMediaAPIService {
    private let authenticatedAPIClient: AuthenticatedAPIClient

    init(authenticatedAPIClient: AuthenticatedAPIClient) {
        self.authenticatedAPIClient = authenticatedAPIClient
    }

    func fetchThumbnailData(logID: Int64) async throws -> Data {
        let url = APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("logs")
            .appendingPathComponent(String(logID))
            .appendingPathComponent("thumbnail")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("image/*", forHTTPHeaderField: "Accept")

        return try await authenticatedAPIClient.data(for: request) // AuthenticatedAPIClient를 지나면서 저장된 access token이 헤더에 붙고, 서버가 돌려준 이미지 원본 바이트(Data)를 받게 됨
    }
}
