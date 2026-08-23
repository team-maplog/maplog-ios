//
//  LogMediaRepository.swift
//  Maplog
//
//  Created by 한채림 on 8/14/26.
//

import Foundation

protocol LogMediaRepository {
    func fetchThumbnailData(logID: Int64) async throws -> Data
    func fetchPlaybackFileURL(logID: Int64) async throws -> URL

    func fetchRoutePointThumbnailData(from url: URL) async throws -> Data
}
