import SwiftUI

struct HomeView: View {
    private static let viewportCoordinateSpace = "home-viewport"
    private static let panelSwipeEdgeWidth: CGFloat = 28
    private static let panelSwipeMinimumDistance: CGFloat = 56

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @Environment(\.maplogLogout) private var performLogout
    @ObservedObject var viewModel: HomeViewModel // MainTabView가 만든 하나를 받아서 관찰
    @ObservedObject var mapPanelViewModel: HomeMapPanelViewModel
    let topSafeAreaInset: CGFloat // 전체 화면 높이는 고정하고 홈 콘텐츠만 상태바 아래에서 시작하기 위한 값
    let onShowAllTourisms: () -> Void
    let onShowTourismDetail: (Int64) -> Void

    private enum HomePanel: Int, CaseIterable, Identifiable {
        case reels
        case map
        var id: Int { rawValue }
    }

    private struct MapRouteLoadRequest: Equatable {
        let panel: HomePanel
        let reelID: Int64?
    }

    @State private var showsLocationPermissionPrompt = false
    @State private var showsCurrentLocationSearch = false
    @State private var homeScrollPosition: String? = "home-intro"
    @State private var selectedPanel: HomePanel = .reels
    @State private var videoPreviewRequest: HomeMapRoutePlaybackRequest?

    private var reelInteractionErrorPresented: Binding<Bool> {
        Binding(
            get: { viewModel.interactionError != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissInteractionError()
                }
            }
        )
    }

    private let spotlightEvent = MockMaplogData.spotlightEvent
//    private let homePosts = MockMaplogData.posts

//    private var featuredPost: VlogPost? {
//        homePosts.first
//    }
//
//    private var discoveryPosts: [VlogPost] {
//        Array(homePosts.dropFirst())
//    }

//    private var homeTourismEvents: [FeaturedEvent] {
//        [spotlightEvent] + MockMaplogData.events
//    }

    private var isHomeReelActive: Bool {
        guard let homeScrollPosition else { return false }
        return homeScrollPosition != "home-intro"
    }

    // 릴스 ID를 꺼내는 함수
