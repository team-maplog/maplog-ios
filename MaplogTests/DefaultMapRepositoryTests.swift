import XCTest
@testable import Maplog

final class DefaultMapRepositoryTests: XCTestCase {
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
