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
    @Published private(set) var selectedSearchScope: ExploreMapSearchScope = .all
    @Published private(set) var mapLogThumbnailDataByMarkerID: [String: Data] = [:]
    @Published private(set) var currentLocation: MapCoordinate?
    @Published private(set) var currentLocationFocusRequestID: UUID?
    @Published private(set) var isLoadingCurrentLocation = false

    private let mapRepository: any MapRepository
    private let logMediaRepository: any LogMediaRepository // 썸네일 내려받음
    private let currentLocationService: any MapCurrentLocationService

    private var scheduledLoadTask: Task<Void, Never>?
    private var selectedMarkerThumbnailTask: Task<Void, Never>?
    private var mapMarkerThumbnailLoadTask: Task<Void, Never>?
    private var latestObservedViewport: MapViewport?
    private var latestRequestedViewport: MapViewport?

    private static let mapThumbnailPrefetchLimit = 24

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

        guard viewport != latestRequestedViewport else {
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
                in: viewport
            )
        }
    }

    func retry() async {
        guard let latestObservedViewport else {
            return
        }

        scheduledLoadTask?.cancel()

        await loadContent(
            in: latestObservedViewport
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

        selectedMarkerID = id

        loadThumbnail(
            for: marker
        )
    }

    func clearSelection() {
        selectedMarkerThumbnailTask?.cancel()

        selectedMarkerID = nil
        selectedMarkerThumbnailData = nil
        isLoadingSelectedMarkerThumbnail = false
    }

    var selectedMarker: MapMarker? {
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
        markers(
            matching: selectedSearchScope
        )
    }

    func markerCount(
        for scope: ExploreMapSearchScope
    ) -> Int {
        markers(
            matching: scope
        )
        .count
    }

    func updateSearchQuery(
        _ query: String
    ) {
        searchQuery = query
        clearSelectionIfFilteredOut()
    }

    func selectSearchScope(
        _ scope: ExploreMapSearchScope
    ) {
        selectedSearchScope = scope
        clearSelectionIfFilteredOut()
    }

    func clearSearch() {
        searchQuery = ""
        selectedSearchScope = .all
        clearSelectionIfFilteredOut()
    }

    func retrySelectedMarkerThumbnail() {
        guard let selectedMarker else {
            return
        }

        loadThumbnail(
            for: selectedMarker
        )
    }

    private func loadContent(
        in viewport: MapViewport
    ) async {
        let previousContent = state.content

        latestRequestedViewport = viewport
        refreshError = nil

        if previousContent == nil {
            state = .loading
        }

        do {
            let content = try await mapRepository
                .fetchViewportContent(
                    in: viewport
                )

            guard !Task.isCancelled,
                  latestRequestedViewport == viewport
            else {
                return
            }

            if content.markers.isEmpty {
                state = .empty
                clearSelection()
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
            guard latestRequestedViewport == viewport else {
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
        matching scope: ExploreMapSearchScope
    ) -> [MapMarker] {
        guard let content = state.content else {
            return []
        }

        return content.markers.filter { marker in
            scope.includes(marker)
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
        scheduledLoadTask?.cancel()
        selectedMarkerThumbnailTask?.cancel()
        mapMarkerThumbnailLoadTask?.cancel()
    }
}

enum ExploreMapSearchScope: CaseIterable, Equatable, Identifiable {
    case all
    case maplog
    case tourism

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
            return "관광"
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