//    "home-intro"
//    "reel-2" -> 여기서 숫자 2만 꺼냄
//    "reel-15"
    private func reelID(
        from scrollPosition: String?
    ) -> Int64? {
        guard let scrollPosition,
              scrollPosition.hasPrefix("reel-")
        else {
            return nil
        }

        return Int64(
            scrollPosition.dropFirst("reel-".count)
        )
    }

    private var activeReelID: Int64? {
        reelID(
            from: homeScrollPosition
        )
    }

    // 상단 영상/지도 전환 버튼
    private struct HomePanelSwitcher: View {
        @Binding var selection: HomePanel

        var body: some View {
            HStack(spacing: 6) {
                Button {
                    selection = .reels
                } label: {
                    Image(systemName: "play.rectangle.fill")
                        .foregroundStyle(
                            selection == .reels
                                ? Color.maplogInk
                                : .white
                        )
                        .frame(width: 42, height: 32)
                        .background(
                            selection == .reels
                                ? Color.maplogLime
                                : .black.opacity(0.46),
                            in: Capsule()
                        )
                }

                Button {
                    selection = .map
                } label: {
                    Image(systemName: "map.fill")
                        .foregroundStyle(
                            selection == .map
                                ? Color.maplogInk
                                : .white
                        )
                        .frame(width: 42, height: 32)
                        .background(
                            selection == .map
                                ? Color.maplogLime
                                : .black.opacity(0.46),
                            in: Capsule()
                        )
                }
            }
            .padding(4)
            .background(
                .black.opacity(0.30),
                in: Capsule()
            )
            .accessibilityElement(children: .contain)
        }
    }

    /// 지도 위의 팬·핀치 제스처를 방해하지 않도록 화면 가장자리에서만 패널 전환 스와이프를 받는다.
    @ViewBuilder
    private var panelEdgeSwipeOverlay: some View {
        if isHomeReelActive {
            switch selectedPanel {
            case .reels:
                panelEdgeSwipeArea(
                    isLeading: false,
                    expectedDirection: -1
                ) {
                    selectedPanel = .map
                }

            case .map:
                panelEdgeSwipeArea(
                    isLeading: true,
                    expectedDirection: 1
                ) {
                    selectedPanel = .reels
                }
            }
        }
    }

    private func panelEdgeSwipeArea(
        isLeading: Bool,
        expectedDirection: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 0) {
            if isLeading {
                panelEdgeSwipeHandle(
                    expectedDirection: expectedDirection,
                    action: action
                )

                Spacer(minLength: 0)
                    .allowsHitTesting(false)
            } else {
                Spacer(minLength: 0)
                    .allowsHitTesting(false)

                panelEdgeSwipeHandle(
                    expectedDirection: expectedDirection,
                    action: action
                )
            }
        }
    }

    private func panelEdgeSwipeHandle(
        expectedDirection: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Color.black.opacity(0.001)
            .frame(width: Self.panelSwipeEdgeWidth)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onEnded { value in
                        let horizontalDistance = value.translation.width
                        let verticalDistance = value.translation.height

                        guard abs(horizontalDistance) > abs(verticalDistance),
                              horizontalDistance * expectedDirection
                                >= Self.panelSwipeMinimumDistance
                        else {
                            return
                        }

                        action()
                    }
            )
    }

    var body: some View {
        ZStack {
            switch selectedPanel {
            case .reels:
                reelsPanel
                    .transition(.opacity)

            case .map:
                HomeMapPanel(
                    viewModel: mapPanelViewModel,
                    onRequestSignIn: performLogout,
                    onPlayRoutePoint: playRoutePoint
                )
                .transition(.opacity)
            }
        }
        .animation(
            reduceMotion
                ? nil
                : .easeInOut(duration: 0.20),
            value: selectedPanel
        )
        .coordinateSpace(name: Self.viewportCoordinateSpace)
        // 홈 ↔ 릴스 전환 중에도 GeometryReader의 페이지 높이가 바뀌지 않게 유지
        .ignoresSafeArea(
            .container,
            edges: [.top, .bottom]
        )
        .toolbar(.hidden, for: .navigationBar)
        .overlay {
            panelEdgeSwipeOverlay
        }
        .overlay(alignment: .top) {
            if isHomeReelActive {
                HomePanelSwitcher(
                    selection: $selectedPanel
                )
                .padding(
                    .top,
                    topSafeAreaInset + 10
                )
            }
        }
        .overlay {
            mapVideoPreviewOverlay
        }
        .task { // body 안에서 직접 API를 호출하지 않고, View가 화면에 등장하는 생명주기에 맞는 .task에서 호출
            async let tourism: Void = viewModel.loadInitialTourisms()
            async let reels: Void = viewModel.loadInitialReels()

            _ = await (tourism, reels)
        }
        .task(
            id: MapRouteLoadRequest(
                panel: selectedPanel,
                reelID: activeReelID
            )
        ) {
            guard selectedPanel == .map else {
                return
            }

            viewModel.pausePlayback()

            guard let activeReelID else {
                mapPanelViewModel.clear()
                return
            }

            await mapPanelViewModel.loadRoute(
                for: activeReelID
            )
        }

        .navigationDestination(isPresented: $showsCurrentLocationSearch) {
            MapSearchView(query: "서울 성수동")
        }
        .sheet(isPresented: $showsLocationPermissionPrompt) {
            LocationPermissionPromptSheet(
                onAllow: {
                    sessionStore.allowLocationPermission()
                    showsCurrentLocationSearch = true
                },
                onSkip: {
                    sessionStore.skipLocationPermission()
                }
            )
            .presentationDetents([.height(384)])
            .presentationDragIndicator(.hidden)
        }
        .alert(
            "작업을 완료하지 못했어요",
            isPresented: reelInteractionErrorPresented
        ) {
            switch viewModel.interactionError?.recoveryAction {
            case .retry:
                Button("다시 시도") {
                    Task {
                        await viewModel.retryLastInteraction()
                    }
                }

            case .signIn:
                Button("다시 로그인", action: performLogout)

            case .some(.none), nil:
                EmptyView()
            }

            Button("확인", role: .cancel) {
                viewModel.dismissInteractionError()
            }
        } message: {
            Text(viewModel.interactionError?.message ?? "")
        }
    }

    @ViewBuilder
    private var mapVideoPreviewOverlay: some View {
        if let request = videoPreviewRequest {
            ZStack {
                Color.black.opacity(0.46)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissVideoPreview()
                    }

                HomeMapVideoPreview(
                    player: viewModel.player(for: request.logID),
                    isLoading: viewModel.isLoadingPlayback(
                        for: request.logID
                    ),
                    hasPlaybackFailed: viewModel.hasPlaybackFailed(
                        for: request.logID
                    ),
                    playbackProgress: viewModel.playbackProgress(
                        for: request.logID
                    ),
                    isPlaying: viewModel.isPlaying(
                        reelID: request.logID
                    ),
                    onPlayToggle: {
                        Task {
                            await viewModel.togglePlayback(
                                for: request.logID
                            )
                        }
                    },
                    onSeek: { progress in
                        viewModel.seekPlayback(
                            to: progress,
                            for: request.logID
                        )
                    },
                    onRetry: {
                        Task {
                            await viewModel.playReel(
                                withID: request.logID,
                                from: request.startTimeMillis
                            )
                        }
                    }
                )
                .frame(maxWidth: 252)
                .padding(.horizontal, 48)
            }
            .accessibilityAddTraits(.isModal)
        }
    }

    private func dismissVideoPreview() {
        viewModel.stopPlayback()
        videoPreviewRequest = nil
    }

    private func playRoutePoint(
        _ request: HomeMapRoutePlaybackRequest
    ) {
        guard request.logID == activeReelID else {
            return
        }

        videoPreviewRequest = request

        Task {
            await viewModel.playReel(
                withID: request.logID,
                from: request.startTimeMillis
            )
        }
    }

    private var reelsPanel: some View {
        GeometryReader { proxy in
            // PageTabView가 자식 페이지를 아래로 배치한 실제 거리만큼 렌더링 위치를 되돌림
            let pageTopOffset = max(
                proxy.frame(
                    in: .named(Self.viewportCoordinateSpace)
                ).minY,
                0
            )

            ScrollViewReader { scrollProxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        homeIntro
                            .padding(
                                .top,
                                topSafeAreaInset + 12 + pageTopOffset
                            )
                            .id("home-intro")

                        homeReelPages(
                            viewportSize: proxy.size
                        )
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(
                    id: $homeScrollPosition,
                    anchor: .top
                )
                .scrollTargetBehavior(
                    .viewAligned(limitBehavior: .always)
                )
                .refreshable {
                    await viewModel.refreshHome()
                }
                .onChange(of: homeScrollPosition) {
                    previousPosition,
                    newPosition in

                    guard
                        previousPosition == "home-intro",
                        let newPosition,
                        newPosition != "home-intro"
                    else {
                        return
                    }

                    withAnimation(
                        reduceMotion
                            ? nil
                            : .easeOut(duration: 0.24)
                    ) {
                        scrollProxy.scrollTo(
                            newPosition,
                            anchor: .top
                        )
                    }
                }
            }
            .offset(y: -pageTopOffset)
        }
        .background(
            isHomeReelActive
                ? Color.black
                : Color(uiColor: .systemBackground)
        )
        .maplogReelTabBarStyle(isHomeReelActive)
        .task(id: homeScrollPosition) {
            guard let reelID = reelID(
                from: homeScrollPosition
            ) else {
                viewModel.stopPlayback()
                return
            }

            await viewModel.activatePlayback(for: reelID)
        }
        .onDisappear {
            viewModel.stopPlayback()
        }
    }

    @ViewBuilder
    private var homeIntro: some View {
        if reduceMotion {
            homeIntroContent
        } else {
            homeIntroContent
                .scrollTransition(.interactive, axis: .vertical) { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0.12)
                }
        }
    }

    @ViewBuilder
    private func homeReelPage(
        for reel: HomeReelViewData
    ) -> some View {
        if reduceMotion {
            HomeReelPage(
                reel: reel,
                thumbnailData: viewModel.thumbnailData(for: reel.id),
                isLoadingThumbnail: viewModel.isLoadingThumbnail(for: reel.id),
                player: viewModel.player(for: reel.id),
                isLoadingPlayback: viewModel.isLoadingPlayback(for: reel.id),
                playbackProgress: viewModel.playbackProgress(for: reel.id),
                onPlayToggle: {
                    Task {
                        await viewModel.togglePlayback(for: reel.id)
                    }
                },
                onSeek: { progress in
                    viewModel.seekPlayback(to: progress, for: reel.id)
                },
                isPlaying: viewModel.isPlaying(reelID: reel.id),
                isUpdatingLike: viewModel.isUpdatingLike(for: reel.id),
                isUpdatingSave: viewModel.isUpdatingSave(for: reel.id),
                onToggleLike: {
                    Task {
                        await viewModel.toggleLike(for: reel.id)
                    }
                },
                onToggleSave: {
                    Task {
                        await viewModel.toggleSaved(for: reel.id)
                    }
                }
            )
            .task(id: reel.id) {
                await viewModel.loadThumbnail(for: reel.id)
            }
        } else {
            HomeReelPage(
                reel: reel,
                thumbnailData: viewModel.thumbnailData(for: reel.id),
                isLoadingThumbnail: viewModel.isLoadingThumbnail(for: reel.id),
                player: viewModel.player(for: reel.id),
                isLoadingPlayback: viewModel.isLoadingPlayback(for: reel.id),
                playbackProgress: viewModel.playbackProgress(for: reel.id),
                onPlayToggle: {
                    Task {
                        await viewModel.togglePlayback(for: reel.id)
                    }
                },
                onSeek: { progress in
                    viewModel.seekPlayback(to: progress, for: reel.id)
                },
                isPlaying: viewModel.isPlaying(reelID: reel.id),
                isUpdatingLike: viewModel.isUpdatingLike(for: reel.id),
                isUpdatingSave: viewModel.isUpdatingSave(for: reel.id),
                onToggleLike: {
                    Task {
                        await viewModel.toggleLike(for: reel.id)
                    }
                },
                onToggleSave: {
                    Task {
                        await viewModel.toggleSaved(for: reel.id)
                    }
                }
            )
            .task(id: reel.id) {
                await viewModel.loadThumbnail(for: reel.id)
            }
                .scrollTransition(.interactive, axis: .vertical) {
                    content,
                    phase in

                    content.opacity(
                        phase.isIdentity ? 1 : 0.18
                    )
                }
        }
    }

    @ViewBuilder
    private func homeReelPages(
        viewportSize: CGSize
    ) -> some View {
        switch viewModel.reelState {
        case .idle, .loading:
            HomeReelStatusPage(
                icon: "play.rectangle",
                title: "로그를 불러오는 중이에요",
                message: nil,
                actionTitle: nil,
                action: nil
            )
            .frame(
                width: viewportSize.width,
                height: viewportSize.height
            )
            .id("reel-loading")

        case let .content(reels):
            ForEach(reels) { reel in
                homeReelPage(for: reel)
                    .frame(
                        width: viewportSize.width,
                        height: viewportSize.height
                )
                .id("reel-\(reel.id)")
            }

        case .empty:
            HomeReelStatusPage(
                icon: "video.slash",
                title: "아직 발행된 로그가 없어요",
                message: "첫 번째 영상을 기록해 보세요.",
                actionTitle: nil,
                action: nil
            )
            .frame(
                width: viewportSize.width,
                height: viewportSize.height
            )
            .id("reel-empty")

        case let .failed(presentation):
            HomeReelStatusPage(
                icon: "exclamationmark.triangle",
                title: "로그를 불러오지 못했어요",
                message: presentation.message,
                actionTitle: actionTitle(for: presentation),
                action: {
                    handleReelErrorAction(
                        presentation.recoveryAction
                    )
                }
            )
            .frame(
                width: viewportSize.width,
                height: viewportSize.height
            )
            .id("reel-failed")
        }
    }

    private func actionTitle(
        for presentation: ErrorPresentation
    ) -> String? {
        switch presentation.recoveryAction {
        case .retry:
            return "다시 시도"

        case .signIn:
            return "다시 로그인"

        case .none:
            return nil
        }
    }

    private func handleReelErrorAction(
        _ action: ErrorPresentation.RecoveryAction
    ) {
        switch action {
        case .retry:
            Task {
                await viewModel.retryInitialReels()
            }

        case .signIn:
            performLogout()

        case .none:
            break
        }
    }


    private var homeIntroContent: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xLarge) {
            homeHeader
                .padding(.horizontal, MaplogSpacing.page)
            weekendTourismCarousel
        }
        .padding(.bottom, 24)
    }

    private var homeHeader: some View {
        HStack(spacing: MaplogSpacing.small) {
            Text("Maplog")
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            Spacer()

            NavigationLink {
                SearchView()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("검색")
        }
    }

    private func openCurrentLocation() {
        if sessionStore.locationPermissionStatus.isAllowed {
            showsCurrentLocationSearch = true
        } else {
            showsLocationPermissionPrompt = true
        }
    }

    private var greetingHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 7) {
                Button {
                    if !sessionStore.locationPermissionStatus.isAllowed {
                        showsLocationPermissionPrompt = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(sessionStore.locationPermissionStatus.isAllowed ? "서울 성수동" : "위치 설정 필요")
                            .font(.system(size: 17, weight: .semibold))
                        Image(systemName: sessionStore.locationPermissionStatus.isAllowed ? "chevron.down" : "location.slash.fill")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(sessionStore.locationPermissionStatus.isAllowed ? Color.maplogMuted : Color.maplogOlive)
                }
                .buttonStyle(.plain)

                Text("좋은 저녁이에요!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
            }
            Spacer()
            NavigationLink {
                NotificationsView()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.maplogPrimary)
                        .frame(width: 46, height: 46)
                        .contentShape(Rectangle())
                    Circle()
                        .fill(.red)
                        .frame(width: 9, height: 9)
                        .offset(x: -9, y: 9)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var weekendTourismCarousel: some View {
        VStack(alignment: .leading, spacing: 14) {
            MaplogSectionHeader(
                "지금 떠나기 좋은 즐길 거리",
//                systemImage: "sparkles",
//                subtitle: "주말 여행을 채워줄 행사"
            ) {
                Button {
                   onShowAllTourisms()
                } label: {
                    HStack(spacing: 4) {
                        Text("전체보기")
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, MaplogSpacing.page)

            tourismSectionContent
            .contentMargins(.horizontal, MaplogSpacing.page, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
        }
    }

    // loading / content / empty / failed 중 무엇을 보일지 결정 (상태 판단과 관광 카드 레이아웃을 분리)
    @ViewBuilder
    private var tourismSectionContent: some View{
        switch viewModel.tourismState {
        case .idle, .loading:
            ProgressView("축제 정보를 불러오는 중이에요")
                .frame(maxWidth: .infinity, minHeight: 172)
                .padding(.horizontal, MaplogSpacing.page)
        case .content(let cards):

            tourismCards(cards)
        case .empty:
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Text("현재 포시할 축제가 없어요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 172)
            .padding(.horizontal, MaplogSpacing.page)

        case .failed(let presentation):
            VStack(spacing: 10) {
                Text(presentation.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                switch presentation.recoveryAction {
                case .retry:
                    Button("다시 시도") {
                        Task {
                            await viewModel.retryInitialTourisms()
                        }
                    }
                    .buttonStyle(.bordered)
                case .signIn:
                    Button("다시 로그인") {
                            performLogout()
                        }
                        .buttonStyle(.bordered)
                case .none:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 172)
            .padding(.horizontal, MaplogSpacing.page)
        }
    }

    // 관광 카드 목록 UI를 만들어 주는 보조 함수(실제 반환값은 ScrollView, LazyHStack, ForEach 등이 조합된 아주 긴 타입인데, 그걸 전부 쓰지 않도록 Swift가 some View로 감춰줌)
    // content일 때 카드들을 어떤 모양으로 그릴지 담당
    private func tourismCards(_ cards: [HomeTourismCardViewData]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 14) {
                ForEach(cards) { card in
                    Button {
                        onShowTourismDetail(card.id)
                    } label: {
                        HomeTourismCarouselCard(card: card)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("관광 상세 정보 보기")
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, MaplogSpacing.page, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
    }

    private var weekendRecommendation: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Text("이번 주말, 여기 어때요?")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.maplogInk)

            ZStack(alignment: .topTrailing) {
                NavigationLink {
                    FeaturedEventDetailView(event: spotlightEvent)
                } label: {
                    HomeWeekendCard(event: spotlightEvent)
                }
                .buttonStyle(.plain)

                Button {
                    toggleSpotlightEventSaved()
                } label: {
                    Image(systemName: sessionStore.hasSavedEvent(spotlightEvent) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.78))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(MaplogSpacing.medium)
            }
        }
    }

//    @ViewBuilder
//    private func homeMaplogPage(for post: VlogPost) -> some View {
//        if reduceMotion {
//            HomeMaplogClipPager(
//                post: post,
//                onNext: {
//                    showNextHomePost(after: post)
//                },
//                onReturnHome: returnToHomeIntro
//            )
//        } else {
//            HomeMaplogClipPager(
//                post: post,
//                onNext: {
//                    showNextHomePost(after: post)
//                },
//                onReturnHome: returnToHomeIntro
//            )
//            .scrollTransition(.interactive, axis: .vertical) { content, phase in
//                content.opacity(phase.isIdentity ? 1 : 0.18)
//            }
//        }
//    }

    private func returnToHomeIntro() {
        guard homeScrollPosition != "home-intro" else { return }

        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
            homeScrollPosition = "home-intro"
        }
    }

//    private func showNextHomePost(after post: VlogPost) {
//        guard let currentIndex = homePosts.firstIndex(where: { $0.id == post.id }) else {
//            return
//        }
//
//        let nextIndex = (currentIndex + 1) % homePosts.count
//        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.32)) {
//            homeScrollPosition = homePosts[nextIndex].id
//        }
//    }

    private func toggleSpotlightEventSaved() {
        if sessionStore.hasSavedEvent(spotlightEvent) {
            sessionStore.removeSavedEvent(spotlightEvent)
        } else {
            sessionStore.saveEvent(spotlightEvent)
        }
    }

    private struct HomeReelStatusPage: View {
        let icon: String
        let title: String
        let message: String?
        let actionTitle: String?
        let action: (() -> Void)?

        var body: some View {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.maplogLime)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                }

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderedProminent)
                        .tint(Color.maplogLime)
                        .foregroundStyle(Color.maplogInk)
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
    }


}

private struct HomeTourismCarouselCard: View {
    let card: HomeTourismCardViewData

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            tourismThumbnail
                .frame(width: 264, height: 172)
                .clipped()

            LinearGradient(
                colors: [.black.opacity(0.04), .clear, .black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 7) {
                Text("축제")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 26)
                    .background(Color.maplogLime, in: Capsule())

                Spacer()

                Text(card.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Label(card.locationText, systemImage: "mappin.and.ellipse")
                        .lineLimit(1)

                    Label(card.periodText, systemImage: "calendar")
                        .lineLimit(1)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.84))
            }
            .padding(14)
        }
        .frame(width: 264, height: 172)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            if let dDayText = card.dDayText {
                Text(dDayText)
                    .font(MaplogFont.callout.weight(.bold))
                    .foregroundStyle(.white)
                    .shadow(
                        color: .black.opacity(0.65),
                        radius: 2,
                        x: 0,
                        y: 1
                    )
                    .padding(.top, MaplogSpacing.medium)
                    .padding(.trailing, MaplogSpacing.medium)
            }
        }
        .shadow(color: .black.opacity(0.09), radius: 10, x: 0, y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(card.title), \(card.locationText), \(card.periodText)"
        )
    }


