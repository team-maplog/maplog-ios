//
//  MainTabView.swift
//  Maplog
//
//  Created by 한채림 on 7/22/26.

//HomeView
//→ “전체보기 눌렸어요”만 알림
//
//MainTabView
//→ NavigationStack 경로를 변경
//→ TourismListView 생성
//→ Repository 주입

import SwiftUI

struct MainTabView: View {
    @Environment(\.makeLogPlaybackService) private var makeLogPlaybackService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var homeviewModel: HomeViewModel // @StateObject를 MainTabView에 두는 이유는 MainTabView가 HomeViewModel의 소유자이기 때문, 홈 탭이 다시 그려져도 같은 ViewModel 인스턴스를 유지하기 좋음
    @StateObject private var homeMapPanelViewModel: HomeMapPanelViewModel
    @StateObject private var profileViewModel: ProfileTabViewModel

    @Binding private var requestedTab: MaplogTab?
    @Binding private var requestedCapturePlaceName: String?
    @Binding private var requestedNotificationDestination: MaplogNotificationDestination?

    @State private var selectedTab: MaplogTab
    @State private var previousTab: MaplogTab
    @State private var isTabBarHidden = false
    @State private var prefersReelTabBarStyle = false
    @State private var activeCapturePlaceName: String?
    @State private var isLogClipPickerPresented = false

    private let tourismRepository: any TourismRepository
    private let cameraCaptureService: any CameraCaptureService
    private let mediaDraftRepository: any MediaDraftRepository
    private let videoThumbnailService: any VideoThumbnailService
    private let videoPlaybackService: any VideoPlaybackService
    private let videoExportService: any VideoExportService
    private let captureLocationService: any CaptureLocationService
    private let logLocationRepository: any LogLocationRepository
    private let logPublishingRepository: any LogPublishingRepository
    private let logReelRepository: any LogReelRepository
    private let logInteractionRepository: any LogInteractionRepository
    private let logCommentRepository: any LogCommentRepository
    private let logMediaRepository: any LogMediaRepository
    private let logRouteRepository: any LogRouteRepository
    private let logDetailRepository: any LogDetailRepository
    private let socialConnectionRepository: any SocialConnectionRepository
    private let profileRepository: any ProfileRepository
    private let followRepository: any FollowRepository
    private let mapRepository: any MapRepository
    private let homeSearchRepository: any HomeSearchRepository
    private let notificationRepository: any NotificationRepository
    private let pushNotificationCoordinator: PushNotificationCoordinator
    private let mapCurrentLocationService: any MapCurrentLocationService
    private let photoLibraryVideoImportService: any PhotoLibraryVideoImporting
    private let photoLibraryVideoSaveService: any PhotoLibraryVideoSaving
    @State private var homeNavigationPath: [HomeNavigationRoute] = []


