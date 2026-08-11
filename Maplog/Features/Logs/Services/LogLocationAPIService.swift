//
//  LogLocationAPIService.swift
//  Maplog
//
//  Created by 한채림 on 8/12/26.
// 좌표를 전달하면, 서버 응답 DTO를 비동기로 가져올 수 있음

import Foundation

protocol LogLocationAPIService {
    func resolveLocation(
        latitude: Double,
        longitude: Double
    ) async throws -> LocationResolveResponseDTO
}