//    축제 목록 API 성공”과 별개로 각 썸네일을 내려받아. 즉 목록은 먼저 카드로 나타나고, 이미지가 조금 뒤에 표시되는 것은 자연스러운 동작
//    다른 View들을 SwiftUI가 하나의 화면으로 조립할 수 있게 해줌
    @ViewBuilder
    private var tourismThumbnail: some View {
        if let thumbnailURL = card.thumbnailURL {
            AsyncImage(url: thumbnailURL) { phase in
                switch phase {
                case .empty:
                    thumbnailPlaceholder
                        .overlay {
                            ProgressView()
                                .tint(.secondary)
                        }
                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()

                                case .failure:
                                    thumbnailPlaceholder

                @unknown default:
                    thumbnailPlaceholder
                }
            }
        } else {
            thumbnailPlaceholder
        }
    }

    private var thumbnailPlaceholder: some View {
        Color(uiColor: .secondarySystemFill)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
    }
}



private struct HomeWeekendCard: View {
    let event: FeaturedEvent
    @ScaledMetric(relativeTo: .body) private var heroHeight: CGFloat = 410

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image("home_gwanghwamun_photo")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: min(heroHeight, 500))
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.xLarge, style: .continuous))
                .overlay {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.24), .black.opacity(0.88)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.xLarge, style: .continuous))
                }

            VStack(alignment: .leading, spacing: 11) {
                Text("오늘 진행 중")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, MaplogSpacing.small)
                    .frame(height: 25)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())

                Spacer()

                Text("서울라이트 광화문")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text("전통과 현대가 만나는 빛의 축제. 이번 주말까지만 진행되는 특별한 야경을 놓치지 마세요.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineSpacing(4)
                    .lineLimit(3)

                HStack(spacing: MaplogSpacing.xSmall) {
                    Label("4.9", systemImage: "star.fill")
                        .foregroundStyle(Color.maplogLime)
                    Text("•")
                        .foregroundStyle(.white.opacity(0.5))
                    Text("서울 종로구")
                        .foregroundStyle(.white.opacity(0.86))
                }
                .font(.subheadline.weight(.semibold))
            }
            .padding(18)
        }
        .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 10)
    }
}

