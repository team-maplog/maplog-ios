//
//  HomeMapPanelViewModel.swift
//  Maplog
//
//  Created by 한채림 on 8/17/26.
//

import Foundation

@MainActor
final class HomeMapPanelViewModel: ObservableObject {
    @Published private(set) var state: HomeMapPanelState = .idle

    /// 현재 사용자가 선택한 지도 마커의 clipID
    @Published private(set) var selectedPointID: Int64?

    private let logRouteRepository: any LogRouteRepository

    /// 재시도할 때 어느 로그를 다시 요청해야 하는지 기억
    private var requestedLogID: Int64?

    init(
        logRouteRepository: any LogRouteRepository
    ) {
        self.logRouteRepository = logRouteRepository
    }

    func loadRoute(
        for logID: Int64
    ) async {
        guard logID > 0 else {
            clear()
            return
        }

        /// 이미 현재 로그의 경로를 보여 주고 있다면 다시 요청하지 않음
        if case let .content(route) = state,
           route.logID == logID {
            return
        }

        requestedLogID = logID
        selectedPointID = nil
        state = .loading

        do {
            let route = try await logRouteRepository.fetchRoute(
                logID: logID
            )

            guard !Task.isCancelled,
                  requestedLogID == logID else {
                return
            }

            let viewData = makeViewData(
                from: route
            )

            guard !viewData.points.isEmpty else {
                state = .empty
                return
            }

            state = .content(viewData)

            /// 지도가 처음 열리면 첫 번째 장소를 기본 선택
            selectedPointID = viewData.points.first?.id

        } catch is CancellationError {
            guard requestedLogID == logID else {
                return
            }

            state = .idle

        } catch {
            guard requestedLogID == logID else {
                return
            }

            state = .failed(
                HomeMapRouteErrorPolicy.presentation(
                    for: error
                )
            )
        }
    }

    func retry() async {
        guard let requestedLogID else {
            return
        }

        state = .idle

        await loadRoute(
            for: requestedLogID
        )
    }

    func selectPoint(
        id: Int64
    ) {
        guard case let .content(route) = state,
              route.points.contains(where: { $0.id == id }) else {
            return
        }

        selectedPointID = id
    }

    func clear() {
        requestedLogID = nil
        selectedPointID = nil
        state = .idle
    }

    var selectedPoint: HomeMapRoutePointViewData? {
        guard case let .content(route) = state,
              let selectedPointID else {
            return nil
        }

        return route.points.first {
            $0.id == selectedPointID
        }
    }

    private func makeViewData(
        from route: LogRoute
    ) -> HomeMapRouteViewData {
        HomeMapRouteViewData(
            logID: route.logID,
            points: route.points.map { point in
                HomeMapRoutePointViewData(
                    clipID: point.clipID,
                    sequence: point.sequence,
                    startTimeMillis: point.startTimeMillis,
                    endTimeMillis: point.endTimeMillis,
                    placeName: displayPlaceName(
                        from: point.placeName
                    ),
                    address: point.address,
                    latitude: point.latitude,
                    longitude: point.longitude,
                    thumbnailURL: point.thumbnailURL
                )
            }
        )
    }

    private func displayPlaceName(
        from placeName: String
    ) -> String {
        let trimmedName = placeName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmedName.isEmpty
            ? "이름 없는 장소"
            : trimmedName
    }
}

enum HomeMapPanelState: Equatable {
    case idle
    case loading
    case content(HomeMapRouteViewData)
    case empty
    case failed(ErrorPresentation)
}