    init(
        tourismRepository: any TourismRepository, // Repository를 받게 함
        cameraCaptureService: any CameraCaptureService,
        mediaDraftRepository: any MediaDraftRepository,
        videoThumbnailService: any VideoThumbnailService,
        videoPlaybackService: any VideoPlaybackService,
        videoExportService: any VideoExportService,
        captureLocationService: any CaptureLocationService,
        logLocationRepository: any LogLocationRepository,
        logPublishingRepository: any LogPublishingRepository,
        logReelRepository: any LogReelRepository,
        logInteractionRepository: any LogInteractionRepository,
        logCommentRepository: any LogCommentRepository,
        logMediaRepository: any LogMediaRepository,
        homeReelPlaybackService: any VideoPlaybackService,
        logRouteRepository: any LogRouteRepository,
        logDetailRepository: any LogDetailRepository,
        profileRepository: any ProfileRepository,
        socialConnectionRepository: any SocialConnectionRepository,
        followRepository: any FollowRepository,
        mapRepository: any MapRepository,
        homeSearchRepository: any HomeSearchRepository,
        notificationRepository: any NotificationRepository,
        pushNotificationCoordinator: PushNotificationCoordinator,
        mapCurrentLocationService: any MapCurrentLocationService,
        photoLibraryVideoImportService: any PhotoLibraryVideoImporting,
        photoLibraryVideoSaveService: any PhotoLibraryVideoSaving,
        requestedTab: Binding<MaplogTab?> = .constant(nil),
        requestedCapturePlaceName: Binding<String?> = .constant(nil),
        requestedNotificationDestination: Binding<MaplogNotificationDestination?> = .constant(nil)
    ) {
        self.tourismRepository = tourismRepository
        self.cameraCaptureService = cameraCaptureService
        self.mediaDraftRepository = mediaDraftRepository
        self.videoThumbnailService = videoThumbnailService
        self.videoPlaybackService = videoPlaybackService
        self.videoExportService = videoExportService
        self.captureLocationService = captureLocationService
        self.logLocationRepository = logLocationRepository
        self.logPublishingRepository = logPublishingRepository
        self.logReelRepository = logReelRepository
        self.logInteractionRepository = logInteractionRepository
        self.logCommentRepository = logCommentRepository
        self.logMediaRepository = logMediaRepository
        self.logRouteRepository = logRouteRepository
        self.logDetailRepository = logDetailRepository
        self.profileRepository = profileRepository
        self.socialConnectionRepository = socialConnectionRepository
        self.followRepository = followRepository
        self.mapRepository = mapRepository
        self.homeSearchRepository = homeSearchRepository
        self.notificationRepository = notificationRepository
        self.pushNotificationCoordinator = pushNotificationCoordinator
        self.mapCurrentLocationService = mapCurrentLocationService
        self.photoLibraryVideoImportService = photoLibraryVideoImportService
        self.photoLibraryVideoSaveService = photoLibraryVideoSaveService

        _requestedTab = requestedTab
        _requestedCapturePlaceName = requestedCapturePlaceName
        _requestedNotificationDestination = requestedNotificationDestination
        _selectedTab = State(initialValue: .home)
        _previousTab = State(initialValue: .home)

        _homeviewModel = StateObject(wrappedValue: HomeViewModel(
            tourismRepository: tourismRepository,
            logReelRepository: logReelRepository,
            logInteractionRepository: logInteractionRepository,
            logMediaRepository: logMediaRepository,
            profileRepository: profileRepository,
            playbackService: homeReelPlaybackService
        )
        )

        _homeMapPanelViewModel = StateObject(
            wrappedValue: HomeMapPanelViewModel(
                logRouteRepository: logRouteRepository,
                logMediaRepository: logMediaRepository
            )
        )

        _profileViewModel = StateObject(
            wrappedValue: ProfileTabViewModel(
                profileRepository: profileRepository,
                logReelRepository: logReelRepository
            )
        )
    }

    private enum HomeNavigationRoute: Hashable { // Hashable인 이유는 NavigationStack의 경로에 넣을 값, 홈에서 갈 수 있는 목적지 이름표
        case tourismList // 관광 목록 화면으로 이동하라는 경로 값
        case tourismDetail(tourismID: Int64)
        case logDetail(logID: Int64)
        case publicProfile(user: FollowUser)
        case notificationInbox
        case notification(MaplogNotificationDestination)
    }

    private var tabSelection: Binding<MaplogTab> {
        Binding(
            get: { selectedTab },
            set: { applyRequestedTab($0) }
        )
    }

    private var usesCompactTabBar: Bool {
        selectedTab != .capture
    }

    private var usesReelTabBarStyle: Bool {
        selectedTab == .home && prefersReelTabBarStyle
    }

