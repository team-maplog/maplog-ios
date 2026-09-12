import Foundation

struct MapSearchResponseDTO: Decodable {
    let items: [MapMarkerSummaryDTO]
    let tourismAvailable: Bool
}

struct MapMarkerSummaryDTO: Decodable {
    let type: String
    let markerID: Int64
    let detailID: Int64
    let title: String?
    let subtitle: String?
    let summary: String?
    let thumbnailURL: String?
    let latitude: Double
    let longitude: Double
    let startTimeMillis: Int64?
    let endTimeMillis: Int64?
    let category: String?
    let startDate: String?
    let endDate: String?

    enum CodingKeys: String, CodingKey {
        case type, title, subtitle, summary, latitude, longitude
        case startTimeMillis, endTimeMillis, category, startDate, endDate
        case markerID = "markerId"
        case detailID = "detailId"
        case thumbnailURL = "thumbnailUrl"
    }
}
