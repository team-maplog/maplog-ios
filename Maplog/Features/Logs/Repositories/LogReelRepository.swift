//
//  LogReelRepository.swift
//  Maplog
//
//  Created by 한채림 on 8/13/26.
//

import Foundation

protocol LogReelRepository {
    func fetchReels(
        cursor: String?, //서버가 준 다음 목록 위치
        size: Int
    ) async throws -> LogReelPage

    func fetchSavedLogs(
        cursor: String?,
        size: Int
    ) async throws -> LogReelPage
}
