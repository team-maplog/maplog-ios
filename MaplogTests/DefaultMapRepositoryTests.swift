import XCTest
@testable import Maplog

final class DefaultMapRepositoryTests: XCTestCase {
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
