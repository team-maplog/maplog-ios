import SwiftUI

private enum HomeFestivalCarouselLayout {
    static let cornerRadius: CGFloat = 18
    static let posterCornerRadius: CGFloat = 10
    static let posterHeight: CGFloat = 200
    static let cardSpacing: CGFloat = 12
}

struct HomeView: View {
    private static let viewportCoordinateSpace = "home-viewport"
    private static let panelSwipeEdgeWidth: CGFloat = 28
    private static let panelSwipeMinimumDistance: CGFloat = 56
    /// 홈 미리보기는 전체 릴스보다 하단 내비게이션에 16pt 더 가깝게 둡니다.
    private static let homePreviewMetadataBottomClearance: CGFloat =
        MaplogSpacing.reelTabBarClearance - MaplogSpacing.medium

    private struct FirstReelTopOffsetPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat?

        static func reduce(
            value: inout CGFloat?,
            nextValue: () -> CGFloat?
        ) {
            if let nextValue = nextValue() {
                value = nextValue
            }
        }
    }

    private struct FirstReelMetadataHeightPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = 0

        static func reduce(
            value: inout CGFloat,
            nextValue: () -> CGFloat
        ) {
            value = nextValue()
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.maplogLogout) private var performLogout
    @ObservedObject var viewModel: HomeViewModel // MainTabView가 만든 하나를 받아서 관찰
    @ObservedObject var mapPanelViewModel: HomeMapPanelViewModel
    let logCommentRepository: any LogCommentRepository
    let profileRepository: any ProfileRepository
    let followRepository: any FollowRepository
    let homeSearchRepository: any HomeSearchRepository
    let logReelRepository: any LogReelRepository
    let logMediaRepository: any LogMediaRepository
    let topSafeAreaInset: CGFloat // 전체 화면 높이는 고정하고 홈 콘텐츠만 상태바 아래에서 시작하기 위한 값
    let onShowAllTourisms: () -> Void
    let onShowTourismDetail: (Int64) -> Void
    let onShowLogDetail: (Int64) -> Void
    let onShowNotifications: () -> Void
    /// 작성자 선택만 상위에 알리고, 공개 프로필 화면 생성과 의존성 주입은 Composition Root가 담당한다.
    let onShowAuthorProfile: (HomeReelViewData) -> Void
    let onShowPublicProfile: (FollowUser) -> Void
    /// 홈은 버튼 탭만 알리고, 클립 선택·편집·발행 화면 전환은 상위 화면이 담당한다.
    let onCreateLog: () -> Void

    private enum HomePanel: Int, CaseIterable, Identifiable {
        case reels
        case map
        var id: Int { rawValue }
    }

    private struct MapRouteLoadRequest: Equatable {
        let panel: HomePanel
        let reelID: Int64?
    }

    @State private var homeScrollPosition: String? = "home-intro"
    @State private var selectedPanel: HomePanel = .reels
    @State private var videoPreviewRequest: HomeMapRoutePlaybackRequest?
    @State private var commentsReel: HomeReelViewData?
    @State private var shareReel: HomeReelViewData?
    @State private var saveToastText: String?
    @State private var firstReelTopOffset: CGFloat?
    @State private var homeIntroHeight: CGFloat = 0
    /// 홈 미리보기의 메타데이터는 로그마다 선택 입력이 달라 실제 높이를 따로 기억합니다.
    @State private var reelMetadataHeightByID: [Int64: CGFloat] = [:]

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

    private var firstReel: HomeReelViewData? {
        guard case let .content(reels) = viewModel.reelState else {
            return nil
        }

        return reels.first
    }

    /// 첫 릴스의 실제 화면 위치에서 0...1 진행도를 만들면,
    /// 드래그 중에도 프로필과 모서리 모양이 같은 속도로 변한다.
    private func firstReelRevealProgress(
        viewportHeight: CGFloat
    ) -> CGFloat {
        guard let firstReelTopOffset,
              viewportHeight > 0
        else {
            return 0
        }

        return min(
            max((viewportHeight - firstReelTopOffset) / viewportHeight, 0),
            1
        )
    }

    private func interpolatedValue(
        from source: CGFloat,
        to destination: CGFloat,
        progress: CGFloat
    ) -> CGFloat {
        source + ((destination - source) * progress)
    }

    private struct MorphingReelMetadata: View {
        let reel: HomeReelViewData
        let imageData: Data?
        let contentWidth: CGFloat
        let engagementOpacity: CGFloat
        let isUpdatingLike: Bool
        let onShowAuthorProfile: () -> Void
        let onToggleLike: () -> Void
        let onShowComments: () -> Void

        var body: some View {
            // 이동 목적지는 작성자 행의 시작점이다. 숨긴 액션 레일 높이가 작성자를 아래로 밀지 않게 한다.
            HStack(alignment: .top, spacing: MaplogSpacing.medium) {
                information
                    .frame(
                        width: informationWidth,
                        alignment: .leading
                    )

                VStack(spacing: MaplogSpacing.small) {
                    HomeReelMetric(
                        systemImage: reel.isLikedByViewer ? "heart.fill" : "heart",
                        text: countText(reel.likeCount),
                        tint: reel.isLikedByViewer
                            ? Color.maplogLime
                            : .white,
                        accessibilityLabel: reel.isLikedByViewer
                            ? "좋아요 취소, \(reel.likeCount)개"
                            : "좋아요, \(reel.likeCount)개",
                        isLoading: isUpdatingLike,
                        action: onToggleLike
                    )

                    HomeReelMetric(
                        systemImage: "message.fill",
                        text: countText(reel.commentCount),
                        accessibilityLabel: "댓글 \(reel.commentCount)개",
                        action: onShowComments
                    )
                }
                .frame(width: MaplogSize.minimumTapTarget)
                .opacity(engagementOpacity)
                .allowsHitTesting(engagementOpacity > 0.1)
            }
            .frame(width: contentWidth, alignment: .leading)
        }

        private var informationWidth: CGFloat {
            max(
                0,
                contentWidth
                    - MaplogSpacing.medium
                    - MaplogSize.minimumTapTarget
            )
        }

        private var information: some View {
            VStack(alignment: .leading, spacing: 10) {
                authorProfileButton

                if let caption = nonEmptyText(reel.caption) {
                    Text(caption)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(3)
                }

                if let address = nonEmptyText(reel.address) {
                    HStack(spacing: MaplogSpacing.xxSmall) {
                        MaplogPinGlyphIcon(size: 13)

                        Text(address)
                    }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                        .accessibilityElement(children: .combine)
                }
            }
        }

        private var authorProfileButton: some View {
            Button(action: onShowAuthorProfile) {
                HStack(spacing: 6) {
                    MaplogProfileAvatar(
                        imageData: imageData,
                        nickname: reel.authorName,
                        size: 32,
                        fallbackBackground: .white.opacity(0.22),
                        fallbackForeground: .white,
                        borderColor: .white.opacity(0.64)
                    )

                    Text(reel.authorName)
                        .font(.headline)
                }
                .frame(
                    minWidth: MaplogSize.minimumTapTarget,
                    minHeight: MaplogSize.minimumTapTarget,
                    alignment: .leading
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .accessibilityLabel("\(reel.authorName)의 프로필")
            .accessibilityHint("탭하면 작성자의 공개 프로필을 봅니다")
        }

        private func countText(_ count: Int64) -> String {
            guard count >= 1_000 else {
                return "\(count)"
            }

            let value = Double(count) / 1_000
            let text = String(format: "%.1f", value)

            return "\(text.replacingOccurrences(of: ".0", with: ""))K"
        }

        private func nonEmptyText(_ text: String) -> String? {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
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
                                : Color.maplogMapLightTextSecondary
                        )
                        .frame(width: 42, height: 32)
                        .background(
                            selection == .reels
                                ? Color.maplogLime
                                : Color.white.opacity(0.40),
                            in: Capsule()
                        )
                }

                Button {
                    selection = .map
                } label: {
                    MaplogMapGlyphIcon(size: 18)
                        .foregroundStyle(
                            selection == .map
                                ? Color.maplogInk
                                : Color.maplogMapLightTextSecondary
                        )
                        .frame(width: 42, height: 32)
                        .background(
                            selection == .map
                                ? Color.maplogLime
                                : Color.white.opacity(0.40),
                            in: Capsule()
                        )
                }
            }
            .padding(4)
            .background(
                .white.opacity(0.82),
                in: Capsule()
            )
            .environment(\.colorScheme, .light)
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
        .overlay(alignment: .bottom) {
            if let saveToastText {
                MaplogToast(message: saveToastText)
                    .padding(
                        .bottom,
                        isHomeReelActive
                            ? MaplogSpacing.reelTabBarClearance
                            : MaplogSpacing.xxxLarge
                    )
                    .transition(
                        .move(edge: .bottom).combined(with: .opacity)
                    )
                    .accessibilityAddTraits(.isStaticText)
            }
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

        .sheet(item: $commentsReel) { reel in
            LogCommentsFeatureSheet(
                logID: reel.id,
                commentRepository: logCommentRepository,
                profileRepository: profileRepository,
                followRepository: followRepository,
                onCommentCountChange: { delta in
                    viewModel.adjustCommentCount(
                        for: reel.id,
                        by: delta
                    )
                }
            )
            .presentationDetents([.fraction(0.62), .large])
            .presentationDragIndicator(.hidden)
        }
        .sheet(item: $shareReel) { reel in
            HomeReelShareSheet(reel: reel)
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
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    homeIntro
                        .padding(.top, topSafeAreaInset + 12)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                            homeIntroHeight = $0
                        }
                        .id("home-intro")

                    homeReelPages(viewportSize: proxy.size)
                }
                .scrollTargetLayout()
                // 서로 다른 높이를 섞은 LazyVStack의 추정 길이로 마지막 정지점이 잘리지 않게 한다.
                .frame(
                    height: homeIntroHeight > 0
                        ? homeIntroHeight + CGFloat(reelPageCount) * proxy.size.height
                        : nil,
                    alignment: .top
                )
            }
            .contentMargins(.vertical, 0, for: .scrollContent)
            .scrollPosition(id: $homeScrollPosition, anchor: .top)
            .scrollTargetBehavior(
                HomeReelScrollBehavior(
                    introHeight: homeIntroHeight,
                    pageHeight: proxy.size.height
                )
            )
            .refreshable {
                await viewModel.refreshHome(tourismPolicy: .reload)
            }
            .onPreferenceChange(FirstReelTopOffsetPreferenceKey.self) {
                firstReelTopOffset = $0
            }
        }
        .overlayPreferenceValue(HomeReelAuthorAnchorPreferenceKey.self) {
            anchors in

            GeometryReader { overlayProxy in
                firstReelMetadataOverlay(
                    anchors: anchors,
                    overlayProxy: overlayProxy,
                    viewportSize: overlayProxy.size
                )
            }
            .clipped()
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

    private var reelPageCount: Int {
        if case let .content(reels) = viewModel.reelState {
            return reels.count
        }
        return 1
    }

    @ViewBuilder
    private func firstReelMetadataOverlay(
        anchors: [Int64: Anchor<CGRect>],
        overlayProxy: GeometryProxy,
        viewportSize: CGSize
    ) -> some View {
        if isHomeReelActive,
           let firstReel,
           let authorAnchor = anchors[firstReel.id],
           let firstReelTopOffset,
           HomeReelMetadataLayout.isVisible(
               pageTop: firstReelTopOffset,
               viewportHeight: viewportSize.height
           ) {
            let revealProgress = firstReelRevealProgress(
                viewportHeight: viewportSize.height
            )
            let authorFrame = overlayProxy[authorAnchor]
            let contentWidth = max(
                0,
                viewportSize.width
                    - (MaplogSpacing.page * 2)
            )
            let destinationX = authorFrame.minX
            let sourceX = MaplogSpacing.page
            // 최초 한 프레임에는 예상 높이를 쓰고, 이후에는 실제 렌더링 높이를 사용합니다.
            // 선택 정보가 비어도 블록의 아래쪽은 항상 하단 내비게이션 바로 위에 고정됩니다.
            let sourceMetadataHeight = reelMetadataHeightByID[firstReel.id]
                ?? estimatedMetadataHeight(for: firstReel)
            let sourceY = viewportSize.height
                - Self.homePreviewMetadataBottomClearance
                - sourceMetadataHeight
            // 홈 미리보기의 하트는 릴스와 같은 불투명한 포인트색으로
            // 유지하고, 전체 릴스에 도착한 순간 실제 오른쪽 레일에 넘긴다.
            let engagementOpacity: CGFloat = revealProgress < 1 ? 1 : 0

            MorphingReelMetadata(
                reel: firstReel,
                imageData: viewModel.authorProfileImageData(for: firstReel.id),
                contentWidth: contentWidth,
                engagementOpacity: engagementOpacity,
                isUpdatingLike: viewModel.isUpdatingLike(for: firstReel.id),
                onShowAuthorProfile: {
                    onShowAuthorProfile(firstReel)
                },
                onToggleLike: {
                    Task {
                        await viewModel.toggleLike(for: firstReel.id)
                    }
                },
                onShowComments: {
                    commentsReel = firstReel
                }
            )
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: FirstReelMetadataHeightPreferenceKey.self,
                        value: proxy.size.height
                    )
                }
            }
            .onPreferenceChange(FirstReelMetadataHeightPreferenceKey.self) { height in
                guard height > 0, height != reelMetadataHeightByID[firstReel.id] else {
                    return
                }

                reelMetadataHeightByID[firstReel.id] = height
            }
            .offset(
                x: interpolatedValue(
                    from: sourceX,
                    to: destinationX,
                    progress: revealProgress
                ),
                y: HomeReelMetadataLayout.verticalOffset(
                    sourceY: sourceY,
                    authorY: authorFrame.minY,
                    pageTop: firstReelTopOffset,
                    revealProgress: revealProgress
                )
            )
            .zIndex(2)
        }
    }

    private func estimatedMetadataHeight(
        for reel: HomeReelViewData
    ) -> CGFloat {
        let caption = reel.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = reel.address.trimmingCharacters(in: .whitespacesAndNewlines)
        let captionHeight: CGFloat = caption.isEmpty ? 0 : 54
        let addressHeight: CGFloat = address.isEmpty ? 0 : 16
        let spacingCount = (caption.isEmpty ? 0 : 1) + (address.isEmpty ? 0 : 1)

        return 44 + captionHeight + addressHeight + (CGFloat(spacingCount) * 10)
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
        for reel: HomeReelViewData,
        usesExternalReelInfoOverlay: Bool,
        cornerRadius: CGFloat,
        previewHorizontalInset: CGFloat,
        previewBottomInset: CGFloat
    ) -> some View {
        if reduceMotion {
            HomeReelPage(
                reel: reel,
                thumbnailData: viewModel.thumbnailData(for: reel.id),
                isLoadingThumbnail: viewModel.isLoadingThumbnail(for: reel.id),
                authorProfileImageData: viewModel.authorProfileImageData(for: reel.id),
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
                        guard let isSaved = await viewModel.toggleSaved(
                            for: reel.id
                        ) else {
                            return
                        }

                        showSaveToast(isSaved: isSaved)
                    }
                },
                onShowComments: {
                    commentsReel = reel
                },
                onShowAuthorProfile: {
                    onShowAuthorProfile(reel)
                },
                onShare: {
                    shareReel = reel
                },
                cornerRadius: cornerRadius,
                previewHorizontalInset: previewHorizontalInset,
                previewBottomInset: previewBottomInset,
                usesExternalReelInfoOverlay: usesExternalReelInfoOverlay,
                showsMetadata: isHomeReelActive
            )
            .task(id: reel.id) {
                await viewModel.loadThumbnail(for: reel.id)
            }
            .task(id: reel.authorProfileImageURL) {
                await viewModel.loadAuthorProfileImage(for: reel)
            }
        } else {
            HomeReelPage(
                reel: reel,
                thumbnailData: viewModel.thumbnailData(for: reel.id),
                isLoadingThumbnail: viewModel.isLoadingThumbnail(for: reel.id),
                authorProfileImageData: viewModel.authorProfileImageData(for: reel.id),
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
                        guard let isSaved = await viewModel.toggleSaved(
                            for: reel.id
                        ) else {
                            return
                        }

                        showSaveToast(isSaved: isSaved)
                    }
                },
                onShowComments: {
                    commentsReel = reel
                },
                onShowAuthorProfile: {
                    onShowAuthorProfile(reel)
                },
                onShare: {
                    shareReel = reel
                },
                cornerRadius: cornerRadius,
                previewHorizontalInset: previewHorizontalInset,
                previewBottomInset: previewBottomInset,
                usesExternalReelInfoOverlay: usesExternalReelInfoOverlay,
                showsMetadata: isHomeReelActive
            )
            .task(id: reel.id) {
                await viewModel.loadThumbnail(for: reel.id)
            }
            .task(id: reel.authorProfileImageURL) {
                await viewModel.loadAuthorProfileImage(for: reel)
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
            let firstReelID = reels.first?.id
            let revealProgress = firstReelRevealProgress(
                viewportHeight: viewportSize.height
            )
            // 홈에서는 내비게이션 위까지 보이는 카드만 둥글게 표시하고,
            // 첫 페이지가 올라오면 여백과 라운드를 함께 없애 전체 릴스로 연결한다.
            let roundedCornerProgress = min(
                max((revealProgress - 0.62) / 0.38, 0),
                1
            )

            ForEach(reels) { reel in
                let usesExternalReelInfoOverlay = reel.id == firstReelID
                let cornerRadius = usesExternalReelInfoOverlay
                    ? HomeFestivalCarouselLayout.cornerRadius
                        * (1 - roundedCornerProgress)
                    : 0
                let previewHorizontalInset = usesExternalReelInfoOverlay
                    ? MaplogSpacing.page * (1 - roundedCornerProgress)
                    : 0
                let previewBottomInset = usesExternalReelInfoOverlay
                    ? min(viewportSize.height,
                          max(0, firstReelTopOffset ?? 0)
                            + MaplogSpacing.reelTabBarClearance * (1 - roundedCornerProgress))
                    : 0

                homeReelPage(
                    for: reel,
                    usesExternalReelInfoOverlay: usesExternalReelInfoOverlay,
                    cornerRadius: cornerRadius,
                    previewHorizontalInset: previewHorizontalInset,
                    previewBottomInset: previewBottomInset
                )
                    .frame(
                        width: viewportSize.width,
                        height: viewportSize.height
                    )
                    .background {
                        if usesExternalReelInfoOverlay {
                            GeometryReader { reelProxy in
                                Color.clear.preference(
                                    key: FirstReelTopOffsetPreferenceKey.self,
                                    value: reelProxy.frame(
                                        in: .named(Self.viewportCoordinateSpace)
                                    ).minY
                                )
                            }
                        }
                    }
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
        .padding(.bottom, 16)
    }

    private var homeHeader: some View {
        HStack(spacing: MaplogSpacing.small) {
            Text("Maplog")
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            Spacer()

            // 44pt 터치 영역은 유지하고 버튼 사이의 추가 여백만 없앱니다.
            HStack(spacing: 0) {
                Button(action: onCreateLog) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.maplogInk)
                        .frame(
                            width: MaplogSize.minimumTapTarget,
                            height: MaplogSize.minimumTapTarget
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("로그 작성")
                .accessibilityHint("저장한 클립을 골라 로그 작성을 시작합니다")

                NavigationLink {
                    HomeSearchFeatureView(
                        searchRepository: homeSearchRepository,
                        logMediaRepository: logMediaRepository,
                        logReelRepository: logReelRepository,
                        onShowLogDetail: onShowLogDetail,
                        onShowTourismDetail: onShowTourismDetail
                    )
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("검색")

                Button(action: onShowNotifications) {
                    Image(systemName: "bell")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("알림")
                .accessibilityHint("서버에 저장된 알림 목록을 엽니다")
                .accessibilityIdentifier("home.notifications")
            }
        }
    }

    /// 토스트는 서버 저장 성공 이후에만 표시한다.
    private func showSaveToast(isSaved: Bool) {
        let message = isSaved
            ? "저장했어요"
            : "저장을 해제했어요"

        withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
            saveToastText = message
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.45))

            guard !Task.isCancelled,
                  saveToastText == message
            else {
                return
            }

            withAnimation(.easeOut(duration: 0.20)) {
                saveToastText = nil
            }
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
        }
    }

    // loading / content / empty / failed 중 무엇을 보일지 결정 (상태 판단과 관광 카드 레이아웃을 분리)
    @ViewBuilder
    private var tourismSectionContent: some View{
        switch viewModel.tourismState {
        case .idle, .loading:
            ProgressView("축제 정보를 불러오는 중이에요")
                .frame(maxWidth: .infinity, minHeight: 120)
                .padding(.horizontal, MaplogSpacing.page)
        case .content(let cards):

            tourismCards(cards)
        case .empty:
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Text("현재 표시할 축제가 없어요.")
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
            LazyHStack(alignment: .top, spacing: HomeFestivalCarouselLayout.cardSpacing) {
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

struct HomeTourismCarouselCard: View {
    let card: HomeTourismCardViewData

    @ScaledMetric(relativeTo: .subheadline)
    private var posterHeight = HomeFestivalCarouselLayout.posterHeight

    private var cardWidth: CGFloat {
        posterHeight * card.poster.aspectRatio
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
            tourismThumbnail
                // 높이를 맞추고 폭은 원본 비율을 따라 포스터 전체를 같은 높이에 배치한다.
                .frame(width: cardWidth, height: posterHeight)
                .background(Color.maplogCanvas)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: HomeFestivalCarouselLayout.posterCornerRadius,
                        style: .continuous
                    )
                )
                .accessibilityHidden(true)

            Text(card.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.maplogInk)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: MaplogSpacing.xSmall) {
                        periodLabel
                        scheduleStatus
                    }

                    VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                        periodLabel
                        scheduleStatus
                    }
                }

                MaplogLocationLabel(title: card.locationText, pinSize: 12)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(MaplogFont.caption)
            .foregroundStyle(Color.maplogMuted)
        }
        .frame(width: cardWidth, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            [card.title, card.periodText, card.dDayText, card.locationText]
                .compactMap { $0 }
                .joined(separator: ", ")
        )
    }

    private var periodLabel: some View {
        HStack(spacing: MaplogSpacing.xxxSmall) {
            MaplogCalendarGlyphIcon(size: 12)
            Text(card.periodText)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var scheduleStatus: some View {
        if let dDayText = card.dDayText {
            Text(dDayText)
                .fontWeight(.semibold)
                .foregroundStyle(Color.maplogOlive)
                .fixedSize()
        }
    }

    @ViewBuilder
    private var tourismThumbnail: some View {
        if let image = UIImage(data: card.poster.data) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}
