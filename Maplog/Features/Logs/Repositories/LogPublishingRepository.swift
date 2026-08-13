//
//  LogPublishingRepository.swift
//  Maplog
//
//  Created by 한채림 on 8/13/26.
//

import Foundation

protocol LogPublishingRepository {
    func publish(
        draft: LogPublishDraft
    ) async throws -> LogPublishResult
}
