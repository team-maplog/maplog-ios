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

    private let mapRepository: any MapRepository
    private let logMediaRepository: any LogMediaRepository // 썸네일 내려받음

    private var scheduledLoadTask: Task<Void, Never>?
    private var selectedMarkerThumbnailTask: Task<Void, Never>?
    private var latestObservedViewport: MapViewport?
    private var latestRequestedViewport: MapViewport?

    init(
        mapRepository: any MapRepository,
        logMediaRepository: any LogMediaRepository
    ) {
        self.mapRepository = mapRepository
        self.logMediaRepository = logMediaRepository
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
        guard let content = state.content,
              let marker = content.markers.first(
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
            } else {
                state = .content(content)
                removeSelectionIfNeeded(
                    from: content
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

    private func removeSelectionIfNeeded(
        from content: MapViewportContent
    ) {
        guard let selectedMarkerID else {
            return
        }

        let stillExists = content.markers.contains {
            $0.id == selectedMarkerID
        }

        if !stillExists {
            clearSelection()
        }
    }

    deinit {
        scheduledLoadTask?.cancel()
        selectedMarkerThumbnailTask?.cancel()
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