    private var tabBarMorphAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.4)
    }

    @ViewBuilder
    private var bottomControls: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: MaplogSpacing.small) { // 각 컴포넌트에 넣은 .glassEffect가 재질을 만들고, 컨테이너는 가까운 유리 두 개를 같은 장면으로 렌더링해 자연스럽고 효율적으로 보이게 해줌
                bottomControlsContent
            }
        } else {
            bottomControlsContent
        }
    }

    private var bottomControlsContent: some View {
        HStack(spacing: MaplogSpacing.small) {
            MaplogTabBar(
                selectedTab: tabSelection,
                isCompact: usesCompactTabBar,
                isReelStyle: usesReelTabBarStyle
            )
            .frame(maxWidth: .infinity)

            MaplogCaptureButton(isReelStyle: usesReelTabBarStyle) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    applyRequestedTab(.capture)
                }
            }
        }
    }

    var body: some View {
        Group {
            switch selectedTab {
            case .home:
                GeometryReader { rootProxy in
                    NavigationStack(path: $homeNavigationPath) {
                        HomeView(
                            viewModel: homeviewModel,
                            mapPanelViewModel: homeMapPanelViewModel,
                            logCommentRepository: logCommentRepository,
                            profileRepository: profileRepository,
                            followRepository: followRepository,
                            homeSearchRepository: homeSearchRepository,
                            logReelRepository: logReelRepository,
                            logMediaRepository: logMediaRepository,
                            topSafeAreaInset: rootProxy.safeAreaInsets.top,
                            onShowAllTourisms: {
                                homeNavigationPath.append(.tourismList)
                            },
                            onShowTourismDetail: { tourismID in
                                homeNavigationPath.append(
                                    .tourismDetail(tourismID: tourismID)
                                )
                            },
                            onShowLogDetail: { logID in
                                homeNavigationPath.append(
                                    .logDetail(logID: logID)
                                )
                            },
                            onShowNotifications: {
                                homeNavigationPath.append(.notificationInbox)
                            },
                            onShowAuthorProfile: { reel in
                                homeNavigationPath.append(
                                    .publicProfile(
                                        user: FollowUser(
                                            id: reel.authorID,
                                            nickname: reel.authorName,
                                            profileImageURL: reel.authorProfileImageURL
                                        )
                                    )
                                )
                            },
                            onShowPublicProfile: { user in
                                homeNavigationPath.append(.publicProfile(user: user))
                            },
                            onCreateLog: {
                                isLogClipPickerPresented = true
                            }
                        )
                        .fullScreenCover(
                            isPresented: $isLogClipPickerPresented,
                            onDismiss: {
                                Task {
                                    await homeviewModel.refreshHome()
                                }
                            }
                        ) {
                            ClipPickerFeatureView(
                                mediaDraftRepository: mediaDraftRepository,
                                videoThumbnailService: videoThumbnailService,
                                videoPlaybackService: videoPlaybackService,
                                videoExportService: videoExportService,
                                logLocationRepository: logLocationRepository,
                                logPublishingRepository: logPublishingRepository,
                                photoLibraryVideoImportService: photoLibraryVideoImportService,
                                photoLibraryVideoSaveService: photoLibraryVideoSaveService
                            )
                        }
                        .navigationDestination(for: HomeNavigationRoute.self) { route in
                            switch route {
                            case .tourismList:
                                TourismListView(
                                    tourismRepository: tourismRepository
                                )

                            case .tourismDetail(let tourismID):
                                TourismDetailView(
                                    tourismID: tourismID,
                                    tourismRepository: tourismRepository
                                )

                            case .logDetail(let logID):
                                LogDetailFeatureView(
                                    logID: logID,
                                    allowsManagement: false,
                                    logDetailRepository: logDetailRepository,
                                    logLocationRepository: logLocationRepository,
                                    logMediaRepository: logMediaRepository,
                                    followRepository: followRepository,
                                    profileRepository: profileRepository,
                                    playbackService: makeLogPlaybackService?() ?? videoPlaybackService,
                                    onLogRemoved: {}
                                )

                            case .notificationInbox:
                                NotificationInboxFeatureView(
                                    notificationRepository: notificationRepository,
                                    pushNotificationCoordinator: pushNotificationCoordinator,
                                    onOpenNotification: { notification in
                                        guard notification.destination != .inbox else { return }
                                        homeNavigationPath.append(.notification(notification.destination))
                                    }
                                )
                                .toolbar(.visible, for: .navigationBar)
                                .maplogTabBarHidden()

                            case .notification(let destination):
                                notificationDestinationView(destination)

                            case .publicProfile(let user):
                                PublicProfileFeatureView(
                                    user: user,
                                    followRepository: followRepository,
                                    profileRepository: profileRepository
                                )
                            }
                        }
                        .ignoresSafeArea(
                            .container,
                            edges: [.top, .bottom]
                        )
                    }
                }
            case .capture:
                NavigationStack {
                    CameraCaptureFeatureView(
                        cameraCaptureService: cameraCaptureService,
                        mediaDraftRepository: mediaDraftRepository,
                        videoThumbnailService: videoThumbnailService,
                        videoPlaybackService: videoPlaybackService,
                        videoExportService: videoExportService,
                        captureLocationService: captureLocationService,
                        logLocationRepository: logLocationRepository,
                        logPublishingRepository: logPublishingRepository,
                        photoLibraryVideoImportService: photoLibraryVideoImportService,
                        photoLibraryVideoSaveService: photoLibraryVideoSaveService
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                            selectedTab = previousTab
                        }
                    }
                    .id(activeCapturePlaceName ?? "manual-capture")
                }
            case .map:
                NavigationStack {
                    ExploreMapFeatureView(
                        mapRepository: mapRepository,
                        tourismRepository: tourismRepository,
                        logDetailRepository: logDetailRepository,
                        logLocationRepository: logLocationRepository,
                        logMediaRepository: logMediaRepository,
                        followRepository: followRepository,
                        profileRepository: profileRepository,
                        playbackService: videoPlaybackService,
                        currentLocationService: mapCurrentLocationService
                    )
                    }
            case .profile:
                NavigationStack {
                    ProfileTabView(
                        profileRepository: profileRepository,
                        socialConnectionRepository: socialConnectionRepository,
                        followRepository: followRepository,
                        logDetailRepository: logDetailRepository,
                        logLocationRepository: logLocationRepository,
                        logMediaRepository: logMediaRepository,
                        playbackService: videoPlaybackService,
                        onLogUpdated: { await homeviewModel.refreshHome() },
                        viewModel: profileViewModel
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if !isTabBarHidden {
                bottomControls
                    .padding(.horizontal, MaplogSpacing.page)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .animation(
                                    tabBarMorphAnimation,
                                    value: usesReelTabBarStyle
                                )
                        }
        }
        .background {
            (
                usesReelTabBarStyle
                    ? Color.black
                    : Color(uiColor: .systemBackground)
            )
            .ignoresSafeArea()
        }
        .onPreferenceChange(MaplogTabBarHiddenPreferenceKey.self) { hidden in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                isTabBarHidden = hidden
            }
        }
        .onPreferenceChange(MaplogTabBarReelStylePreferenceKey.self) { prefersReelStyle in
            withAnimation(tabBarMorphAnimation) {
                prefersReelTabBarStyle = prefersReelStyle
            }
        }
        .onAppear(perform: applyPendingRequestedTab)
        .onChange(of: requestedTab) { _, newTab in
            guard let newTab else { return }

            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                applyRequestedTab(newTab, capturePlaceName: requestedCapturePlaceName)
            }
            requestedTab = nil
            requestedCapturePlaceName = nil
        }
        .onChange(of: requestedNotificationDestination) { _, destination in
            guard let destination else {
                return
            }

            openNotificationDestination(destination)
            requestedNotificationDestination = nil
        }
        .environment(\.maplogSelectTab) { tab in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                applyRequestedTab(tab)
            }
        }
    }

    private func applyPendingRequestedTab() {
        if let requestedNotificationDestination {
            openNotificationDestination(requestedNotificationDestination)
            self.requestedNotificationDestination = nil
            return
        }

        guard let requestedTab else { return }

        applyRequestedTab(requestedTab, capturePlaceName: requestedCapturePlaceName)
        self.requestedTab = nil
        requestedCapturePlaceName = nil
    }

    private func applyRequestedTab(_ tab: MaplogTab) {
        applyRequestedTab(tab, capturePlaceName: nil)
    }

    private func applyRequestedTab(_ tab: MaplogTab, capturePlaceName: String?) {
        // 홈에서 시작한 발행이 성공하면 LogComposeView가 홈 탭 선택을 요청한다.
        // 그 신호로 선택·편집·작성 전체 화면 흐름도 함께 닫아 홈 목록을 새로 고친다.
        if tab == .home {
            isLogClipPickerPresented = false
        }

        if tab == .capture {
            activeCapturePlaceName = capturePlaceName
            if selectedTab != .capture {
                previousTab = selectedTab
            }
        } else {
            previousTab = tab
        }
        selectedTab = tab
    }

    @ViewBuilder
    private func notificationDestinationView(_ destination: MaplogNotificationDestination) -> some View {
        switch destination {
        case let .logDetail(logID, commentID):
            LogDetailFeatureView(
                logID: logID,
                allowsManagement: false,
                logDetailRepository: logDetailRepository,
                logLocationRepository: logLocationRepository,
                logMediaRepository: logMediaRepository,
                followRepository: followRepository,
                profileRepository: profileRepository,
                playbackService: makeLogPlaybackService?() ?? videoPlaybackService,
                onLogRemoved: {},
                initialCommentID: commentID,
                commentRepository: logCommentRepository
            )
        case let .userProfile(userID):
            NotificationProfileFeatureView(
                userID: userID,
                notificationRepository: notificationRepository,
                profileRepository: profileRepository,
                followRepository: followRepository
            )
        case .inbox:
            EmptyView()
        }
    }

    private func openNotificationDestination(
        _ destination: MaplogNotificationDestination
    ) {
        applyRequestedTab(.home)
        homeNavigationPath.removeAll()

        // 푸시 진입도 알림함을 부모 화면으로 둬 대상이 삭제됐을 때 돌아갈 곳을 보장합니다.
        homeNavigationPath.append(.notificationInbox)
        if destination != .inbox {
            homeNavigationPath.append(.notification(destination))
        }
    }
}

