//
//  LogReelAPIService.swift
//  Maplog
//
//  Created by 한채림 on 8/13/26.
//

import Foundation

protocol LogReelAPIService {
    func fetchReels(
        cursor: String?,
        size: Int
    ) async throws -> LogReelPageDTO
}