private struct HomeMaplogClipPager: View {
    let post: VlogPost
    let onNext: () -> Void
    let onReturnHome: () -> Void
    @State private var selectedPage = 0

    private var trip: MaplogTrip {
        MockMaplogData.routeTrip(for: post)
    }

    var body: some View {
        GeometryReader { proxy in
            TabView(selection: $selectedPage) {
                HomeMaplogClipCard(
                    post: post,
                    onNext: onNext,
                    onReturnHome: onReturnHome
                )
                    .tag(0)

                MaplogReelRoutePage(post: post, trip: trip)
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(Color.black)
            .overlay(alignment: .top) {
                MaplogReelPageCue(selectedPage: selectedPage)
                    .padding(.top, max(proxy.safeAreaInsets.top, MaplogSpacing.reelTopClearance) + MaplogSpacing.xxSmall)
            }
            .accessibilityHint("좌우로 넘기면 영상과 전체 루트를 전환합니다")
        }
    }
}

private struct HomeMaplogClipCard: View {
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    let post: VlogPost
    let onNext: () -> Void
    let onReturnHome: () -> Void
    @State private var showsComments = false
    @State private var showsShareSheet = false
    @State private var showsSaveCollections = false
    @State private var shareSheetDetent: PresentationDetent = .medium
    @State private var actionToast: String?
    @State private var isCaptionExpanded = false
    @State private var isCaptionTruncated = false

