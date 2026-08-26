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
    private let followRepository: any FollowRepository
    private let profileRepository: any ProfileRepository
    private let playbackService: any VideoPlaybackService
    private let currentLocationService: any MapCurrentLocationService

    @StateObject private var viewModel: ExploreMapFeatureViewModel
    @State private var destination: ExploreMapDestination?
    @FocusState private var isSearchFieldFocused: Bool

    init(
        mapRepository: any MapRepository,
        tourismRepository: any TourismRepository,
        logDetailRepository: any LogDetailRepository,
        logMediaRepository: any LogMediaRepository,
        followRepository: any FollowRepository,
        profileRepository: any ProfileRepository,
        playbackService: any VideoPlaybackService,
        currentLocationService: any MapCurrentLocationService
    ) {
        self.tourismRepository = tourismRepository
        self.logDetailRepository = logDetailRepository
        self.logMediaRepository = logMediaRepository
        self.followRepository = followRepository
        self.profileRepository = profileRepository
        self.playbackService = playbackService
        self.currentLocationService = currentLocationService

        _viewModel = StateObject(
            wrappedValue: ExploreMapFeatureViewModel(
                mapRepository: mapRepository,
                logMediaRepository: logMediaRepository,
                currentLocationService: currentLocationService
            )
        )
    }

    var body: some View {
        ZStack {
            ExploreKakaoMap(
                markers: viewModel.filteredMarkers,
                thumbnailDataByMarkerID: viewModel.mapLogThumbnailDataByMarkerID,
                selectedMarkerID: viewModel.selectedMarkerID,
                currentLocation: viewModel.currentLocation,
                currentLocationFocusRequestID: viewModel.currentLocationFocusRequestID,
                onViewportChanged: handleViewportChanged,
                onMarkerSelected: handleMarkerSelected,
                onMapTapped: dismissSearchKeyboard
            )
            .ignoresSafeArea()

        }
        .overlay(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                ExploreMapSearchControls(
                    query: searchQueryBinding,
                    isSearchFieldFocused: $isSearchFieldFocused,
                    selectedScope: viewModel.selectedSearchScope,
                    markerCount: {
                        viewModel.markerCount(
                            for: $0
                        )
                    },
                    onSelectScope: handleSearchScopeSelected,
                    onClearSearch: viewModel.clearSearch
                )

                ExploreMapStateOverlay(
                    state: viewModel.state,
                    refreshError: viewModel.refreshError,
                    onRetry: retry
                )
            }
            .padding(.top, 8)
            .padding(.horizontal, MaplogSpacing.page)
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
        .overlay(alignment: .bottomTrailing) {
            ExploreMapCurrentLocationButton(
                isLoading: viewModel.isLoadingCurrentLocation,
                action: focusCurrentLocation
            )
            .padding(.trailing, MaplogSpacing.page)
            .padding(
                .bottom,
                currentLocationButtonBottomInset
            )
        }
        .toolbar(.hidden, for: .navigationBar)
        .maplogTabBarHidden(false)
        .task {
            await viewModel.loadCurrentLocationIfNeeded()
        }
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
                    followRepository: followRepository,
                    profileRepository: profileRepository,
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
        dismissSearchKeyboard()

        viewModel.selectMarker(
            id: markerID
        )
    }

    private func handleSearchScopeSelected(
        _ scope: ExploreMapSearchScope
    ) {
        dismissSearchKeyboard()
        viewModel.selectSearchScope(scope)
    }

    private func dismissSearchKeyboard() {
        isSearchFieldFocused = false
    }

    private var currentLocationButtonBottomInset: CGFloat {
        MaplogSize.tabBarHeight
        + (viewModel.selectedMarker == nil ? 16 : 164)
    }

    private func focusCurrentLocation() {
        Task {
            await viewModel.focusCurrentLocation()
        }
    }

    private var searchQueryBinding: Binding<String> {
        Binding(
            get: {
                viewModel.searchQuery
            },
            set: {
                viewModel.updateSearchQuery($0)
            }
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

private struct ExploreMapCurrentLocationButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(Color.maplogInk)

                } else {
                    Image(systemName: "location.fill")
                        .font(.title3.weight(.semibold))
                }
            }
            .foregroundStyle(Color.maplogInk)
            .frame(width: 50, height: 50)
            .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .shadow(
            color: .black.opacity(0.16),
            radius: 8,
            x: 0,
            y: 4
        )
        .accessibilityLabel("현재 위치로 지도 이동")
    }
}

private struct ExploreMapStateOverlay: View {
    let state: ExploreMapState
    let refreshError: ErrorPresentation?
    let onRetry: () -> Void

    var body: some View {
        Group {
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
        }
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
