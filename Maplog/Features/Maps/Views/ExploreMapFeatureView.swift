//
//  ExploreMapFeatureView.swift
//  Maplog
//
//  Created by 한채림 on 8/25/26.
//

import SwiftUI

private enum ExploreMapDestination: Hashable {
    case log(Int64)
    case tourism(Int64)
}

struct ExploreMapFeatureView: View {
    private let tourismRepository: any TourismRepository
    private let logDetailRepository: any LogDetailRepository
    private let logMediaRepository: any LogMediaRepository
    private let playbackService: any VideoPlaybackService

    @StateObject private var viewModel: ExploreMapFeatureViewModel
    @State private var destination: ExploreMapDestination?

    init(
        mapRepository: any MapRepository,
        tourismRepository: any TourismRepository,
        logDetailRepository: any LogDetailRepository,
        logMediaRepository: any LogMediaRepository,
        playbackService: any VideoPlaybackService
    ) {
        self.tourismRepository = tourismRepository
        self.logDetailRepository = logDetailRepository
        self.logMediaRepository = logMediaRepository
        self.playbackService = playbackService

        _viewModel = StateObject(
            wrappedValue: ExploreMapFeatureViewModel(
                mapRepository: mapRepository,
                logMediaRepository: logMediaRepository
            )
        )
    }

    var body: some View {
        ZStack {
            ExploreKakaoMap(
                markers: viewModel.state.content?.markers ?? [],
                selectedMarkerID: viewModel.selectedMarkerID,
                onViewportChanged: handleViewportChanged,
                onMarkerSelected: handleMarkerSelected
            )
            .ignoresSafeArea()

            ExploreMapStateOverlay(
                state: viewModel.state,
                refreshError: viewModel.refreshError,
                onRetry: retry
            )
        }
        .overlay(alignment: .bottom) {
            if let marker = viewModel.selectedMarker {
                ExploreMapMarkerPreviewCard(
                    marker: marker,
                    thumbnailData: viewModel.selectedMarkerThumbnailData,
                    isLoadingThumbnail: viewModel.isLoadingSelectedMarkerThumbnail,
                    onOpen: openSelectedMarker,
                    onDismiss: viewModel.clearSelection,
                    onRetryThumbnail: viewModel.retrySelectedMarkerThumbnail
                )
                .padding(.horizontal, MaplogSpacing.page)
                .padding(
                    .bottom,
                    MaplogSize.tabBarHeight + 12
                )
                .transition(
                    .move(edge: .bottom)
                        .combined(with: .opacity)
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .maplogTabBarHidden(false)
        .animation(
            .smooth(duration: 0.25),
            value: viewModel.selectedMarkerID
        )
        .navigationDestination(
            item: $destination
        ) { destination in
            switch destination {
            case let .log(logID):
                LogDetailFeatureView(
                    logID: logID,
                    allowsManagement: false,
                    logDetailRepository: logDetailRepository,
                    logMediaRepository: logMediaRepository,
                    playbackService: playbackService,
                    onLogRemoved: { }
                )

            case let .tourism(tourismID):
                TourismDetailView(
                    tourismID: tourismID,
                    tourismRepository: tourismRepository
                )
            }
        }
    }

    private func handleViewportChanged(
        _ viewport: MapViewport
    ) {
        viewModel.mapDidBecomeIdle(
            in: viewport
        )
    }

    private func handleMarkerSelected(
        _ markerID: String
    ) {
        viewModel.selectMarker(
            id: markerID
        )
    }

    private func retry() {
        Task {
            await viewModel.retry()
        }
    }

    private func openSelectedMarker() {
        guard let marker = viewModel.selectedMarker else {
            return
        }

        switch marker {
        case let .log(logMarker):
            destination = .log(logMarker.logID)

        case let .tourism(tourismMarker):
            destination = .tourism(tourismMarker.tourismID)
        }
    }
}

private struct ExploreMapStateOverlay: View {
    let state: ExploreMapState
    let refreshError: ErrorPresentation?
    let onRetry: () -> Void

    var body: some View {
        VStack {
            switch state {
            case .idle:
                EmptyView()

            case .loading:
                loadingMessage

            case .empty:
                emptyMessage

            case let .failed(presentation):
                errorMessage(
                    presentation: presentation
                )

            case let .content(content):
                contentNotice(
                    content: content
                )
            }

            Spacer()
        }
        .padding(.top, 18)
        .padding(.horizontal, MaplogSpacing.page)
    }

    private var loadingMessage: some View {
        HStack(spacing: 10) {
            ProgressView()

            Text("이 지역의 장소를 찾고 있어요")
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
    }

    private var emptyMessage: some View {
        Text("이 지도 범위에는 아직 기록된 장소가 없어요.")
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: Capsule())
    }

    private func errorMessage(
        presentation: ErrorPresentation
    ) -> some View {
        VStack(spacing: 10) {
            Text(presentation.message)
                .font(.subheadline)
                .multilineTextAlignment(.center)

            if presentation.recoveryAction == .retry {
                Button(
                    "다시 시도",
                    action: onRetry
                )
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(
            .regularMaterial,
            in: RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
    }

    private func contentNotice(
        content: MapViewportContent
    ) -> some View {
        Group {
            if content.shouldAskUserToZoomIn {
                Text("장소가 많아요. 지도를 확대해 더 자세히 보세요.")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())

            } else if let refreshError {
                Text(refreshError.message)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())

            } else {
                EmptyView()
            }
        }
    }
}
