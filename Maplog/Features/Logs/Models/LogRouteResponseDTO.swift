//
//  LogRouteResponseDTO.swift
//  Maplog
//
//  Created by 한채림 on 8/22/26.
//

import Foundation

/// GET /api/v1/logs/{logId}/route 의 data 내부 형식
struct LogRouteResponseDTO: Decodable {
    let logID: Int64
    let points: [RoutePointResponseDTO]

    enum CodingKeys: String, CodingKey {
        case logID = "logId"
        case points
    }
}

/// 서버가 보내는 경로의 장소 한 점
struct RoutePointResponseDTO: Decodable {
    let sequence: Int
    let clipID: Int64
    let startTimeMillis: Int64
    let endTimeMillis: Int64

    // 수동으로 좌표와 주소만 지정한 클립은 장소명이 없을 수 있다.
    let placeName: String?
    let address: String
    let latitude: Double
    let longitude: Double

    let thumbnailURL: String?

    enum CodingKeys: String, CodingKey {
        case sequence
        case clipID = "clipId"
        case startTimeMillis
        case endTimeMillis
        case placeName
        case address
        case latitude
        case longitude
        case thumbnailURL = "thumbnailUrl"
    }
}
