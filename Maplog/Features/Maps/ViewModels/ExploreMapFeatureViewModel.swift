//
//  ExploreMapViewModel.swift
//  Maplog
//
//  Created by 한채림 on 8/25/26.
//

import Foundation

@MainActor
final class ExploreMapFeatureViewModel: ObservableObject {
    @Published private(set) var state: ExploreMapState = .idle
    @Published private(set) var selectedMarkerID: String?
    @Published private(set) var refreshError: ErrorPresentation?
    @Published private(set) var selectedMarkerThumbnailData: Data?
    @Published private(set) var isLoadingSelectedMarkerThumbnail = false
    @Published private(set) var searchQuery = ""
    @Published private(set) var selectedFilter: ExploreMapFilter = .all
    @Published private(set) var mapLogThumbnailDataByMarkerID: [String: Data] = [:]
    @Published private(set) var currentLocation: MapCoordinate?
    @Published private(set) var currentLocationFocusRequestID: UUID?
    @Published private(set) var isLoadingCurrentLocation = false

    @Published private(set) var searchResults: [MapMarkerSummary] = []
    @Published private(set) var isSearching = false
    @Published private(set) var searchError: ErrorPresentation?
    @Published private(set) var isTourismSearchAvailable = true
    @Published private(set) var showsSearchResults = false
    @Published private(set) var searchFocusRequest: MapCameraFocusRequest?
    private var searchTask: Task<Void, Never>?
    private var searchGeneration = UUID()
    private var selectedSearchMarker: MapMarker?

    private let mapRepository: any MapRepository
    private let logMediaRepository: any LogMediaRepository // 썸네일 내려받음
    private let currentLocationService: any MapCurrentLocationService

    private var scheduledLoadTask: Task<Void, Never>?
    private var selectedMarkerThumbnailTask: Task<Void, Never>?
    private var mapMarkerThumbnailLoadTask: Task<Void, Never>?
    private var latestObservedViewport: MapViewport?
    private var latestRequestedLoad: ViewportContentLoad?

    private static let mapThumbnailPrefetchLimit = 24

    private struct ViewportContentLoad: Equatable {
        let viewport: MapViewport
        let tourismCategory: TourismMapCategory
    }

    init(
        mapRepository: any MapRepository,
        logMediaRepository: any LogMediaRepository,
        currentLocationService: any MapCurrentLocationService
    ) {
        self.mapRepository = mapRepository
        self.logMediaRepository = logMediaRepository
        self.currentLocationService = currentLocationService
    }

    /// 지도 탭이 처음 열릴 때 도트 표시용 좌표를 한 번 받아온다.
    func loadCurrentLocationIfNeeded() async {
        guard currentLocation == nil else {
            return
        }

        _ = await refreshCurrentLocation()
    }

    /// 버튼을 누르면 최신 좌표를 요청하고, 지도 이동 명령을 새로 만든다.
    func focusCurrentLocation() async {
        guard let coordinate = await refreshCurrentLocation() else {
            return
        }

        currentLocationFocusRequestID = UUID()
        currentLocation = coordinate
    }