private struct MaplogTabBarHiddenPreferenceKey: PreferenceKey {
    static var defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

private struct MaplogTabBarReelStylePreferenceKey: PreferenceKey {
    static var defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    func maplogTabBarHidden(_ hidden: Bool = true) -> some View {
        preference(key: MaplogTabBarHiddenPreferenceKey.self, value: hidden)
    }

    func maplogReelTabBarStyle(_ active: Bool = true) -> some View {
        preference(key: MaplogTabBarReelStylePreferenceKey.self, value: active)
    }
}

struct MaplogTabBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selectedTab: MaplogTab
    var isCompact = false
    var isReelStyle = false

    @ViewBuilder
    var body: some View {
        if isCompact {
            compactTabBar
        } else {
            standardTabBar
        }
    }

    private var standardTabBar: some View {
        HStack(spacing: 0) {
            ForEach(MaplogTab.navigationTabs) { tab in
                Button {
                    select(tab, response: 0.35, dampingFraction: 0.86)
                } label: {
                    MaplogTabBarItem(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        tint: itemColor(for: tab)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, MaplogSpacing.xSmall)
        .padding(.top, 7)
        .padding(.bottom, 5)
        .frame(maxWidth: .infinity)
        .frame(height: MaplogSize.tabBarHeight)
        .background {
            Rectangle()
                .fill(.white.opacity(0.98))
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.maplogLine.opacity(0.82))
                        .frame(height: 1)
                }
        }
    }

    // iOS 버전에 맞춰 유리 표면만 입힘
    @ViewBuilder
    private var compactTabBar: some View {
        Group {
            if #available(iOS 26, *) {
                compactTabBarContent
                    .background(.white.opacity(0.28), in: Capsule())
                    .glassEffect( // .regular → 조금 더 안정적·읽기 쉬운 기본 유리 .clear   → 배경이 더 비치는 맑은 유리
                        .regular.interactive(),
                        in: Capsule())
            } else {
                compactTabBarContent
                    .background(.white.opacity(0.28), in: Capsule())
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                    }
                    .clipShape(Capsule())
                    .shadow(
                        color: .black.opacity(isReelStyle ? 0.10 : 0.12),
                        radius: isReelStyle ? 10 : 12,
                        x: 0,
                        y: isReelStyle ? 4 : 5
                    )
            }
        }
        .environment(\.colorScheme, .light)
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.4),
                value: isReelStyle
            )
    }



    // 탭 아이콘·선택 상태·크기만 담당
    private var compactTabBarContent: some View {
        HStack(spacing: 0) {
            ForEach(MaplogTab.navigationTabs) { tab in
                Button {
                    select(
                        tab,
                        response: 0.32,
                        dampingFraction: 0.88
                    )
                } label: {
                    ZStack {
                        if selectedTab == tab {
                            Capsule()
                                .fill(
                                    Color.maplogPrimary.opacity(0.24)
                                )
                                .padding(
                                    .vertical,
                                    isReelStyle ? 2 : 0
                                )
                        }

                        Image(systemName: tab.icon)
                            .font(
                                .system(
                                    size: isReelStyle ? 18 : 21,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(Color.maplogInk)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(
                        height: isReelStyle
                            ? MaplogSize.minimumTapTarget
                            : 48
                    )
                    .contentShape(Rectangle())
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(
                    selectedTab == tab
                        ? .isSelected
                        : []
                )
            }
        }
        .padding(.horizontal, MaplogSpacing.xxSmall)
        .frame(
            maxWidth: isReelStyle
                ? 258
                : .infinity
        )
        .frame(
            height: isReelStyle
                ? 48
                : 56
        )
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.4),
            value: isReelStyle
        )
    }

    private func itemColor(for tab: MaplogTab) -> Color {
        selectedTab == tab ? .maplogLime : .maplogMuted
    }

    private func select(_ tab: MaplogTab, response: Double, dampingFraction: Double) {
        if reduceMotion {
            selectedTab = tab
        } else {
            withAnimation(.spring(response: response, dampingFraction: dampingFraction)) {
                selectedTab = tab
            }
        }
    }

}

private struct MaplogTabBarItem: View {
    let tab: MaplogTab
    let isSelected: Bool
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous)
                        .fill(tab == .capture ? Color.maplogLime : Color.maplogLime.opacity(0.16))
                        .frame(width: 42, height: 30)
                }

                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tab == .capture && isSelected ? Color.maplogInk : tint)
            }
            .frame(height: 32)

            Text(tab.title)
                .font(MaplogFont.tabLabel)
                .foregroundStyle(isSelected ? (tab == .capture ? Color.maplogInk : tint) : Color.maplogMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}
