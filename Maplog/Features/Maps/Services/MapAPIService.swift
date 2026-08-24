//
//  MapAPIService.swift
//  Maplog
//
//  Created by 한채림 on 8/25/26.
// 지도 범위를 주면, 서버 DTO를 가져옴

import Foundation

protocol MapAPIService {
    func fetchViewportContent(
        in viewport: MapViewport
    ) async throws -> MapViewportResponseDTO
}