    private var trip: MaplogTrip {
        MockMaplogData.routeTrip(for: post)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                VlogPostImageView(post: post)
                    .frame(width: proxy.size.width, height: proxy.size.height)

                LinearGradient(
                    colors: [.black.opacity(0.18), .clear, .black.opacity(0.86)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Color.clear
                    .frame(
                        width: max(proxy.size.width * 0.64, 200),
                        height: max(proxy.size.height * 0.5, 260)
                    )
                    .contentShape(Rectangle())
                    .position(x: proxy.size.width * 0.38, y: proxy.size.height * 0.39)
                    .onTapGesture(perform: onReturnHome)
                    .accessibilityElement()
                    .accessibilityLabel("홈 피드 처음으로")
                    .accessibilityHint("탭하면 릴스를 닫고 홈 화면 처음으로 돌아갑니다.")
                    .accessibilityAddTraits(.isButton)

                Color.clear
                    .frame(width: max(proxy.size.width * 0.22, 72), height: max(proxy.size.height * 0.24, 132))
                    .contentShape(Rectangle())
                    .position(x: proxy.size.width * 0.87, y: proxy.size.height * 0.40)
                    .onTapGesture(perform: onNext)
                    .accessibilityElement()
                    .accessibilityLabel("다음 Maplog")
                    .accessibilityAddTraits(.isButton)

                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 24)

                    HStack(alignment: .bottom, spacing: MaplogSpacing.small) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: MaplogSpacing.xSmall) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.title2)
                                Text(post.author)
                                    .font(.headline)
                            }

