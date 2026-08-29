//
//  LogMediaAPIService.swift
//  Maplog
//
//  Created by 한채림 on 8/14/26.
//

import Foundation

protocol LogMediaAPIService {
    func fetchThumbnailData(
        logID: Int64,
        targetSize: MaplogImageTargetSize
    ) async throws -> Data
    func fetchPlaybackFileURL(logID: Int64) async throws -> URL

    func fetchRoutePointThumbnailData(
        from url: URL,
        targetSize: MaplogImageTargetSize
    ) async throws -> Data
}

extension LogMediaAPIService {
    func fetchThumbnailData(
        logID: Int64
    ) async throws -> Data {
        try await fetchThumbnailData(
            logID: logID,
            targetSize: .reelCover
        )
    }

    func fetchRoutePointThumbnailData(
        from url: URL
    ) async throws -> Data {
        try await fetchRoutePointThumbnailData(
            from: url,
            targetSize: .mapMarker
        )
    }
}
