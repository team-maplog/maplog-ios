//
//  MapCurrentLocationService.swift
//  Maplog
//
//  Created by 한채림 on 8/25/26.
//

import Foundation

@MainActor
protocol MapCurrentLocationService {
    /// 사용자가 지도에서 현재 위치를 요청했을 때의 단발성 좌표 요청이다.
    /// 지도 탭은 백그라운드 위치 추적이 필요하지 않으므로 계속 관찰하지 않는다.
    func requestCurrentLocation() async throws -> MapCoordinate
}

enum MapCurrentLocationError: Error, Equatable {
    case servicesDisabled
    case authorizationDenied
    case unavailable
}
