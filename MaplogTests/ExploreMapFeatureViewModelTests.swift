import Foundation
import XCTest
@testable import Maplog

@MainActor
final class ExploreMapFeatureViewModelTests: XCTestCase {
    func testUnavailableTourismWithoutMarkersKeepsFailureStatusForRetry() async {
        let content = MapViewportContent(logMarkers: [], tourismMarkers: [],
            isLogMarkerTruncated: false,
            tourismStatus: TourismMapStatus(isAvailable: false, isStale: false, isTruncated: false))
        let viewModel = makeViewModel(mapRepository: MapRepositoryStub(content: content))
        await loadContent(into: viewModel)
        XCTAssertEqual(viewModel.state, .content(content))
        XCTAssertTrue(viewModel.filteredMarkers.isEmpty)
    }

    func testUnavailableTourismPreservesLogMarkers() async {
        let initial = makeMapViewportContent()
        let content = MapViewportContent(logMarkers: initial.logMarkers, tourismMarkers: [],
            isLogMarkerTruncated: false,
            tourismStatus: TourismMapStatus(isAvailable: false, isStale: false, isTruncated: false))
        let viewModel = makeViewModel(mapRepository: MapRepositoryStub(content: content))
        await loadContent(into: viewModel)
        XCTAssertEqual(viewModel.filteredMarkers.map(\.id), initial.logMarkers.map(\.mapMarkerID))
        XCTAssertEqual(viewModel.state.content?.tourismStatus.isAvailable, false)
    }

    func testStaleFestivalMarkersRemainVisible() async {
        let initial = makeMapViewportContent()
        let content = MapViewportContent(logMarkers: [], tourismMarkers: initial.tourismMarkers,
            isLogMarkerTruncated: false,
            tourismStatus: TourismMapStatus(isAvailable: true, isStale: true, isTruncated: false))
        let viewModel = makeViewModel(mapRepository: MapRepositoryStub(content: content))
        await loadContent(into: viewModel)
        XCTAssertEqual(viewModel.filteredMarkers, content.markers)
        XCTAssertEqual(viewModel.state.content?.tourismStatus.isStale, true)
    }

    func testClosingCardDiscardsPendingPreview() async throws {
        let viewModel = makeViewModel()
        await loadContent(into: viewModel)
        viewModel.selectMarker(id: "log-1-11")
        viewModel.clearSelection()
        await Task.yield()
        XCTAssertNil(viewModel.selectedMarkerSummary)
        XCTAssertNil(viewModel.selectedMarkerID)
        XCTAssertFalse(viewModel.isLoadingPreview)
    }

    func testSelectedMarkerLoadsPreview() async throws {
        let viewModel = makeViewModel()
        await loadContent(into: viewModel)
        viewModel.selectMarker(id: "log-1-11")
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(viewModel.selectedMarkerSummary?.id, "log-1-11")
        XCTAssertNil(viewModel.previewError)
    }

    func testSelectingRemoteResultMovesCameraWithoutChangingCurrentLocation() async {
        let viewModel = makeViewModel()
        await viewModel.loadCurrentLocationIfNeeded()
        let originalLocation = viewModel.currentLocation
        let marker = MapMarker.tourism(TourismMapMarker(
            tourismID: 99, name: "부산", thumbnailURL: nil, startDateText: nil, endDateText: nil,
            category: .natureTourism, coordinate: MapCoordinate(latitude: 35.1, longitude: 129.0)
        ))
        viewModel.selectSearchResult(MapMarkerSummary(marker: marker, title: "부산", subtitle: "", summary: nil))
        XCTAssertEqual(viewModel.selectedMarker, marker)
        XCTAssertEqual(viewModel.searchFocusRequest?.coordinate, marker.coordinate)
        XCTAssertEqual(viewModel.currentLocation, originalLocation)
        XCTAssertTrue(viewModel.filteredMarkers.contains(marker))
        XCTAssertFalse(viewModel.showsSearchResults)
    }

    func testClearingSearchCancelsPendingResults() async throws {
        let viewModel = makeViewModel()
        viewModel.updateSearchQuery("서울")
        XCTAssertTrue(viewModel.isSearching)
        viewModel.clearSearch()
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertFalse(viewModel.showsSearchResults)
        XCTAssertTrue(viewModel.searchResults.isEmpty)
    }

