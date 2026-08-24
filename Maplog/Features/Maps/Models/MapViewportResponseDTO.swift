//
//  MapViewportResponseDTO.swift
//  Maplog
//
//  Created by 한채림 on 8/25/26.
//

import Foundation

/// GET /api/v1/maps의 data 내부 형식
struct MapViewportResponseDTO: Decodable {
    let markers: [LogMapMarkerResponseDTO]?
    let truncated: Bool?
    let tourisms: TourismMapViewportResponseDTO?
}

struct LogMapMarkerResponseDTO: Decodable {
    let logID: Int64?
    let clipID: Int64?
    let sequence: Int?
    let startTimeMillis: Int64?
    let endTimeMillis: Int64?

    let caption: String?
    let thumbnailURL: String?
    let placeName: String?
    let address: String?
    let latitude: Double?
    let longitude: Double?

    enum CodingKeys: String, CodingKey {
        case logID = "logId"
        case clipID = "clipId"
        case sequence
        case startTimeMillis
        case endTimeMillis
        case caption
        case thumbnailURL = "thumbnailUrl"
        case placeName
        case address
        case latitude
        case longitude
    }
}

struct TourismMapViewportResponseDTO: Decodable {
    let markers: [TourismMapMarkerResponseDTO]?
    let truncated: Bool?
    let available: Bool?
    let stale: Bool?
}

struct TourismMapMarkerResponseDTO: Decodable {
    let tourismID: Int64?
    let name: String?
    let thumbnailURL: String?
    let startDate: String?
    let endDate: String?
    let latitude: Double?
    let longitude: Double?

    enum CodingKeys: String, CodingKey {
        case tourismID = "tourismId"
        case name
        case thumbnailURL = "thumbnailUrl"
        case startDate
        case endDate
        case latitude
        case longitude
    }
}
