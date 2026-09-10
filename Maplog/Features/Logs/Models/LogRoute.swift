//
//  LogRoute.swift
//  Maplog
//
//  Created by 한채림 on 8/22/26.
//
/// 앱 내부에서 사용하는 로그 한 편의 장소 경로
/// 서버 DTO와 달리, 화면과 Repository가 공통으로 이해할 수 있는 형태

import Foundation

struct LogRoute: Equatable, Sendable {
    let logID: Int64
    let points: [LogRoutePoint]
}

struct LogRoutePoint: Identifiable, Equatable, Sendable {
    let clipID: Int64
    let sequence: Int
    let startTimeMillis: Int64
    let endTimeMillis: Int64

    let placeName: String?
    let address: String
    let latitude: Double
    let longitude: Double

    let thumbnailURL: URL?

    /// SwiftUI의 ForEach에서 사용할 고유 식별자
    var id: Int64 {
        clipID
    }
}
