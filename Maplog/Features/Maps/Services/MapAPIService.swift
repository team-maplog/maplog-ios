//
//  MapAPIService.swift
//  Maplog
//
//  Created by 한채림 on 8/25/26.
// 지도 범위를 주면, 서버 DTO를 가져옴

import Foundation

protocol MapAPIService {
    func fetchPreview(type: String, markerID: Int64) async throws -> MapMarkerSummaryDTO

    func search(query: String, scope: String, category: TourismMapCategory) async throws -> MapSearchResponseDTO

    func fetchViewportContent(
        in viewport: MapViewport,
        tourismCategory: TourismMapCategory
    ) async throws -> MapViewportResponseDTO
}
