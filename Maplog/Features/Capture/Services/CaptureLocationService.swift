//
//  CaptureLocationService.swift
//  Maplog
//
//  Created by 한채림 on 8/6/26.
// iPhone의 Core Location 기능을 다루는 기술 계층

import Foundation

@MainActor
protocol CaptureLocationService {
    var latestLocation: CaptureLocation? { get } // 촬영 버튼을 누른 순간의 가장 최근 위치 스냅샷

    func startUpdatingLocation()  // 카메라 화면이 열릴 때 위치 권한을 요청하고 위치 갱신 시작
    func stopUpdatingLocation() // 카메라를 닫을 때 불필요한 위치 추적 중지
}
