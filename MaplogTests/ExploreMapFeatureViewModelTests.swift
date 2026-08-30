import Foundation
import XCTest
@testable import Maplog

@MainActor
final class ExploreMapFeatureViewModelTests: XCTestCase {
    func testSearchFiltersCurrentViewportMarkersByKeywordAndScope() async throws {
        let viewModel = makeViewModel()

        await loadContent(
            into: viewModel
        )

        viewModel.updateSearchQuery("성수")

        XCTAssertEqual(
            viewModel.filteredMarkers.map(\.id),
            [
                "log-1-11",
                "tourism-3"
            ]
        )

        viewModel.selectFilter(.maplog)

        XCTAssertEqual(
            viewModel.filteredMarkers.map(\.id),
            [
                "log-1-11"
            ]
        )
    }

    func testSearchClearsSelectedMarkerWhenItIsFilteredOut() async throws {
        let viewModel = makeViewModel()

        await loadContent(
            into: viewModel
        )
        viewModel.selectMarker(id: "log-1-11")

        viewModel.updateSearchQuery("서울숲")

        XCTAssertNil(viewModel.selectedMarkerID)
        XCTAssertEqual(
            viewModel.filteredMarkers.map(\.id),
            [
                "log-2-21"
            ]
        )
    }

    func testViewportContentPrefetchesMapLogMarkerThumbnail() async throws {
        let mediaRepository = MapLogMediaRepositoryStub()
        let viewModel = makeViewModel(
            mediaRepository: mediaRepository
        )

        await loadContent(
            into: viewModel
        )

        XCTAssertEqual(
            mediaRepository.requestedRoutePointThumbnailURLs,
            [URL(string: "https://example.com/marker-1.jpg")!]
        )
        XCTAssertEqual(
            viewModel.mapLogThumbnailDataByMarkerID["log-1-11"],
            Data("thumbnail".utf8)
        )
    }

    func testFocusCurrentLocationRequestsCoordinateAndCreatesMapMoveCommand() async throws {
        let locationService = MapCurrentLocationServiceStub(
            coordinate: MapCoordinate(
                latitude: 37.5012,
                longitude: 127.0396
            )
        )
        let viewModel = makeViewModel(
            locationService: locationService
        )

        await viewModel.focusCurrentLocation()

        XCTAssertEqual(
            viewModel.currentLocation,
            MapCoordinate(
                latitude: 37.5012,
                longitude: 127.0396
            )
        )
        XCTAssertNotNil(viewModel.currentLocationFocusRequestID)
        XCTAssertEqual(locationService.requestCount, 1)
    }

    func testTourismCategoryFilterShowsOnlyMatchingTourismMarkers() async throws {
        let viewModel = makeViewModel()

        await loadContent(
            into: viewModel
        )

        viewModel.selectFilter(.food)

        XCTAssertEqual(
            viewModel.filteredMarkers.map(\.id),
            ["tourism-4"]
        )
    }

    private func loadContent(
        into viewModel: ExploreMapFeatureViewModel
    ) async {
        viewModel.mapDidBecomeIdle(
            in: MapViewport(
                southLatitude: 37.5,
                westLongitude: 127.0,
                northLatitude: 37.6,
                eastLongitude: 127.1
            )
        )

        try? await Task.sleep(
            nanoseconds: 450_000_000
        )
    }

    private func makeViewModel(
        mediaRepository: MapLogMediaRepositoryStub = MapLogMediaRepositoryStub(),
        locationService: MapCurrentLocationServiceStub? = nil
    ) -> ExploreMapFeatureViewModel {
        ExploreMapFeatureViewModel(
            mapRepository: MapRepositoryStub(
                content: MapViewportContent(
                    logMarkers: [
                        MapLogMarker(
                            logID: 1,
                            clipID: 11,
                            sequence: 1,
                            startTimeMillis: 0,
                            endTimeMillis: 1_000,
                            caption: "성수 카페 기록",
                            placeName: "성수 카페",
                            address: "서울 성동구 성수동",
                            thumbnailURL: URL(
                                string: "https://example.com/marker-1.jpg"
                            ),
                            coordinate: MapCoordinate(
                                latitude: 37.54,
                                longitude: 127.04
                            )
                        ),
                        MapLogMarker(
                            logID: 2,
                            clipID: 21,
                            sequence: 1,
                            startTimeMillis: 0,
                            endTimeMillis: 1_000,
                            caption: "서울숲 산책",
                            placeName: "서울숲",
                            address: "서울 성동구 뚝섬로",
                            thumbnailURL: nil,
                            coordinate: MapCoordinate(
                                latitude: 37.55,
                                longitude: 127.03
                            )
                        )
                    ],
                    tourismMarkers: [
                        TourismMapMarker(
                            tourismID: 3,
                            name: "성수 문화 축제",
                            thumbnailURL: nil,
                            startDateText: nil,
                            endDateText: nil,
                            category: .festival,
                            coordinate: MapCoordinate(
                                latitude: 37.53,
                                longitude: 127.05
                            )
                        ),
                        TourismMapMarker(
                            tourismID: 4,
                            name: "강남 맛집",
                            thumbnailURL: nil,
                            startDateText: nil,
                            endDateText: nil,
                            category: .food,
                            coordinate: MapCoordinate(
                                latitude: 37.52,
                                longitude: 127.01
                            )
                        )
                    ],
                    isLogMarkerTruncated: false,
                    tourismStatus: TourismMapStatus(
                        isAvailable: true,
                        isStale: false,
                        isTruncated: false
                    )
                )
            ),
            logMediaRepository: mediaRepository,
            currentLocationService: locationService
                ?? MapCurrentLocationServiceStub(
                    coordinate: MapCoordinate(
                        latitude: 37.54,
                        longitude: 127.04
                    )
                )
        )
    }
}

private final class MapRepositoryStub: MapRepository {
    let content: MapViewportContent

    init(
        content: MapViewportContent
    ) {
        self.content = content
    }

    func fetchViewportContent(
        in viewport: MapViewport,
        tourismCategory: TourismMapCategory
    ) async throws -> MapViewportContent {
        content
    }
}

private final class MapLogMediaRepositoryStub: LogMediaRepository {
    private(set) var requestedRoutePointThumbnailURLs: [URL] = []

    func fetchThumbnailData(
        logID: Int64,
        targetSize: MaplogImageTargetSize
    ) async throws -> Data {
        Data()
    }

    func fetchPlaybackFileURL(
        logID: Int64
    ) async throws -> URL {
        URL(fileURLWithPath: "/tmp/log.mov")
    }

    func fetchRoutePointThumbnailData(
        from url: URL,
        targetSize: MaplogImageTargetSize
    ) async throws -> Data {
        requestedRoutePointThumbnailURLs.append(url)
        return Data("thumbnail".utf8)
    }
}

@MainActor
private final class MapCurrentLocationServiceStub: MapCurrentLocationService {
    let coordinate: MapCoordinate
    private(set) var requestCount = 0

    init(
        coordinate: MapCoordinate
    ) {
        self.coordinate = coordinate
    }

    func requestCurrentLocation() async throws -> MapCoordinate {
        requestCount += 1
        return coordinate
    }
}
