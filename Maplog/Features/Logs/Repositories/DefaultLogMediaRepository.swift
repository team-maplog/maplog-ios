//
//  DefaultLogMediaRepository.swift
//  Maplog
//
//  Created by 한채림 on 8/14/26.
//

import Foundation

final class DefaultLogMediaRepository: LogMediaRepository {
    private let apiService: any LogMediaAPIService

    init(apiService: any LogMediaAPIService) {
        self.apiService = apiService
    }

    func fetchThumbnailData(logID: Int64) async throws -> Data {
        try await apiService.fetchThumbnailData(logID: logID)
    }

    func fetchPlaybackFileURL(
        logID: Int64
    ) async throws -> URL {
        try await apiService.fetchPlaybackFileURL(
            logID: logID
        )
    }
}