                            Text(fullCaptionText)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.84))
                                .lineLimit(isCaptionExpanded ? nil : 2)
                                .background(captionMeasurement)
                                .onPreferenceChange(CaptionTextMeasurementPreferenceKey.self) { measurements in
                                    updateCaptionTruncation(with: measurements)
                                }

                            if shouldShowCaptionExpansion {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isCaptionExpanded.toggle()
                                    }
                                } label: {
                                    Text(isCaptionExpanded ? "접기" : "더보기")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.maplogLime)
                                        .frame(minHeight: 28)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(isCaptionExpanded ? "본문 접기" : "본문 더보기")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        actionRail
                    }
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, MaplogSpacing.page)
                .padding(.top, max(proxy.safeAreaInsets.top, MaplogSpacing.reelTopClearance) + MaplogSpacing.small)
                .padding(.bottom, proxy.safeAreaInsets.bottom + MaplogSpacing.reelTabBarClearance)

                if let actionToast {
                    Text(actionToast)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(.ultraThinMaterial, in: Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, proxy.safeAreaInsets.bottom + MaplogSpacing.reelTabBarClearance + 64)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .sheet(isPresented: $showsComments) {
            VlogCommentsSheet(post: post)
                .presentationDetents([.fraction(0.62), .large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showsShareSheet) {
            MaplogActivityShareSheet(post: post) {
                showsShareSheet = false
            }
            .presentationDetents([.medium, .large], selection: $shareSheetDetent)
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsSaveCollections) {
            ReelSaveCollectionSheet(trip: trip)
                .presentationDetents([.fraction(0.66), .large])
                .presentationDragIndicator(.visible)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(post.author)의 \(post.title), \(post.place.name) 경로, \(trip.duration)")
    }

    private var actionRail: some View {
        VStack(spacing: MaplogSpacing.small) {
            actionMetric(
                systemImage: sessionStore.hasLikedVlogPost(post) ? "heart.fill" : "heart",
                text: likeCountText,
                tint: sessionStore.hasLikedVlogPost(post) ? Color.maplogLime : .white,
                accessibilityLabel: sessionStore.hasLikedVlogPost(post) ? "좋아요 취소" : "좋아요"
            ) {
                toggleLike()
            }
            actionMetric(systemImage: "message.fill", text: commentCountText, accessibilityLabel: "댓글 보기") {
                showsComments = true
            }
            actionMetric(systemImage: "square.and.arrow.up", text: "공유", accessibilityLabel: "공유") {
                shareSheetDetent = .medium
                showsShareSheet = true
            }
            actionMetric(
                systemImage: sessionStore.hasSavedRoute(trip) ? "bookmark.fill" : "bookmark",
                text: "저장",
                tint: sessionStore.hasSavedRoute(trip) ? Color.maplogLime : .white,
                accessibilityLabel: sessionStore.hasSavedRoute(trip) ? "저장한 컬렉션 관리" : "저장"
            ) {
                toggleSave()
            }
        }
        .frame(width: 44)
        .shadow(color: .black.opacity(0.34), radius: 5, y: 2)
    }

    private var shouldShowCaptionExpansion: Bool {
        isCaptionTruncated
    }

    private var captionMeasurement: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                captionMeasurementText(
                    lineLimit: 2,
                    kind: .collapsed,
                    width: proxy.size.width
                )

                captionMeasurementText(
                    lineLimit: nil,
                    kind: .full,
                    width: proxy.size.width
                )
            }
            .hidden()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func captionMeasurementText(
        lineLimit: Int?,
        kind: CaptionTextMeasurementKind,
        width: CGFloat
    ) -> some View {
        Text(fullCaptionText)
            .font(.subheadline)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: width, alignment: .leading)
            .background {
                GeometryReader { textProxy in
                    Color.clear.preference(
                        key: CaptionTextMeasurementPreferenceKey.self,
                        value: [CaptionTextMeasurement(kind: kind, height: textProxy.size.height)]
                    )
                }
            }
    }

    private func updateCaptionTruncation(with measurements: [CaptionTextMeasurement]) {
        guard
            let collapsedHeight = measurements
                .filter({ $0.kind == .collapsed })
                .map(\.height)
                .max(),
            let fullHeight = measurements
                .filter({ $0.kind == .full })
                .map(\.height)
                .max(),
            collapsedHeight > 0,
            fullHeight > 0
        else {
            return
        }

        let needsExpansion = fullHeight > collapsedHeight + 0.5
        guard needsExpansion != isCaptionTruncated else { return }

        isCaptionTruncated = needsExpansion
        if !needsExpansion {
            isCaptionExpanded = false
        }
    }

    private var fullCaptionText: String {
        let hashtags = post.hashtags.map { "#\($0)" }.joined(separator: " ")
        return hashtags.isEmpty ? post.caption : "\(post.caption) \(hashtags)"
    }

    /// 장소 카드 UI는 다음 릴스 확장 시 다시 사용할 수 있도록 유지합니다.
    private var routeAction: some View {
        NavigationLink {
            PopularMaplogDetailView(post: post, trip: trip)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "mappin.circle.fill")
                Text(post.place.name)
                Spacer(minLength: 8)
                Text("루트 보기")
                Image(systemName: "chevron.right")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 13)
            .frame(minHeight: 54)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Maplog 경로 상세를 엽니다")
    }

    private func actionMetric(
        systemImage: String,
        text: String,
        tint: Color = .white,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(tint)
                Text(text)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 44)
            .frame(minHeight: 45)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(text)
    }

    private var commentCountText: String {
        let baseCount = Int(post.comments.filter(\.isNumber)) ?? 0
        let totalCount = baseCount + sessionStore.vlogCommentCount(for: post.id)
        return compactCountText(totalCount)
    }

    private var likeCountText: String {
        guard let baseCount = compactCountValue(from: post.likes) else {
            return post.likes
        }

        let wasInitiallyLiked = sessionStore.wasInitiallyLikedVlogPost(post)
        let isLiked = sessionStore.hasLikedVlogPost(post)
        let adjustment = isLiked == wasInitiallyLiked ? 0 : (isLiked ? 1 : -1)
        return compactCountText(max(baseCount + adjustment, 0))
    }

    private func toggleLike() {
        withAnimation(.easeOut(duration: 0.18)) {
            if sessionStore.hasLikedVlogPost(post) {
                sessionStore.unlikeVlogPost(post)
            } else {
                sessionStore.likeVlogPost(post)
            }
        }
    }

    private func toggleSave() {
        showsSaveCollections = true
    }

    private func compactCountValue(from text: String) -> Int? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.hasSuffix("k") {
            guard let value = Double(String(normalized.dropLast())) else { return nil }
            return Int((value * 1_000).rounded())
        }
        return Int(normalized.filter(\.isNumber))
    }

    private func compactCountText(_ count: Int) -> String {
        guard count >= 1_000 else { return "\(count)" }
        let formatted = String(format: "%.1f", Double(count) / 1_000)
        return "\(formatted.replacingOccurrences(of: ".0", with: ""))k"
    }

    private func showToast(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            actionToast = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                if actionToast == message {
                    actionToast = nil
                }
            }
        }
    }
}

