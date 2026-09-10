import Foundation

struct MapSearchResult: Equatable {
    let items: [MapMarkerSummary]
    let isTourismAvailable: Bool
}

/// 검색·약식 조회의 식별자. 로그에서는 markerID가 clipID, detailID가 logID다.
struct MapMarkerSummary: Identifiable, Equatable {
    let marker: MapMarker
    let title: String
    let subtitle: String
    let summary: String?
    var id: String { marker.id }
}

struct MapCameraFocusRequest: Equatable {
    let id = UUID()
    let coordinate: MapCoordinate
}
