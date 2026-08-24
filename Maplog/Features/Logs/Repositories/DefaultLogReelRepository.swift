//
//  DefaultLogReelRepository.swift
//  Maplog
//
//  Created by 한채림 on 8/13/26.
// 서버 DTO를 앱 모델로 번역

import Foundation

final class DefaultLogReelRepository: LogReelRepository {
    private let apiService: any LogReelAPIService

    init(
        apiService: any LogReelAPIService
    ) {
        self.apiService = apiService
    }

    func fetchReels(
        cursor: String?,
        size: Int
    ) async throws -> LogReelPage {
        let pageDTO = try await apiService.fetchReels(
            cursor: cursor,
            size: size
        )

        let reels = try pageDTO.content.map(
            LogResponseMapper.makeLogReel
        )

        return LogReelPage(
            reels: reels,
            hasNext: pageDTO.hasNext,
            nextCursor: pageDTO.nextCursor
        )
    }

}