    /// 지도의 드래그·확대·축소가 끝났을 때 호출
    func mapDidBecomeIdle(
        in viewport: MapViewport
    ) {
        latestObservedViewport = viewport

        let load = ViewportContentLoad(
            viewport: viewport,
            tourismCategory: selectedFilter.tourismRequestCategory
        )

        guard load != latestRequestedLoad else {
            return
        }

        scheduledLoadTask?.cancel()

        scheduledLoadTask = Task { [weak self] in
            do {
                try await Task.sleep(
                    nanoseconds: 350_000_000
                )
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            await self?.loadContent(
                for: load
            )
        }
    }

    func retry() async {
        guard let latestObservedViewport else {
            return
        }

        scheduledLoadTask?.cancel()

        await loadContent(
            for: ViewportContentLoad(
                viewport: latestObservedViewport,
                tourismCategory: selectedFilter.tourismRequestCategory
            )
        )
    }

    func selectMarker(
        id: String
    ) {
        guard let marker = filteredMarkers.first(
                where: { $0.id == id }
        )
        else {
            return
        }

        guard selectedMarkerID != id else {
            return
        }

        selectedSearchMarker = nil
        selectedMarkerID = id

        loadThumbnail(
            for: marker
        )
    }

    func clearSelection() {
        selectedMarkerThumbnailTask?.cancel()

        selectedSearchMarker = nil
        selectedMarkerID = nil
        selectedMarkerThumbnailData = nil
        isLoadingSelectedMarkerThumbnail = false
    }

    var selectedMarker: MapMarker? {
        if let selectedSearchMarker { return selectedSearchMarker }

        guard let selectedMarkerID,
              let content = state.content
        else {
            return nil
        }

        return content.markers.first {
            $0.id == selectedMarkerID
        }
    }

    var filteredMarkers: [MapMarker] {
        let visible = markers(matching: selectedFilter)
        guard let selectedSearchMarker, !visible.contains(where: { $0.id == selectedSearchMarker.id }) else {
            return visible
        }
        return visible + [selectedSearchMarker]
    }

    func selectSearchResult(_ item: MapMarkerSummary) {
        clearSelection()
        selectedSearchMarker = item.marker
        selectedMarkerID = item.id
        showsSearchResults = false
        searchFocusRequest = MapCameraFocusRequest(coordinate: item.marker.coordinate)
        loadThumbnail(for: item.marker)
    }

    func retrySearch() { scheduleSearch() }

    private func scheduleSearch() {
        searchTask?.cancel()
        // 취소가 늦게 전달되는 네트워크 응답도 이전 검색 결과를 덮어쓰지 못하게 한다.
        let generation = UUID()
        searchGeneration = generation
        searchResults = []
        searchError = nil
        isTourismSearchAvailable = true
        let query = normalizedSearchQuery
        showsSearchResults = !query.isEmpty
        isSearching = false
        guard !query.isEmpty else { return }
        guard query.count <= 50 else {
            searchError = ErrorPresentation(message: "검색어는 50자까지 입력해 주세요.", recoveryAction: .none)
            return
        }
        let scope = selectedFilter == .all ? "ALL" : (selectedFilter == .maplog ? "LOG" : "TOURISM")
        let category = selectedFilter.tourismRequestCategory
        isSearching = true
        searchTask = Task { [weak self] in
            guard let self else { return }
            defer { if searchGeneration == generation { isSearching = false } }
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
                let result = try await mapRepository.search(query: query, scope: scope, category: category)
                guard !Task.isCancelled, searchGeneration == generation else { return }
                searchResults = result.items
                isTourismSearchAvailable = result.isTourismAvailable
            } catch {
                guard !Task.isCancelled, searchGeneration == generation else { return }
                searchError = ExploreMapErrorPolicy.presentation(for: error)
            }
        }
    }

    func updateSearchQuery(
        _ query: String
    ) {
        searchQuery = query
        selectedSearchMarker = nil
        scheduleSearch()
        clearSelectionIfFilteredOut()
    }

    func selectFilter(
        _ filter: ExploreMapFilter
    ) {
        guard selectedFilter != filter else {
            return
        }

        selectedFilter = filter
        selectedSearchMarker = nil
        scheduleSearch()
        clearSelectionIfFilteredOut()

        guard let latestObservedViewport else {
            return
        }

        scheduledLoadTask?.cancel()

        let load = ViewportContentLoad(
            viewport: latestObservedViewport,
            tourismCategory: filter.tourismRequestCategory
        )

        Task { [weak self] in
            await self?.loadContent(for: load)
        }
    }

    func clearSearch() {
        searchQuery = ""
        selectedSearchMarker = nil
        scheduleSearch()

        if selectedFilter == .all {
            clearSelectionIfFilteredOut()
        } else {
            selectFilter(.all)
        }
    }

