
//
//  TourismLocationMapView.swift
//  Maplog
//
//  Created by 한채림 on 7/26/26.
// 관광 상세 안에서 열릴 지도 전용 화면

import SwiftUI

struct TourismLocationMapView: View {
    let title: String
    let coordinate: TourismDetailCoordinateViewData

    var body: some View {
        TourismKakaoMapCanvas(latitude: coordinate.latitude, longitude: coordinate.longitude)
            .navigationTitle("위치 보기")
            .navigationBarTitleDisplayMode(.inline)
            .maplogTabBarHidden()
    }
}