private enum CaptionTextMeasurementKind: Equatable {
    case collapsed
    case full
}

private struct CaptionTextMeasurement: Equatable {
    let kind: CaptionTextMeasurementKind
    let height: CGFloat
}

private struct CaptionTextMeasurementPreferenceKey: PreferenceKey {
    static var defaultValue: [CaptionTextMeasurement] = []

    static func reduce(value: inout [CaptionTextMeasurement], nextValue: () -> [CaptionTextMeasurement]) {
        value.append(contentsOf: nextValue())
    }
}

/// 릴스에서 저장을 누른 직후, 전체 보관함과 개인 컬렉션을 함께 정리하는 시트입니다.
/// 새 컬렉션을 만들면 현재 보고 있는 루트를 바로 그 안에 담습니다.
private struct ReelSaveCollectionSheet: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: MaplogSessionStore

    let trip: MaplogTrip

    @State private var isCreatingCollection = false
    @State private var collectionName = ""
    @State private var selectedCoverStyle: PhotoStyle = .cafe
    @State private var validationMessage: String?
    @State private var selectionFeedback = 0
    @State private var successFeedback = 0
    @FocusState private var isCollectionNameFocused: Bool

    private let coverOptions: [PhotoStyle] = [.cafe, .city, .night, .ocean]

    var body: some View {
        Group {
            if isCreatingCollection {
                createCollectionContent
            } else {
                collectionPickerContent
            }
        }
        .background(Color.maplogSurface)
        .animation(
            reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.9),
            value: isCreatingCollection
        )
        .sensoryFeedback(.selection, trigger: selectionFeedback)
        .sensoryFeedback(.success, trigger: successFeedback)
        .onAppear {
            if sessionStore.saveRoute(trip) {
                successFeedback += 1
            }
        }
    }

    private var collectionPickerContent: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MaplogSpacing.xLarge) {
                    VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                        Text("저장할 컬렉션")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.maplogInk)
                        Text("이 루트는 전체 보관함에 저장됐어요. 원하는 컬렉션에도 함께 담아보세요.")
                            .font(.subheadline)
                            .foregroundStyle(Color.maplogMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    savedSummary

                    VStack(alignment: .leading, spacing: MaplogSpacing.small) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("컬렉션")
                                .font(.headline)
                                .foregroundStyle(Color.maplogInk)

                            Spacer()

                            Button(action: beginCreatingCollection) {
                                Label("새 컬렉션", systemImage: "plus")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.maplogOlive)
                                    .frame(minHeight: MaplogSize.minimumTapTarget)
                            }
                            .buttonStyle(ReelSavePressStyle())
                            .accessibilityHint("새 컬렉션을 만들고 현재 루트를 바로 저장합니다")
                        }

                        ForEach(sessionStore.routeCollections) { collection in
                            collectionRow(collection)
                        }
                    }
                }
                .padding(.horizontal, MaplogSpacing.page)
                .padding(.top, MaplogSpacing.medium)
                .padding(.bottom, MaplogSpacing.large)
            }

            Button {
                dismiss()
            } label: {
                Text("완료")
                    .font(.headline)
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(Color.maplogLime, in: Capsule())
            }
            .buttonStyle(ReelSavePressStyle())
            .padding(.horizontal, MaplogSpacing.page)
            .padding(.vertical, MaplogSpacing.small)
            .background(Color.maplogSurface)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.maplogLine.opacity(0.72))
                    .frame(height: 1)
            }
        }
    }

    private var savedSummary: some View {
        HStack(spacing: MaplogSpacing.small) {
            TravelImageView(
                style: trip.coverStyle,
                height: 64,
                cornerRadius: MaplogRadius.medium,
                showsSymbol: false
            )
            .frame(width: 64)

            VStack(alignment: .leading, spacing: MaplogSpacing.xxxSmall) {
                Text("저장됨")
                    .font(.headline)
                    .foregroundStyle(Color.maplogInk)
                Text(trip.title)
                    .font(.subheadline)
                    .foregroundStyle(Color.maplogMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "bookmark.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.maplogOlive)
                .accessibilityHidden(true)
        }
        .padding(MaplogSpacing.small)
        .background(Color.maplogCanvas, in: RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("저장됨, \(trip.title)")
    }

    private func collectionRow(_ collection: MaplogRouteCollection) -> some View {
        let isIncluded = sessionStore.isRoute(trip, in: collection)
        let routeCount = sessionStore.routes(in: collection).count

        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.86)) {
                if isIncluded {
                    _ = sessionStore.removeRoute(trip, from: collection.id)
                } else {
                    _ = sessionStore.addRoute(trip, to: collection.id)
                }
            }
            selectionFeedback += 1
        } label: {
            HStack(spacing: MaplogSpacing.small) {
                TravelImageView(
                    style: collection.coverStyle,
                    height: 56,
                    cornerRadius: MaplogRadius.medium,
                    showsSymbol: false
                )
                .frame(width: 56)

                VStack(alignment: .leading, spacing: MaplogSpacing.xxxSmall) {
                    Text(collection.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.maplogInk)
                        .lineLimit(1)
                    Text("\(routeCount)개 루트")
                        .font(.caption)
                        .foregroundStyle(Color.maplogMuted)
                }

                Spacer(minLength: 8)

                Image(systemName: isIncluded ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(isIncluded ? Color.maplogOlive : Color.maplogMuted)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
            }
            .padding(MaplogSpacing.xSmall)
            .frame(minHeight: 72)
            .background(
                isIncluded ? Color.maplogLime.opacity(0.16) : Color.maplogSurface,
                in: RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous)
            )
        }
        .buttonStyle(ReelSavePressStyle())
        .accessibilityLabel(collection.title)
        .accessibilityValue(isIncluded ? "이 컬렉션에 저장됨" : "이 컬렉션에 저장되지 않음")
        .accessibilityHint(isIncluded ? "두 번 탭하면 이 컬렉션에서 제거합니다" : "두 번 탭하면 이 컬렉션에 저장합니다")
    }

    private var createCollectionContent: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    endCreatingCollection()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                }
                .buttonStyle(ReelSavePressStyle())
                .accessibilityLabel("컬렉션 목록으로 돌아가기")

                Spacer()

                Text("새 컬렉션")
                    .font(.headline)
                    .foregroundStyle(Color.maplogInk)

                Spacer()

                Color.clear
                    .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
            }
            .padding(.horizontal, MaplogSpacing.xSmall)
            .padding(.top, MaplogSpacing.xxSmall)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MaplogSpacing.xLarge) {
                    VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                        Text("나만의 저장 폴더 만들기")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.maplogInk)
                        Text("만드는 즉시 지금 보고 있는 루트가 이 컬렉션에 저장됩니다.")
                            .font(.subheadline)
                            .foregroundStyle(Color.maplogMuted)
                    }

                    VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                        Text("컬렉션 이름")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.maplogInk)

                        TextField("예: 가을 서울 산책", text: $collectionName)
                            .font(.body)
                            .foregroundStyle(Color.maplogInk)
                            .focused($isCollectionNameFocused)
                            .submitLabel(.done)
                            .onSubmit(createCollection)
                            .padding(.horizontal, MaplogSpacing.small)
                            .frame(minHeight: 52)
                            .background(Color.maplogCanvas, in: RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
                            .overlay {
                                if validationMessage != nil {
                                    RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous)
                                        .stroke(Color.maplogDanger, lineWidth: 1)
                                }
                            }

                        if let validationMessage {
                            Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.maplogDanger)
                        }
                    }

                    VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                        Text("대표 이미지")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.maplogInk)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: MaplogSpacing.xSmall), count: 2),
                            spacing: MaplogSpacing.xSmall
                        ) {
                            ForEach(coverOptions, id: \.self) { style in
                                coverStyleButton(style)
                            }
                        }
                    }
                }
                .padding(.horizontal, MaplogSpacing.page)
                .padding(.top, MaplogSpacing.medium)
                .padding(.bottom, MaplogSpacing.large)
            }

            Button(action: createCollection) {
                Label("만들고 저장하기", systemImage: "bookmark.fill")
                    .font(.headline)
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(
                        canCreateCollection ? Color.maplogLime : Color.maplogLine,
                        in: Capsule()
                    )
            }
            .buttonStyle(ReelSavePressStyle())
            .disabled(!canCreateCollection)
            .padding(.horizontal, MaplogSpacing.page)
            .padding(.vertical, MaplogSpacing.small)
            .background(Color.maplogSurface)
        }
        .onAppear {
            DispatchQueue.main.async {
                isCollectionNameFocused = true
            }
        }
        .onChange(of: collectionName) {
            validationMessage = nil
        }
    }

    private func coverStyleButton(_ style: PhotoStyle) -> some View {
        let isSelected = selectedCoverStyle == style

        return Button {
            selectedCoverStyle = style
            selectionFeedback += 1
        } label: {
            ZStack(alignment: .bottomLeading) {
                TravelImageView(
                    style: style,
                    height: 92,
                    cornerRadius: MaplogRadius.medium,
                    showsSymbol: false
                )

                LinearGradient(
                    colors: [.clear, .black.opacity(0.54)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Text(coverStyleTitle(for: style))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(MaplogSpacing.xSmall)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.maplogLime)
                        .padding(MaplogSpacing.xSmall)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .accessibilityHidden(true)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous)
                    .stroke(isSelected ? Color.maplogLime : .clear, lineWidth: 3)
            }
        }
        .buttonStyle(ReelSavePressStyle())
        .accessibilityLabel("\(coverStyleTitle(for: style)) 대표 이미지")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var canCreateCollection: Bool {
        !collectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func beginCreatingCollection() {
        collectionName = ""
        validationMessage = nil
        selectedCoverStyle = .cafe
        withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.9)) {
            isCreatingCollection = true
        }
    }

    private func endCreatingCollection() {
        isCollectionNameFocused = false
        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.92)) {
            isCreatingCollection = false
        }
    }

    private func createCollection() {
        guard let collection = sessionStore.createRouteCollection(
            title: collectionName,
            coverStyle: selectedCoverStyle
        ) else {
            validationMessage = "같은 이름의 컬렉션이 있거나 이름이 비어 있어요."
            return
        }

        _ = sessionStore.addRoute(trip, to: collection.id)
        isCollectionNameFocused = false
        successFeedback += 1
        endCreatingCollection()
    }

    private func coverStyleTitle(for style: PhotoStyle) -> String {
        switch style {
        case .cafe: return "카페"
        case .city: return "도시"
        case .night: return "야경"
        case .ocean: return "바다"
        default: return "여행"
        }
    }
}

private struct ReelSavePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
