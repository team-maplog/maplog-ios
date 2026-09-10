import XCTest
@testable import Maplog

final class DefaultMapRepositoryTests: XCTestCase {
    func testPreviewUsesClipIDRatherThanLogID() async throws {
        let service = MapViewportAPIServiceStub(response: MapViewportResponseDTO(markers: [], truncated: false, tourisms: nil))
        service.previewResponse = try JSONDecoder().decode(MapMarkerSummaryDTO.self, from: Data(#"{"type":"LOG","markerId":101,"detailId":11,"latitude":37.5,"longitude":127}"#.utf8))
        let marker = MapMarker.log(MapLogMarker(logID: 11, clipID: 101, sequence: 1, startTimeMillis: 0, endTimeMillis: 1000, caption: nil, placeName: nil, address: nil, thumbnailURL: nil, coordinate: MapCoordinate(latitude: 37.5, longitude: 127)))
        let result = try await DefaultMapRepository(apiService: service).fetchPreview(for: marker)
        XCTAssertEqual(service.previewMarkerID, 101)
        XCTAssertEqual(service.previewType, "LOG")
        XCTAssertEqual(result.id, marker.id)
    }

    func testSearchDTOMapsClipAndDetailIDsSeparately() throws {
        let json = Data(#"{"type":"LOG","markerId":101,"detailId":11,"title":"성수","latitude":37.5,"longitude":127,"thumbnailUrl":"/api/v1/logs/11/clips/101/thumbnail"}"#.utf8)
        let dto = try JSONDecoder().decode(MapMarkerSummaryDTO.self, from: json)
        let service = MapViewportAPIServiceStub(response: MapViewportResponseDTO(markers: [], truncated: false, tourisms: nil))
        let result = DefaultMapRepository(apiService: service).makeSummary(from: dto)
        guard case let .log(marker) = result?.marker else { return XCTFail("Expected log marker") }
        XCTAssertEqual(marker.clipID, 101)
        XCTAssertEqual(marker.logID, 11)
        XCTAssertEqual(marker.thumbnailURL?.host, APIConfiguration.baseURL.host)
    }

    func testSearchDTORejectsInvalidCoordinates() throws {
        let json = Data(#"{"type":"LOG","markerId":101,"detailId":11,"latitude":100,"longitude":127}"#.utf8)
        let dto = try JSONDecoder().decode(MapMarkerSummaryDTO.self, from: json)
        let service = MapViewportAPIServiceStub(response: MapViewportResponseDTO(markers: [], truncated: false, tourisms: nil))
        XCTAssertNil(DefaultMapRepository(apiService: service).makeSummary(from: dto))
    }

    func testFetchViewportContentMapsTourismCategoryAndPassesFilter() async throws {
        let apiService = MapViewportAPIServiceStub(
            response: MapViewportResponseDTO(
                markers: [],
                truncated: false,
                tourisms: TourismMapViewportResponseDTO(
                    markers: [
                        TourismMapMarkerResponseDTO(
                            tourismID: 301,
                            name: "성수 맛집",
                            thumbnailURL: nil,
                            startDate: nil,
                            endDate: nil,
                            category: "FOOD",
                            latitude: 37.544,
                            longitude: 127.037
                        )
                    ],
                    truncated: false,
                    available: true,
                    stale: false
                )
            )
        )
        let repository = DefaultMapRepository(
            apiService: apiService
        )

        let content = try await repository.fetchViewportContent(
            in: MapViewport(
                southLatitude: 37.5,
                westLongitude: 127.0,
                northLatitude: 37.6,
                eastLongitude: 127.1
            ),
            tourismCategory: .food
        )

        XCTAssertEqual(
            apiService.requestedTourismCategories,
            [.food]
        )
        XCTAssertEqual(
            content.tourismMarkers.first?.category,
            .food
        )
    }
}

private final class MapViewportAPIServiceStub: MapAPIService {
    var previewResponse: MapMarkerSummaryDTO?
    var previewMarkerID: Int64?
    var previewType: String?
    func fetchPreview(type: String, markerID: Int64) async throws -> MapMarkerSummaryDTO {
        previewMarkerID = markerID
        previewType = type
        guard let previewResponse else { throw APIError.invalidResponse }
        return previewResponse
    }

    func search(query: String, scope: String, category: TourismMapCategory) async throws -> MapSearchResponseDTO {
        MapSearchResponseDTO(items: [], tourismAvailable: true)
    }

    let response: MapViewportResponseDTO
    private(set) var requestedTourismCategories: [TourismMapCategory] = []

    init(
        response: MapViewportResponseDTO
    ) {
        self.response = response
    }

    func fetchViewportContent(
        in viewport: MapViewport,
        tourismCategory: TourismMapCategory
    ) async throws -> MapViewportResponseDTO {
        requestedTourismCategories.append(tourismCategory)
        return response
    }
}
