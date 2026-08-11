//
//  LogLocationDraft.swift
//  Maplog
//
//  Created by 한채림 on 8/11/26.
// Logs 기능 전용 초안 위치 모델
//CaptureLocation
//= 카메라가 촬영 때 받은 원본 좌표·임시 장소명
//
//LogLocationDraft
//= 로그에서 수정 중인 좌표·장소명·서버 주소

import Foundation

struct LogLocationDraft: Equatable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double
    var name: String?
    var address: String?

    init(
        latitude: Double,
        longitude: Double,
        name: String? = nil,
        address: String? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.address = address
    }

    init(captureLocation: CaptureLocation) {
        self.init(
            latitude: captureLocation.latitude,
            longitude: captureLocation.longitude,
            name: captureLocation.placeName
        )
    }
}
