//
//  MapViewport.swift
//  Maplog
//
//  Created by 한채림 on 8/25/26.
//

import Foundation

/// 현재 지도 화면의 남서·북동 경계
struct MapViewport: Equatable {
    let southLatitude: Double
    let westLongitude: Double
    let northLatitude: Double
    let eastLongitude: Double

    init(
        southLatitude: Double,
        westLongitude: Double,
        northLatitude: Double,
        eastLongitude: Double
    ) {
        self.southLatitude = southLatitude
        self.westLongitude = westLongitude
        self.northLatitude = northLatitude
        self.eastLongitude = eastLongitude
    }
}

// repository가 지도 화면에 넘기는 최종 결과 묶음
// 로그 핀 목록, 관광 핀 목록, 너무 많은지 여부 등을 같이 전달
struct MapViewportContent: Equatable {
    let logMarkers: [MapLogMarker]
    let tourismMarkers: [TourismMapMarker]

    let isLogMarkerTruncated: Bool
    let tourismStatus: TourismMapStatus

    var markers: [MapMarker] {
        logMarkers.map { .log($0) }
        + tourismMarkers.map { .tourism($0) }
    }

    var shouldAskUserToZoomIn: Bool {
        isLogMarkerTruncated || tourismStatus.isTruncated
    }
}

struct TourismMapStatus: Equatable {
    let isAvailable: Bool
    let isStale: Bool
    let isTruncated: Bool
}

struct MapCoordinate: Equatable {
    let latitude: Double
    let longitude: Double
}

// 로그 클립 핀 하나
struct MapLogMarker: Equatable {
    let logID: Int64
    let clipID: Int64
    let sequence: Int
    let startTimeMillis: Int64
    let endTimeMillis: Int64

    let caption: String?
    let placeName: String?
    let address: String?
    let thumbnailURL: URL?
    let coordinate: MapCoordinate
}

// 관광 핀 하나
struct TourismMapMarker: Equatable {
    let tourismID: Int64
    let name: String?
    let thumbnailURL: URL?
    let startDateText: String?
    let endDateText: String?
    let coordinate: MapCoordinate
}

// View가 로그 핀인지 관광 핀인지만 알면 되게 하기 위함, 서버 DTO를 View까지 그대로 전달하지 않는 구조
// 두 종류를 지도 view가 한 배열로 다루기 위한 포장지 같은 존재
enum MapMarker: Identifiable, Equatable {
    case log(MapLogMarker)
    case tourism(TourismMapMarker)

    var id: String {
        switch self {
        case let .log(marker):
            return "log-\(marker.logID)-\(marker.clipID)"

        case let .tourism(marker):
            return "tourism-\(marker.tourismID)"
        }
    }

    var coordinate: MapCoordinate {
        switch self {
        case let .log(marker):
            return marker.coordinate

        case let .tourism(marker):
            return marker.coordinate
        }
    }

    var title: String {
        switch self {
        case let .log(marker):
            return marker.placeName ?? "이름 없는 장소"

        case let .tourism(marker):
            return marker.name ?? "관광 장소"
        }
    }

    var subtitle: String {
        switch self {
        case let .log(marker):
            return marker.address ?? marker.caption ?? ""

        case .tourism:
            return "관광 정보"
        }
    }

    var thumbnailURL: URL? {
        switch self {
        case let .log(marker):
            return marker.thumbnailURL

        case let .tourism(marker):
            return marker.thumbnailURL
        }
    }
}

enum MapRepositoryError: Error, Equatable {
    case invalidViewport
    case invalidMarkerCoordinate
}