    func testOverlongSearchDoesNotStartRequest() {
        let viewModel = makeViewModel()
        viewModel.updateSearchQuery(String(repeating: "가", count: 51))
        XCTAssertNotNil(viewModel.searchError)
        XCTAssertFalse(viewModel.isSearching)
    }

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

    func testInitialLocationFocusesOnceAndPreservesCameraRequestOnReturn() async {
        let service = MapCurrentLocationServiceStub(coordinate: MapCoordinate(latitude: 35.1, longitude: 129.0))
        let viewModel = makeViewModel(locationService: service)

        await viewModel.loadCurrentLocationIfNeeded()
        let firstRequest = viewModel.currentLocationFocusRequestID
        XCTAssertEqual(viewModel.currentLocation, service.coordinate)
        XCTAssertNotNil(firstRequest)

        await viewModel.loadCurrentLocationIfNeeded()
        XCTAssertEqual(service.requestCount, 1)
        XCTAssertEqual(viewModel.currentLocationFocusRequestID, firstRequest)
    }

    func testInitialLocationFailureDoesNotFocusAndCanRetry() async {
        let service = MapCurrentLocationServiceStub(coordinate: MapCoordinate(latitude: 35.1, longitude: 129.0))
        service.error = MapCurrentLocationError.authorizationDenied
        let viewModel = makeViewModel(locationService: service)

        await viewModel.loadCurrentLocationIfNeeded()
        XCTAssertNil(viewModel.currentLocation)
        XCTAssertNil(viewModel.currentLocationFocusRequestID)
        XCTAssertFalse(viewModel.isLoadingCurrentLocation)

        service.error = nil
        await viewModel.loadCurrentLocationIfNeeded()
        XCTAssertEqual(service.requestCount, 2)
        XCTAssertNotNil(viewModel.currentLocationFocusRequestID)
    }