    private func loadContent(
        for load: ViewportContentLoad
    ) async {
        let previousContent = state.content

        latestRequestedLoad = load
        refreshError = nil

        if previousContent == nil {
            state = .loading
        }

        do {
            let content = try await mapRepository
                .fetchViewportContent(
                    in: load.viewport,
                    tourismCategory: load.tourismCategory
                )

            guard !Task.isCancelled,
                  latestRequestedLoad == load
            else {
                return
            }

            if content.markers.isEmpty {
                state = .empty
                if selectedSearchMarker == nil { clearSelection() }
                mapMarkerThumbnailLoadTask?.cancel()
            } else {
                state = .content(content)
                clearSelectionIfFilteredOut()
                loadMapLogThumbnails(
                    for: content.logMarkers
                )
            }

        } catch is CancellationError {
            return

        } catch {
            guard latestRequestedLoad == load else {
                return
            }

            let presentation = ExploreMapErrorPolicy.presentation(
                for: error
            )

            if let previousContent {
                state = .content(previousContent)
                refreshError = presentation
            } else {
                state = .failed(presentation)
            }
        }
    }

    private func refreshCurrentLocation() async -> MapCoordinate? {
        isLoadingCurrentLocation = true

        defer {
            isLoadingCurrentLocation = false
        }

        do {
            let coordinate = try await currentLocationService
                .requestCurrentLocation()

            currentLocation = coordinate
            return coordinate

        } catch {
            // 위치 권한을 거절해도 지도 탐색과 기존 핀은 계속 사용할 수 있어야 한다.
            return currentLocation
        }
    }

    private func loadThumbnail(
        for marker: MapMarker
    ) {
        selectedMarkerThumbnailTask?.cancel()

        selectedMarkerThumbnailData = nil

        guard let thumbnailURL = marker.thumbnailURL else {
            isLoadingSelectedMarkerThumbnail = false
            return
        }

        isLoadingSelectedMarkerThumbnail = true

        let markerID = marker.id

        selectedMarkerThumbnailTask = Task { [weak self] in
            guard let self else {
                return
            }

            defer {
                if self.selectedMarkerID == markerID {
                    self.isLoadingSelectedMarkerThumbnail = false
                }
            }

            do {
                let data = try await logMediaRepository
                    .fetchRoutePointThumbnailData(
                        from: thumbnailURL
                    )

                guard !Task.isCancelled,
                      self.selectedMarkerID == markerID
                else {
                    return
                }

                self.selectedMarkerThumbnailData = data

            } catch is CancellationError {
                return

            } catch {
                // 썸네일 하나의 실패는 지도와 선택 카드를 실패 화면으로 바꾸지 않는다.
                guard self.selectedMarkerID == markerID else {
                    return
                }

                self.selectedMarkerThumbnailData = nil
            }
        }
    }

    private func loadMapLogThumbnails(
        for markers: [MapLogMarker]
    ) {
        mapMarkerThumbnailLoadTask?.cancel()

        let pendingMarkers = markers
            .filter {
                $0.thumbnailURL != nil
                && mapLogThumbnailDataByMarkerID[$0.mapMarkerID] == nil
            }
            .prefix(Self.mapThumbnailPrefetchLimit)

        guard !pendingMarkers.isEmpty else {
            return
        }

        mapMarkerThumbnailLoadTask = Task { [weak self] in
            guard let self else {
                return
            }

            for marker in pendingMarkers {
                guard !Task.isCancelled,
                      let thumbnailURL = marker.thumbnailURL
                else {
                    return
                }

                do {
                    let data = try await logMediaRepository
                        .fetchRoutePointThumbnailData(
                            from: thumbnailURL
                        )

                    guard !Task.isCancelled,
                          isVisibleMapLogMarker(
                            id: marker.mapMarkerID
                          )
                    else {
                        return
                    }

                    mapLogThumbnailDataByMarkerID[
                        marker.mapMarkerID
                    ] = data

                } catch is CancellationError {
                    return

                } catch {
                    continue
                }
            }
        }
    }

