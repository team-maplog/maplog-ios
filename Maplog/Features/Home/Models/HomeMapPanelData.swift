//
//  HomeMapPanelData.swift
//  Maplog
//
//  Created by 한채림 on 8/17/26.
//

import Foundation

/// 홈 지도 패널이 한 로그의 경로를 표시할 때 사용하는 데이터
struct HomeMapRouteViewData: Equatable {
    let logID: Int64
    let points: [HomeMapRoutePointViewData]
}

/// 홈 지도 패널에서 마커와 장소 카드 하나를 그릴 때 사용하는 데이터
struct HomeMapRoutePointViewData: Identifiable, Equatable {
    let clipID: Int64
    let sequence: Int
    let startTimeMillis: Int64
    let endTimeMillis: Int64

    let placeName: String
    let address: String
    let latitude: Double
    let longitude: Double

    let thumbnailURL: URL?

    var id: Int64 {
        clipID
    }
}

/// 지도에서 선택한 장소의 영상 재생 요청
struct HomeMapRoutePlaybackRequest: Equatable {
    let logID: Int64
    let startTimeMillis: Int64
}