    func testInitialLocationDoesNotOverrideSelectedSearchDestination() async {
        let viewModel = makeViewModel()
        let marker = MapMarker.tourism(TourismMapMarker(
            tourismID: 99, name: "부산", thumbnailURL: nil, startDateText: nil, endDateText: nil,
            category: .natureTourism, coordinate: MapCoordinate(latitude: 35.1, longitude: 129.0)
        ))
        viewModel.selectSearchResult(MapMarkerSummary(marker: marker, title: "부산", subtitle: "", summary: nil))
        let searchRequest = viewModel.searchFocusRequest?.id

        await viewModel.loadCurrentLocationIfNeeded()
        XCTAssertNotNil(viewModel.currentLocation)
        XCTAssertNil(viewModel.currentLocationFocusRequestID)
        XCTAssertEqual(viewModel.searchFocusRequest?.id, searchRequest)
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

    func testEveryVisibleMapFilterUsesItsExpectedCategoryAndMarkerScope() {
        let markers = mapFilterFixtures
        let expectedFilters = expectedMapFilters(for: markers)

        XCTAssertEqual(
            ExploreMapFilter.allCases.map(\.title).contains("행사"),
            true
        )
        XCTAssertEqual(
            ExploreMapFilter.allCases,
            expectedFilters.map(\.filter)
        )

        for expected in expectedFilters {
            XCTAssertEqual(
                expected.filter.tourismRequestCategory,
                expected.category,
                "\(expected.filter.title) 요청 category가 올바르지 않습니다."
            )
            XCTAssertEqual(
                markers
                    .filter(expected.filter.includes)
                    .map(\.id),
                expected.markerIDs,
                "\(expected.filter.title) 필터 표시 대상이 올바르지 않습니다."
            )
        }
    }

    func testSelectingEveryMapFilterReloadsWithMatchingTourismCategory() async throws {
        let repository = MapRepositoryStub(
            content: makeMapViewportContent()
        )
        let viewModel = makeViewModel(mapRepository: repository)
        let expectedFilters = expectedMapFilters(for: mapFilterFixtures)

        await loadContent(into: viewModel)
        XCTAssertEqual(repository.requestedTourismCategories, [.all])

        for expected in expectedFilters.dropFirst() {
            viewModel.selectFilter(expected.filter)
            try await Task.sleep(nanoseconds: 50_000_000)

            XCTAssertEqual(
                repository.requestedTourismCategories.last,
                expected.category,
                "\(expected.filter.title) 선택 시 올바른 category로 다시 조회해야 합니다."
            )
        }
    }

    private func expectedMapFilters(
        for markers: [MapMarker]
    ) -> [(filter: ExploreMapFilter, category: TourismMapCategory, markerIDs: [String])] {
        [
            (.all, .all, markers.map(\.id)),
            (.maplog, .all, ["log-1-11"]),
            (.tourism, .all, tourismMarkerIDs),
            (.events, .events, ["tourism-101", "tourism-102", "tourism-103"]),
            (.festival, .festival, ["tourism-101"]),
            (.performance, .performance, ["tourism-102"]),
            (.event, .event, ["tourism-103"]),
            (.accommodation, .accommodation, ["tourism-104"]),
            (.food, .food, ["tourism-105"]),
            (.shopping, .shopping, ["tourism-106"]),
            (.recommendedCourse, .recommendedCourse, ["tourism-107"]),
            (.experienceTourism, .experienceTourism, ["tourism-108"]),
            (.historyTourism, .historyTourism, ["tourism-109"]),
            (.leisureSports, .leisureSports, ["tourism-110"]),
            (.natureTourism, .natureTourism, ["tourism-111"]),
            (.culturalTourism, .culturalTourism, ["tourism-112"])
        ]
    }

    private var mapFilterFixtures: [MapMarker] {
        [
            .log(MapLogMarker(
                logID: 1,
                clipID: 11,
                sequence: 1,
                startTimeMillis: 0,
                endTimeMillis: 1_000,
                caption: nil,
                placeName: "맵로그",
                address: nil,
                thumbnailURL: nil,
                coordinate: MapCoordinate(latitude: 37.54, longitude: 127.04)
            )),
            tourismMarker(id: 101, category: .festival),
            tourismMarker(id: 102, category: .performance),
            tourismMarker(id: 103, category: .event),
            tourismMarker(id: 104, category: .accommodation),
            tourismMarker(id: 105, category: .food),
            tourismMarker(id: 106, category: .shopping),
            tourismMarker(id: 107, category: .recommendedCourse),
            tourismMarker(id: 108, category: .experienceTourism),
            tourismMarker(id: 109, category: .historyTourism),
            tourismMarker(id: 110, category: .leisureSports),
            tourismMarker(id: 111, category: .natureTourism),
            tourismMarker(id: 112, category: .culturalTourism)
        ]
    }

    private var tourismMarkerIDs: [String] {
        mapFilterFixtures.dropFirst().map(\.id)
    }

    private func tourismMarker(
        id: Int64,
        category: TourismMapCategory
    ) -> MapMarker {
        .tourism(TourismMapMarker(
            tourismID: id,
            name: category.title,
            thumbnailURL: nil,
            startDateText: nil,
            endDateText: nil,
            category: category,
            coordinate: MapCoordinate(latitude: 37.5, longitude: 127.0)
        ))
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
        mapRepository: (any MapRepository)? = nil,
        mediaRepository: MapLogMediaRepositoryStub = MapLogMediaRepositoryStub(),
        locationService: MapCurrentLocationServiceStub? = nil
    ) -> ExploreMapFeatureViewModel {
        ExploreMapFeatureViewModel(
            mapRepository: mapRepository
                ?? MapRepositoryStub(content: makeMapViewportContent()),
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

    private func makeMapViewportContent() -> MapViewportContent {
        MapViewportContent(
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
    }
}

private final class MapRepositoryStub: MapRepository {
    private(set) var requestedTourismCategories: [TourismMapCategory] = []

    func fetchPreview(for marker: MapMarker) async throws -> MapMarkerSummary {
        MapMarkerSummary(marker: marker, title: marker.title, subtitle: marker.subtitle, summary: nil)
    }

    func search(query: String, scope: String, category: TourismMapCategory) async throws -> MapSearchResult {
        MapSearchResult(items: [], isTourismAvailable: true)
    }

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
        requestedTourismCategories.append(tourismCategory)
        return content
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
    var error: Error?
    private(set) var requestCount = 0

    init(
        coordinate: MapCoordinate
    ) {
        self.coordinate = coordinate
    }

    func requestCurrentLocation() async throws -> MapCoordinate {
        requestCount += 1
        if let error { throw error }
        return coordinate
    }
}
