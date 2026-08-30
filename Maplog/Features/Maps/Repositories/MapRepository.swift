//
//  MapRepository.swift
//  Maplog
//
//  Created by 한채림 on 8/25/26.
// 지도 범위를 주면 지도 표시용 데이터를 줌, DTO나 URL은 모름

import Foundation

protocol MapRepository {
    func fetchViewportContent(
        in viewport: MapViewport,
        tourismCategory: TourismMapCategory
    ) async throws -> MapViewportContent
}