    private var normalizedSearchQuery: String {
        searchQuery.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private func markers(
        matching filter: ExploreMapFilter
    ) -> [MapMarker] {
        guard let content = state.content else {
            return []
        }

        return content.markers.filter { marker in
            filter.includes(marker)
            && markerMatchesSearchQuery(marker)
        }
    }

    private func markerMatchesSearchQuery(
        _ marker: MapMarker
    ) -> Bool {
        guard !normalizedSearchQuery.isEmpty else {
            return true
        }

        return marker.searchableTexts.contains {
            $0.localizedCaseInsensitiveContains(
                normalizedSearchQuery
            )
        }
    }

    private func clearSelectionIfFilteredOut() {
        guard let selectedMarkerID else {
            return
        }

        let stillExists = filteredMarkers.contains {
            $0.id == selectedMarkerID
        }

        if !stillExists {
            clearSelection()
        }
    }

    private func isVisibleMapLogMarker(
        id: String
    ) -> Bool {
        state.content?.logMarkers.contains {
            $0.mapMarkerID == id
        }
        ?? false
    }

    deinit {
        searchTask?.cancel()
        scheduledLoadTask?.cancel()
        selectedMarkerThumbnailTask?.cancel()
        mapMarkerThumbnailLoadTask?.cancel()
    }
}

enum ExploreMapFilter: CaseIterable, Equatable, Identifiable {
    case all
    case maplog
    case tourism
    case events
    case festival
    case performance
    case event
    case accommodation
    case food
    case shopping
    case recommendedCourse
    case experienceTourism
    case historyTourism
    case leisureSports
    case natureTourism
    case culturalTourism

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .all:
            return "전체"

        case .maplog:
            return "맵로그"

        case .tourism:
            return "관광 전체"
        case .events:
            return "행사 전체"
        case .festival:
            return "축제"
        case .performance:
            return "공연"
        case .event:
            return "행사"
        case .accommodation:
            return "숙소"
        case .food:
            return "음식점·카페"
        case .shopping:
            return "쇼핑"
        case .recommendedCourse:
            return "추천 코스"
        case .experienceTourism:
            return "체험 관광"
        case .historyTourism:
            return "역사 관광"
        case .leisureSports:
            return "레저·스포츠"
        case .natureTourism:
            return "자연 관광"
        case .culturalTourism:
            return "문화 관광"
        }
    }

    var tourismRequestCategory: TourismMapCategory {
        switch self {
        case .all, .maplog, .tourism:
            return .all
        case .events:
            return .events
        case .festival:
            return .festival
        case .performance:
            return .performance
        case .event:
            return .event
        case .accommodation:
            return .accommodation
        case .food:
            return .food
        case .shopping:
            return .shopping
        case .recommendedCourse:
            return .recommendedCourse
        case .experienceTourism:
            return .experienceTourism
        case .historyTourism:
            return .historyTourism
        case .leisureSports:
            return .leisureSports
        case .natureTourism:
            return .natureTourism
        case .culturalTourism:
            return .culturalTourism
        }
    }

    func includes(
        _ marker: MapMarker
    ) -> Bool {
        switch self {
        case .all:
            return true

        case .maplog:
            return marker.kind == .log

        case .tourism:
            return marker.kind == .tourism

        default:
            guard let tourismCategory = marker.tourismCategory else {
                return false
            }

            return tourismCategory.matches(
                requestedCategory: tourismRequestCategory
            )
        }
    }
}

enum ExploreMapState: Equatable {
    case idle
    case loading
    case content(MapViewportContent)
    case empty
    case failed(ErrorPresentation)

    var content: MapViewportContent? {
        guard case let .content(content) = self else {
            return nil
        }

        return content
    }
}
