import SwiftUI

struct LogFeedView: View {
    @Environment(\.maplogSelectTab) private var selectTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @State private var selectedMode = "추천"
    @State private var currentPost = MockMaplogData.posts[0]
    @State private var logScrollPosition: String? = MockMaplogData.posts[0].id
    @State private var selectedPlaceForSheet: MaplogSpot?
    @State private var selectedProfilePost: VlogPost?
    @State private var selectedCommentPost: VlogPost?
    @State private var sharePost: VlogPost?
    @State private var shareSheetDetent: PresentationDetent = .medium
    @State private var activeClipIndex = 0
    @State private var actionToast: String?
    @State private var selectedReelPage = 0

    private var feedPosts: [VlogPost] {
        sessionStore.publishedLogs.map(post(from:)) + MockMaplogData.posts
    }

    private var unblockedPosts: [VlogPost] {
        feedPosts.filter { !sessionStore.isBlocked(author: $0.author) }
    }

    private var visiblePosts: [VlogPost] {
        if selectedMode == "팔로잉" {
            return unblockedPosts.filter { sessionStore.isFollowing(author: $0.author) }
        }
        return unblockedPosts
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if visiblePosts.isEmpty {
                    Color.black
                    VStack(spacing: 0) {
                        clipProgress
                        topBar(for: currentPost)
                        Spacer()
                        emptyFeedState
                            .padding(.horizontal, MaplogSpacing.page)
                            .padding(.bottom, proxy.safeAreaInsets.bottom + MaplogSpacing.reelTabBarClearance)
                    }
                    .padding(.top, max(proxy.safeAreaInsets.top, MaplogSpacing.reelTopClearance) + 8)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(visiblePosts) { post in
                                logReelPager(post: post, proxy: proxy)
                                    .frame(width: proxy.size.width, height: proxy.size.height)
                                    .id(post.id)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollPosition(id: $logScrollPosition, anchor: .top)
                    .scrollTargetBehavior(.paging)
                    .background(Color.black)
                }

                if let actionToast {
                    Text(actionToast)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 48)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, proxy.safeAreaInsets.bottom + MaplogSpacing.reelTabBarClearance)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .maplogReelTabBarStyle()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedProfilePost) { post in
            OtherProfileView(post: post)
        }
        .sheet(item: $selectedPlaceForSheet) { spot in
            VlogPlaceInfoSheet(spot: spot, post: currentPost)
                .presentationDetents([.height(760), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedCommentPost) { post in
            VlogCommentsSheet(post: post)
                .presentationDetents([.fraction(0.62), .large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $sharePost) { post in
            MaplogActivityShareSheet(post: post) {
                sharePost = nil
            }
            .presentationDetents([.medium, .large], selection: $shareSheetDetent)
            .presentationDragIndicator(.visible)
        }
        .onChange(of: selectedMode) { _, _ in
            moveToFirstVisiblePost()
        }
        .onChange(of: sessionStore.followedAuthorIDs) { _, _ in
            moveToFirstVisiblePost()
        }
        .onChange(of: sessionStore.blockedAuthorIDs) { _, _ in
            moveToFirstVisiblePost()
        }
        .onChange(of: sessionStore.publishedLogs) { _, _ in
            moveToFirstVisiblePost(preferFirst: selectedMode == "추천")
        }
        .onChange(of: logScrollPosition) { _, newPostID in
            guard
                let newPostID,
                let post = visiblePosts.first(where: { $0.id == newPostID })
            else {
                return
            }

            currentPost = post
            activeClipIndex = 0
            selectedReelPage = 0
        }
        .onAppear {
            moveToFirstVisiblePost(preferFirst: selectedMode == "추천")
        }
    }

    private func logReelPager(post: VlogPost, proxy: GeometryProxy) -> some View {
        TabView(selection: $selectedReelPage) {
            reelVideoPage(post: post, proxy: proxy)
                .tag(0)

            MaplogReelRoutePage(post: post, trip: routeTrip(for: post))
                .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(width: proxy.size.width, height: proxy.size.height)
        .background(Color.black)
        .overlay(alignment: .top) {
            MaplogReelPageCue(selectedPage: selectedReelPage)
                .padding(.top, max(proxy.safeAreaInsets.top, MaplogSpacing.reelTopClearance) + 92)
        }
        .accessibilityHint("좌우로 넘기면 영상과 전체 루트를 전환합니다")
    }

    private func reelVideoPage(post: VlogPost, proxy: GeometryProxy) -> some View {
        ZStack {
            VlogPostImageView(post: post)
                .frame(width: proxy.size.width, height: proxy.size.height + 2)
                .ignoresSafeArea(.container, edges: .top)

            LinearGradient(
                colors: [.black.opacity(0.28), .clear, .black.opacity(0.18), .black.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(.container, edges: .top)

            Color.clear
                .frame(width: max(proxy.size.width * 0.24, 76), height: max(proxy.size.height * 0.26, 140))
                .contentShape(Rectangle())
                .position(x: proxy.size.width * 0.87, y: proxy.size.height * 0.42)
                .onTapGesture {
                    showNextPost(after: post)
                }
                .accessibilityElement()
                .accessibilityLabel("다음 Maplog")
                .accessibilityAddTraits(.isButton)

            VStack(spacing: 0) {
                clipProgress
                topBar(for: post)
                Spacer()

                HStack(alignment: .bottom, spacing: 14) {
                    postMeta(for: post)
                        .layoutPriority(1)
                    sideActions(for: post)
                        .frame(width: 48)
                }
                .padding(.horizontal, MaplogSpacing.page)
                .padding(.bottom, proxy.safeAreaInsets.bottom + MaplogSpacing.reelTabBarClearance)
            }
            .padding(.top, max(proxy.safeAreaInsets.top, MaplogSpacing.reelTopClearance) + 8)
        }
        .frame(width: proxy.size.width, height: proxy.size.height)
        .clipped()
    }

    private var clipProgress: some View {
        Button {
            activeClipIndex = (activeClipIndex + 1) % 4
            showToast("\(activeClipIndex + 1)번째 클립 재생 중")
        } label: {
            HStack(spacing: 5) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index <= activeClipIndex ? Color.white : Color.white.opacity(0.34))
                        .frame(maxWidth: .infinity)
                        .frame(height: 3)
                }
            }
            .padding(.horizontal, MaplogSpacing.page)
            .frame(height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("클립 진행 상태, 4개 중 \(activeClipIndex + 1)번째")
        .accessibilityHint("다음 클립으로 이동합니다")
    }

    private func topBar(for post: VlogPost) -> some View {
        HStack(spacing: MaplogSpacing.small) {
            Button {
                showToast("검색은 홈 탭에서 이용할 수 있어요")
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("검색")

            Spacer(minLength: 0)

            HStack(spacing: 22) {
                modeButton("팔로잉")
                modeButton("추천")
            }

            Spacer(minLength: 0)

            Menu {
                Button {
                    shareSheetDetent = .medium
                    sharePost = post
                } label: {
                    Label("공유", systemImage: "square.and.arrow.up")
                }

                Button {
                    selectedPlaceForSheet = post.place
                } label: {
                    Label("장소 정보", systemImage: "mappin.and.ellipse")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("더보기")
        }
        .padding(.horizontal, MaplogSpacing.page)
        .frame(height: 48)
    }

    private func modeButton(_ title: String) -> some View {
        Button {
            selectedMode = title
            activeClipIndex = 0
            if title == "팔로잉" && unblockedPosts.filter({ sessionStore.isFollowing(author: $0.author) }).isEmpty {
                showToast("팔로우한 맵로거가 아직 없어요")
            }
        } label: {
            VStack(spacing: MaplogSpacing.xSmall) {
                Text(title)
                    .font(.headline.weight(selectedMode == title ? .bold : .medium))
                    .foregroundStyle(selectedMode == title ? .white : .white.opacity(0.62))
                Capsule()
                    .fill(selectedMode == title ? Color.maplogLime : .clear)
                    .frame(width: 22, height: 3)
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    private var emptyFeedState: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.medium) {
            VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                Text(selectedMode == "팔로잉" ? "팔로우한 맵로거가 아직 없어요" : "표시할 맵로그가 없어요")
                    .font(.system(size: 25, weight: .black))
                    .foregroundStyle(.white)
                Text(selectedMode == "팔로잉" ? "마음에 드는 작성자를 팔로우하면 이 탭에서 새 로그만 모아볼 수 있어요." : "차단한 사용자를 해제하면 추천 로그를 다시 볼 수 있어요.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.84))
                    .lineSpacing(4)
            }

            if selectedMode == "팔로잉" {
                VStack(spacing: 10) {
                    ForEach(unblockedPosts) { post in
                        suggestedAuthorRow(post)
                    }
                }
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                    selectedMode = "추천"
                    moveToFirstVisiblePost()
                }
            } label: {
                Label("추천 피드 둘러보기", systemImage: "play.rectangle.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Color.maplogOnPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(.black.opacity(0.44))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }

    private func suggestedAuthorRow(_ post: VlogPost) -> some View {
        HStack(spacing: MaplogSpacing.small) {
            VlogPostImageView(post: post, cornerRadius: 24)
                .frame(height: 48)
                .frame(width: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(post.author)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                Text(post.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                sessionStore.follow(author: post.author)
                showToast("\(post.author)을 팔로우했어요")
            } label: {
                Text("팔로우")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.maplogOnPrimary)
                    .padding(.horizontal, MaplogSpacing.small)
                    .frame(height: 34)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(post.author) 팔로우")
        }
        .padding(10)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func postMeta(for post: VlogPost) -> some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
            HStack(spacing: 10) {
                Button {
                    if post.author == "@\(sessionStore.profile.displayName)" {
                        selectTab(.profile)
                    } else {
                        selectedProfilePost = post
                    }
                } label: {
                    HStack(spacing: MaplogSpacing.xSmall) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                        Text(post.author)
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                if post.author != "@\(sessionStore.profile.displayName)" {
                    Button {
                        toggleFollow(for: post)
                    } label: {
                        Text(sessionStore.isFollowing(author: post.author) ? "팔로잉" : "팔로우")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(sessionStore.isFollowing(author: post.author) ? .white : Color.maplogInk)
                            .padding(.horizontal, 11)
                            .frame(minHeight: 30)
                            .background(
                                sessionStore.isFollowing(author: post.author)
                                    ? Color.white.opacity(0.18)
                                    : Color.maplogLime,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(post.title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(post.caption)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(1)

            Text(post.hashtags.map { "#\($0)" }.joined(separator: "  "))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(1)

            Button {
                selectedPlaceForSheet = post.place
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.place.name)
                            .font(.subheadline.weight(.semibold))
                        Text(post.place.area)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, MaplogSpacing.small)
                .frame(minHeight: 44)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            routeAction(for: post)
        }
    }

    private func routeAction(for post: VlogPost) -> some View {
        NavigationLink {
            PopularMaplogDetailView(post: post, trip: routeTrip(for: post))
        } label: {
            Label("루트 따라가기", systemImage: "location.north.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.maplogOnPrimary)
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(Color.maplogLime)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func sideActions(for post: VlogPost) -> some View {
        VStack(spacing: MaplogSpacing.xSmall) {
            actionButton(
                icon: sessionStore.hasLikedVlogPost(post) ? "heart.fill" : "heart",
                count: likeCountText(for: post),
                tint: sessionStore.hasLikedVlogPost(post) ? Color.maplogLime : .white
            ) {
                toggleLike(for: post)
            }
            actionButton(icon: "message.fill", count: commentCountText(for: post)) {
                selectedCommentPost = post
            }
            actionButton(icon: "square.and.arrow.up", count: "공유") {
                shareSheetDetent = .medium
                sharePost = post
            }
            actionButton(
                icon: sessionStore.hasSavedRoute(routeTrip(for: post)) ? "bookmark.fill" : "bookmark",
                count: "저장",
                tint: sessionStore.hasSavedRoute(routeTrip(for: post)) ? Color.maplogLime : .white
            ) {
                toggleSave(for: post)
            }
        }
        .foregroundStyle(.white)
    }

    private func actionButton(icon: String, count: String, tint: Color = .white, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(tint)
                Text(count)
                    .font(.caption2.weight(.bold))
            }
            .frame(width: 48)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleLike(for post: VlogPost) {
        if sessionStore.hasLikedVlogPost(post) {
            sessionStore.unlikeVlogPost(post)
            showToast("좋아요를 취소했어요")
        } else {
            sessionStore.likeVlogPost(post)
            showToast("좋아요를 눌렀어요")
        }
    }

    private func toggleFollow(for post: VlogPost) {
        if sessionStore.isFollowing(author: post.author) {
            sessionStore.unfollow(author: post.author)
            showToast("팔로우를 취소했어요")
        } else {
            sessionStore.follow(author: post.author)
            showToast("\(post.author)을 팔로우했어요")
        }
    }

    private func toggleSave(for post: VlogPost) {
        let trip = routeTrip(for: post)

        if sessionStore.hasSavedRoute(trip) {
            sessionStore.removeSavedRoute(trip)
            showToast("저장을 해제했어요")
        } else {
            sessionStore.saveRoute(trip)
            showToast("루트 보관함에 저장했어요")
        }
    }

    private func commentCountText(for post: VlogPost) -> String {
        let totalCount = baseCommentCount(for: post) + sessionStore.vlogCommentCount(for: post.id)
        return totalCount >= 1_000 ? String(format: "%.1fk", Double(totalCount) / 1_000) : "\(totalCount)"
    }

    private func likeCountText(for post: VlogPost) -> String {
        guard let baseCount = compactCountValue(from: post.likes) else {
            return post.likes
        }

        let wasInitiallyLiked = sessionStore.wasInitiallyLikedVlogPost(post)
        let isLiked = sessionStore.hasLikedVlogPost(post)
        let adjustment = isLiked == wasInitiallyLiked ? 0 : (isLiked ? 1 : -1)
        return compactCountText(max(baseCount + adjustment, 0))
    }

    private func compactCountValue(from text: String) -> Int? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.hasSuffix("k") {
            let numberText = String(normalized.dropLast())
            guard let value = Double(numberText) else { return nil }
            return Int((value * 1_000).rounded())
        }

        return Int(normalized.filter(\.isNumber))
    }

    private func compactCountText(_ count: Int) -> String {
        guard count >= 1_000 else {
            return "\(count)"
        }

        let value = Double(count) / 1_000
        let formatted = String(format: "%.1f", value)
        return "\(formatted.replacingOccurrences(of: ".0", with: ""))k"
    }

    private func baseCommentCount(for post: VlogPost) -> Int {
        Int(post.comments.filter(\.isNumber)) ?? 0
    }

    private func routeTrip(for post: VlogPost) -> MaplogTrip {
        MockMaplogData.routeTrip(for: post)
    }

    private func post(from log: TravelLog) -> VlogPost {
        let spot = spot(for: log)
        return VlogPost(
            id: "published-post-\(log.id)",
            author: "@\(sessionStore.profile.displayName)",
            title: log.title,
            caption: log.note,
            place: spot,
            imageStyle: log.imageStyle,
            likes: "0",
            comments: "0",
            hashtags: hashtags(for: log)
        )
    }

    private func spot(for log: TravelLog) -> MaplogSpot {
        if let existingSpot = MockMaplogData.spots.first(where: { $0.name == log.place }) {
            return existingSpot
        }

        return MaplogSpot(
            id: "published-spot-\(log.id)",
            name: log.place,
            category: "내 기록",
            area: log.city,
            summary: log.note,
            rating: 5.0,
            imageStyle: log.imageStyle,
            tags: hashtags(for: log),
            pinX: 0.50,
            pinY: 0.50
        )
    }

    private func hashtags(for log: TravelLog) -> [String] {
        let cityTag = log.city.trimmingCharacters(in: .whitespacesAndNewlines)
        let placeTag = log.place.replacingOccurrences(of: " ", with: "")
        return ["내기록", cityTag.isEmpty ? "Maplog" : cityTag, placeTag]
            .filter { !$0.isEmpty }
    }

    private func showNextPost(after post: VlogPost) {
        let posts = visiblePosts
        guard !posts.isEmpty else { return }
        let currentIndex = posts.firstIndex(where: { $0.id == post.id }) ?? 0
        let nextIndex = (currentIndex + 1) % posts.count
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
            logScrollPosition = posts[nextIndex].id
        }
    }

    private func moveToFirstVisiblePost(preferFirst: Bool = false) {
        guard let firstPost = visiblePosts.first else {
            return
        }

        guard preferFirst || !visiblePosts.contains(where: { $0.id == currentPost.id }) else {
            return
        }

        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
            currentPost = firstPost
            logScrollPosition = firstPost.id
            activeClipIndex = 0
            selectedReelPage = 0
        }
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            actionToast = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            withAnimation(.easeOut(duration: 0.22)) {
                if actionToast == message {
                    actionToast = nil
                }
            }
        }
    }
}

private struct PopularRouteStop: Identifiable {
    let spot: MaplogSpot
    let subtitle: String
    let duration: String

    var id: String { spot.id }
}

struct PopularMaplogDetailView: View {
    let post: VlogPost
    let trip: MaplogTrip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @State private var showsShareSheet = false
    @State private var toastText: String?

    private var isSaved: Bool {
        sessionStore.hasSavedRoute(trip)
    }

    private var routeStops: [PopularRouteStop] {
        trip.spots.enumerated().map { index, spot in
            PopularRouteStop(
                spot: spot,
                subtitle: routeStopSubtitle(for: spot, at: index),
                duration: routeStopDuration(at: index)
            )
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                    if isSaved {
                        savedRouteConfirmation
                            .padding(.horizontal, MaplogSpacing.page)
                            .padding(.top, 24)
                    }
                    itinerary
                        .padding(.horizontal, MaplogSpacing.page)
                        .padding(.top, isSaved ? 18 : 24)
                        .padding(.bottom, 126)
                }
            }
            .ignoresSafeArea(edges: .top)

            bottomBar

            if let toastText {
                Text(toastText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 18)
                    .frame(height: 50)
                    .background(Color.maplogSurface)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
                    .padding(.bottom, 106)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            routeTopBar
        }
        .background(Color.maplogSurface)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .maplogTabBarHidden()
        .sheet(isPresented: $showsShareSheet) {
            RouteShareSheet(trip: trip) { message in
                showToast(message)
            }
            .presentationDetents([.height(328)])
            .presentationDragIndicator(.visible)
        }
    }

    private var routeTopBar: some View {
        HStack {
            MaplogNavigationButton(systemName: "chevron.left", accessibilityLabel: "뒤로 가기") {
                close()
            }

            Spacer()
            Text("루트 상세")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.maplogInk)
            Spacer()

            MaplogNavigationButton(systemName: "square.and.arrow.up", accessibilityLabel: "루트 공유") {
                showsShareSheet = true
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 48)
        .frame(height: 106)
        .background(Color.maplogSurface)
    }

    private var header: some View {
        VlogPostImageView(post: post, cornerRadius: MaplogRadius.xLarge)
            .frame(height: 286)
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .top, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.xLarge, style: .continuous))
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(post.title)
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    HStack(spacing: MaplogSpacing.small) {
                        Label("\(routeStops.count)개 장소", systemImage: "mappin.and.ellipse")
                        Label("2.5km", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                        Label(trip.duration, systemImage: "clock")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
                }
                .padding(MaplogSpacing.large)
            }
            .padding(.horizontal, MaplogSpacing.page)
            .padding(.top, 118)
    }

    private var itinerary: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("루트 일정")
                .font(MaplogFont.sectionTitle)
                .foregroundStyle(Color.maplogInk)

            VStack(spacing: 0) {
                ForEach(Array(routeStops.enumerated()), id: \.element.id) { index, stop in
                    HStack(alignment: .top, spacing: MaplogSpacing.medium) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(index == 0 ? Color.maplogLime : Color.maplogLine)
                                .frame(width: 14, height: 14)
                            Rectangle()
                                .fill(index == routeStops.count - 1 ? .clear : Color.maplogLine)
                                .frame(width: 2, height: 104)
                        }
                        .frame(width: 20)

                        NavigationLink {
                            SpotDetailView(spot: stop.spot)
                        } label: {
                            HStack(spacing: 14) {
                                TravelImageView(style: stop.spot.imageStyle, height: 78, cornerRadius: MaplogRadius.small, showsSymbol: false)
                                    .frame(width: 78)

                                VStack(alignment: .leading, spacing: 7) {
                                    HStack(alignment: .top) {
                                        Text(stop.spot.name)
                                            .font(.system(size: 19, weight: .black))
                                            .foregroundStyle(Color.maplogInk)
                                            .lineLimit(2)
                                        Spacer(minLength: 8)
                                        Text(stop.duration)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color.maplogMuted)
                                    }

                                    Text(stop.subtitle)
                                        .font(MaplogFont.callout)
                                        .foregroundStyle(Color.maplogMuted)
                                        .lineLimit(1)

                                    Label("지도에서 보기", systemImage: "map")
                                        .font(.system(size: 13, weight: .black))
                                        .foregroundStyle(Color.maplogOlive)
                                }
                            }
                            .padding(14)
                            .background(Color.maplogSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func routeStopSubtitle(for spot: MaplogSpot, at index: Int) -> String {
        if index == 0 {
            return post.caption
        }
        return spot.summary
    }

    private func routeStopDuration(at index: Int) -> String {
        let durations = ["45분", "30분", "1시간"]
        guard durations.indices.contains(index) else {
            return "30분"
        }
        return durations[index]
    }

    private var savedRouteConfirmation: some View {
        HStack(spacing: MaplogSpacing.small) {
            Image(systemName: "bookmark.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.maplogPrimary)
            Text("루트가 저장되어 있어요")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.maplogInk)
            Spacer()
        }
        .frame(minHeight: 48)
        .padding(.horizontal, MaplogSpacing.medium)
        .maplogCard()
    }

    private var bottomBar: some View {
        HStack(spacing: MaplogSpacing.small) {
            Button {
                toggleSavedRoute()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 23, weight: .bold))
                    Text(isSaved ? "저장됨" : "이 루트 저장")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(Color.maplogInk)
                .frame(width: 96, height: 68)
            }
            .buttonStyle(MaplogPressFeedbackStyle())

            NavigationLink {
                RouteDetailView(trip: trip)
            } label: {
                Label("따라가기 시작", systemImage: "play.circle.fill")
                    .font(MaplogFont.cardTitle)
                    .foregroundStyle(Color.maplogOnPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(Color.maplogLime, in: RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, MaplogSpacing.page)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .background(Color.maplogSurface)
    }

    private func toggleSavedRoute() {
        if isSaved {
            sessionStore.removeSavedRoute(trip)
            showToast("루트 저장을 해제했어요")
        } else {
            sessionStore.saveRoute(trip)
            showToast("이 루트를 보관함에 저장했어요")
        }
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            toastText = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                if toastText == message {
                    toastText = nil
                }
            }
        }
    }

    private func close() {
        dismiss()
        presentationMode.wrappedValue.dismiss()
    }
}

struct VlogPlaceInfoSheet: View {
    let spot: MaplogSpot
    let post: VlogPost
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @State private var showsShareSheet = false
    @State private var toastMessage: String?

    private var relatedPosts: [VlogPost] {
        let posts = MockMaplogData.posts.filter { $0.place.id == spot.id || $0.id == post.id }
        return posts.isEmpty ? MockMaplogData.posts : posts
    }

    private var galleryStyles: [PhotoStyle] {
        [spot.imageStyle, post.imageStyle, .cafe, .alley]
    }

    private var suggestedTrip: MaplogTrip {
        routeTrip(for: spot)
    }

    private var routeAdded: Bool {
        sessionStore.hasSavedRoute(suggestedTrip)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                backgroundScene

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        topControls
                            .padding(.top, 26)
                            .padding(.horizontal, MaplogSpacing.page)

                        placeCard
                            .padding(.top, 70)
                    }
                    .padding(.bottom, 112)
                }

                bottomAddBar

                if let toastMessage {
                    Text(toastMessage)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, 18)
                        .frame(height: 48)
                        .background(Color.maplogSurface)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.14), radius: 16, x: 0, y: 8)
                        .padding(.bottom, 94)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(Color.maplogCanvas)
            .ignoresSafeArea(edges: .top)
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showsShareSheet) {
            SpotShareSheet(spot: spot) { message in
                showToast(message)
            }
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
    }

    private var backgroundScene: some View {
        TravelImageView(style: post.imageStyle, height: 360, cornerRadius: 0, showsSymbol: false)
            .blur(radius: 9)
            .overlay(Color.maplogSurface.opacity(0.30))
            .ignoresSafeArea()
    }

    private var topControls: some View {
        HStack {
            sheetCircleButton(systemImage: "xmark") {
                dismiss()
            }
            Spacer()
            sheetCircleButton(systemImage: "square.and.arrow.up") {
                showsShareSheet = true
            }
        }
    }

    private var placeCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(Color.maplogLine)
                .frame(width: 52, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(galleryStyles.enumerated()), id: \.offset) { index, style in
                        TravelImageView(style: style, height: 206, cornerRadius: 14, showsSymbol: false)
                            .frame(width: index == 0 ? 256 : 168)
                            .overlay(alignment: .topTrailing) {
                                if index == 0 {
                                    Text("대표")
                                        .font(.system(size: 11, weight: .black))
                                        .foregroundStyle(Color.maplogOnPrimary)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 5)
                                        .background(Color.maplogLime)
                                        .clipShape(Capsule())
                                        .padding(10)
                                }
                            }
                    }
                }
                .padding(.horizontal, MaplogSpacing.page)
            }

            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .firstTextBaseline) {
                    Text(spot.name)
                        .font(.system(size: 27, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                    Spacer()
                    Label(String(format: "%.1f", spot.rating), systemImage: "star.fill")
                        .font(MaplogFont.cardTitle)
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(Color.maplogCanvas)
                        .clipShape(Capsule())
                }

                Label("\(spot.area) · 계동길 5", systemImage: "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.maplogMuted)

                HStack(spacing: MaplogSpacing.xSmall) {
                    ForEach(spot.tags.prefix(3), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.maplogMuted)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Color.maplogCanvas)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, MaplogSpacing.page)

            reviewBlock
                .padding(.horizontal, MaplogSpacing.page)

            relatedMaplogs
                .padding(.horizontal, MaplogSpacing.page)

            NavigationLink {
                SpotDetailView(spot: spot)
            } label: {
                Label("장소 상세 정보 보기", systemImage: "mappin.circle.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.maplogCanvas)
                    .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, MaplogSpacing.page)
            .padding(.bottom, 18)
        }
        .background(Color.maplogSurface)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.24), radius: 28, x: 0, y: -10)
    }

    private var reviewBlock: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Rectangle()
                .fill(Color.maplogLine)
                .frame(height: 1)

            HStack(alignment: .top, spacing: MaplogSpacing.small) {
                Circle()
                    .fill(Color.maplogCanvas)
                    .frame(width: 42, height: 42)
                    .overlay {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.maplogMuted)
                    }

                VStack(alignment: .leading, spacing: 7) {
                    Text("여행자지민")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.maplogInk)
                    Text("평일 오전에 갔는데도 사람이 많았지만, \(spot.category) 특유의 분위기가 정말 좋았어요. 근처 루트까지 이어서 보기 좋아요.")
                        .font(MaplogFont.callout)
                        .lineSpacing(3)
                        .foregroundStyle(Color.maplogInk)
                }
            }

            Rectangle()
                .fill(Color.maplogLine)
                .frame(height: 1)
        }
    }

    private var relatedMaplogs: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("이 장소가 포함된 다른 맵로그")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.maplogInk)

            HStack(spacing: MaplogSpacing.small) {
                ForEach(relatedPosts.prefix(2)) { item in
                    NavigationLink {
                        PopularMaplogDetailView(post: item, trip: MockMaplogData.routeTrip(for: item))
                    } label: {
                        VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                            TravelImageView(style: item.imageStyle, height: 122, cornerRadius: MaplogRadius.medium, showsSymbol: false)
                            Text(item.title)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.maplogInk)
                                .lineLimit(2)
                            Text(item.author)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.maplogMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var bottomAddBar: some View {
        VStack(spacing: 0) {
            Button {
                toggleRouteAdded()
            } label: {
                Label(routeAdded ? "내 루트에 추가됨" : "내 루트에 추가", systemImage: routeAdded ? "checkmark" : "plus")
                    .font(MaplogFont.sectionTitle)
                    .foregroundStyle(Color.maplogOnPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())
                    .padding(.horizontal, MaplogSpacing.page)
                    .padding(.top, 14)
                    .padding(.bottom, 20)
            }
            .buttonStyle(.plain)
        }
        .background(Color.maplogSurface)
    }

    private func toggleRouteAdded() {
        if routeAdded {
            sessionStore.removeSavedRoute(suggestedTrip)
            showToast("루트 추가를 해제했어요")
        } else {
            sessionStore.saveRoute(suggestedTrip)
            showToast("내 루트에 추가했어요")
        }
    }

    private func routeTrip(for spot: MaplogSpot) -> MaplogTrip {
        MockMaplogData.routeTrip(for: spot)
    }

    private func sheetCircleButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(MaplogFont.cardTitle)
                .foregroundStyle(Color.maplogInk)
                .frame(width: 44, height: 44)
                .background(Color.maplogSurface.opacity(0.92))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            withAnimation(.easeOut(duration: 0.2)) {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }
}

private struct LegacyVlogCommentsSheet: View {
    let post: VlogPost
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @State private var draft = ""
    @FocusState private var isComposerFocused: Bool
    @State private var replyTarget: VlogComment?
    @State private var likedCommentIDs: Set<String> = []
    @State private var localReplies: [String: [VlogComment]] = [:]
    @State private var expandedReplyIDs: Set<String> = []

    private var baseCommentCount: Int {
        Int(post.comments.filter(\.isNumber)) ?? 0
    }

    private var totalCommentCount: Int {
        baseCommentCount + sessionStore.vlogCommentCount(for: post.id) + localReplies.values.reduce(0) { $0 + $1.count }
    }

    private var comments: [VlogComment] {
        sessionStore.vlogComments(for: post.id) + defaultComments
    }

    private var defaultComments: [VlogComment] {
        [
            VlogComment(id: "\(post.id)-default-1", author: "traveler_min", body: "여기 루트 그대로 따라가도 좋겠어요.", timeText: "1분", isMine: false),
            VlogComment(id: "\(post.id)-default-2", author: "route.collector", body: "카페 위치 저장했습니다. 주말에 가볼게요.", timeText: "2분", isMine: false),
            VlogComment(id: "\(post.id)-default-3", author: "seoul.walker", body: "영상 분위기랑 장소가 잘 맞네요.", timeText: "3분", isMine: false)
        ]
    }

    private var seededReplies: [String: [VlogComment]] {
        guard let firstComment = defaultComments.first else { return [:] }
        return [
            firstComment.id: [
                VlogComment(
                    id: "\(post.id)-seeded-reply-1",
                    author: "maplover",
                    body: "저도 다음 주에 이 코스로 걸어보려고요.",
                    timeText: "방금 전",
                    isMine: false
                )
            ]
        ]
    }

    private let avatarLetters = [
        "채", "민", "서", "준", "아"
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    header

                    postContext
                        .padding(.vertical, MaplogSpacing.small)

                    Divider()
                        .overlay(Color.maplogLine)

                    Text("댓글 \(totalCommentCount)")
                        .font(MaplogFont.cardTitle)
                        .foregroundStyle(Color.maplogInk)
                        .padding(.top, MaplogSpacing.large)
                        .padding(.bottom, MaplogSpacing.small)

                    ForEach(Array(comments.enumerated()), id: \.element.id) { index, comment in
                        commentRow(comment, index: index)
                            .padding(.vertical, MaplogSpacing.small)
                    }
                }
                .padding(.horizontal, MaplogSpacing.page)
                .padding(.bottom, MaplogSpacing.large)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composer
            }
            .background(Color.maplogSurface)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: MaplogSpacing.small) {
            VStack(alignment: .leading, spacing: 3) {
                Text("댓글")
                    .font(MaplogFont.screenTitle)
                    .foregroundStyle(Color.maplogInk)
                Text("Maplog 여행자들의 짧은 기록")
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogMuted)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("댓글 닫기")
        }
        .padding(.top, MaplogSpacing.large)
        .padding(.bottom, MaplogSpacing.small)
    }

    private var postContext: some View {
        HStack(spacing: MaplogSpacing.small) {
            VlogPostImageView(post: post, cornerRadius: MaplogRadius.medium)
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(post.title)
                    .font(MaplogFont.bodyStrong)
                    .foregroundStyle(Color.maplogInk)
                    .lineLimit(1)
                Text("\(post.author) · \(post.place.name)")
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func commentRow(_ comment: VlogComment, index: Int) -> some View {
        let replies = replies(for: comment)
        let isExpanded = expandedReplyIDs.contains(comment.id)

        return VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
            HStack(alignment: .top, spacing: MaplogSpacing.small) {
                avatar(for: comment, index: index, size: 40)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: MaplogSpacing.xSmall) {
                        Text(comment.author)
                            .font(MaplogFont.caption)
                            .foregroundStyle(Color.maplogInk)
                        Text(comment.timeText)
                            .font(.caption2)
                            .foregroundStyle(Color.maplogMuted)
                        Spacer(minLength: 0)
                        commentLikeButton(for: comment)
                    }

                    Text(comment.body)
                        .font(MaplogFont.body)
                        .foregroundStyle(Color.maplogInk)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: MaplogSpacing.small) {
                        Button {
                            startReply(to: comment)
                        } label: {
                            Text("답글")
                                .font(MaplogFont.caption)
                                .foregroundStyle(Color.maplogMuted)
                                .frame(minHeight: 32)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(comment.author)에게 답글 달기")

                        if !replies.isEmpty {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if isExpanded {
                                        expandedReplyIDs.remove(comment.id)
                                    } else {
                                        expandedReplyIDs.insert(comment.id)
                                    }
                                }
                            } label: {
                                Label(
                                    isExpanded ? "답글 숨기기" : "답글 \(replies.count)개 보기",
                                    systemImage: isExpanded ? "chevron.up" : "chevron.down"
                                )
                                .font(MaplogFont.caption)
                                .foregroundStyle(Color.maplogOlive)
                                .frame(minHeight: 32)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: MaplogSpacing.small) {
                    ForEach(replies) { reply in
                        replyRow(reply)
                    }
                }
                .padding(.leading, 52)
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func replyRow(_ reply: VlogComment) -> some View {
        HStack(alignment: .top, spacing: MaplogSpacing.inline) {
            avatar(for: reply, index: 0, size: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: MaplogSpacing.xSmall) {
                    Text(reply.author)
                        .font(MaplogFont.caption)
                        .foregroundStyle(Color.maplogInk)
                    Text(reply.timeText)
                        .font(.caption2)
                        .foregroundStyle(Color.maplogMuted)
                    Spacer(minLength: 0)
                    commentLikeButton(for: reply, compact: true)
                }
                Text(reply.body)
                    .font(MaplogFont.callout)
                    .foregroundStyle(Color.maplogInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func avatar(for comment: VlogComment, index: Int, size: CGFloat) -> some View {
        if comment.isMine {
            Image("home_profile_avatar")
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.maplogCanvas)
                .frame(width: size, height: size)
                .overlay {
                    Text(avatarLetters[index % avatarLetters.count])
                        .font(.system(size: size * 0.36, weight: .bold))
                        .foregroundStyle(Color.maplogOlive)
                }
        }
    }

    private func commentLikeButton(for comment: VlogComment, compact: Bool = false) -> some View {
        let isLiked = likedCommentIDs.contains(comment.id)
        let count = baseLikeCount(for: comment) + (isLiked ? 1 : 0)

        return Button {
            withAnimation(.easeOut(duration: 0.18)) {
                if isLiked {
                    likedCommentIDs.remove(comment.id)
                } else {
                    likedCommentIDs.insert(comment.id)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: compact ? 12 : 13, weight: .semibold))
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.semibold))
                }
            }
            .foregroundStyle(isLiked ? Color.maplogOlive : Color.maplogMuted)
            .frame(minHeight: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isLiked ? "댓글 좋아요 취소" : "댓글 좋아요")
        .accessibilityValue(count > 0 ? "\(count)개" : "좋아요 없음")
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
            if let replyTarget {
                HStack(spacing: MaplogSpacing.xSmall) {
                    Text("@\(replyTarget.author)님에게 답글 작성 중")
                        .font(MaplogFont.caption)
                        .foregroundStyle(Color.maplogOlive)
                    Spacer(minLength: 0)
                    Button {
                        self.replyTarget = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(Color.maplogMuted)
                            .frame(width: MaplogSize.minimumTapTarget, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("답글 취소")
                }
            }

            HStack(spacing: MaplogSpacing.xSmall) {
                Image("home_profile_avatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())

                TextField(replyTarget == nil ? "댓글을 입력하세요" : "답글을 입력하세요", text: $draft)
                    .font(MaplogFont.body)
                    .focused($isComposerFocused)
                    .submitLabel(.send)
                    .onSubmit(sendComment)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 46)
                    .background(Color.maplogCanvas, in: Capsule())

                Button(action: sendComment) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.maplogOnPrimary)
                        .frame(width: 46, height: 46)
                        .background(Color.maplogLime, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                .accessibilityLabel(replyTarget == nil ? "댓글 등록" : "답글 등록")
            }
        }
        .padding(.horizontal, MaplogSpacing.page)
        .padding(.top, MaplogSpacing.small)
        .padding(.bottom, MaplogSpacing.small)
        .background(Color.maplogSurface)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.maplogLine).frame(height: 1)
        }
    }

    private func replies(for comment: VlogComment) -> [VlogComment] {
        seededReplies[comment.id, default: []] + localReplies[comment.id, default: []]
    }

    private func baseLikeCount(for comment: VlogComment) -> Int {
        if comment.isMine { return 0 }
        if comment.id.contains("default-1") { return 12 }
        if comment.id.contains("default-2") { return 7 }
        if comment.id.contains("default-3") { return 4 }
        return 2
    }

    private func startReply(to comment: VlogComment) {
        replyTarget = comment
        DispatchQueue.main.async {
            isComposerFocused = true
        }
    }

    private func sendComment() {
        let trimmedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDraft.isEmpty else { return }

        if let replyTarget {
            let reply = VlogComment(
                id: "reply-\(UUID().uuidString)",
                author: sessionStore.profile.displayName,
                body: trimmedDraft,
                timeText: "방금",
                isMine: true
            )
            localReplies[replyTarget.id, default: []].append(reply)
            expandedReplyIDs.insert(replyTarget.id)
            self.replyTarget = nil
        } else {
            guard sessionStore.addVlogComment(postID: post.id, body: trimmedDraft) != nil else { return }
        }

        draft = ""
    }
}

private struct LegacyVlogShareSheet: View {
    let post: VlogPost
    let onAction: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.large) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("공유")
                        .font(MaplogFont.screenTitle)
                        .foregroundStyle(Color.maplogInk)
                    Text(post.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.maplogMuted)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: MaplogSpacing.small) {
                shareOption(title: "링크", systemImage: "link") {
                    complete("맵로그 링크를 복사했어요")
                }
                shareOption(title: "메시지", systemImage: "message.fill") {
                    complete("친구에게 맵로그를 보냈어요")
                }
                shareOption(title: "카드 저장", systemImage: "square.and.arrow.down") {
                    complete("공유 카드를 저장했어요")
                }
                shareOption(title: "더보기", systemImage: "ellipsis") {
                    complete("공유 옵션을 열었어요")
                }
            }

            HStack(spacing: MaplogSpacing.small) {
                TravelImageView(style: post.imageStyle, height: 92, cornerRadius: MaplogRadius.medium, showsSymbol: false)
                    .frame(width: 92)
                VStack(alignment: .leading, spacing: 7) {
                    Text(post.author)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.maplogMuted)
                    Text(post.title)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .lineLimit(2)
                    Text(post.place.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.maplogMuted)
                }
                Spacer()
            }
            .padding(MaplogSpacing.small)
            .maplogCard()
        }
        .padding(MaplogSpacing.xLarge)
        .background(Color.maplogSurface)
    }

    private func shareOption(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(MaplogFont.sectionTitle)
                    .foregroundStyle(Color.maplogPrimary)
                    .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                    .contentShape(Rectangle())
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.maplogMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func complete(_ message: String) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onAction(message)
        }
    }
}

struct OtherProfileView: View {
    let post: VlogPost
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @State private var selectedTab = "맵로그"
    @State private var activeSheet: OtherProfileSheet?
    @State private var showProfileOptions = false
    @State private var toastText: String?

    private let tabs = ["맵로그", "루트", "저장"]

    private var authorPosts: [VlogPost] {
        let matchingPosts = MockMaplogData.posts.filter { $0.author == post.author }
        return matchingPosts.isEmpty ? [post] : matchingPosts
    }

    private var authorRoutes: [MaplogTrip] {
        var seenIDs: Set<String> = []
        return authorPosts.compactMap { item in
            let trip = MockMaplogData.routeTrip(for: item)
            guard seenIDs.insert(trip.id).inserted else {
                return nil
            }
            return trip
        }
    }

    private var authorSavedSpots: [MaplogSpot] {
        var seenIDs: Set<String> = []
        return authorRoutes.flatMap(\.spots).compactMap { spot in
            guard seenIDs.insert(spot.id).inserted else {
                return nil
            }
            return spot
        }
    }

    private var isFollowing: Bool {
        sessionStore.isFollowing(author: post.author)
    }

    private var isBlocked: Bool {
        sessionStore.isBlocked(author: post.author)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    profileHero

                    VStack(spacing: MaplogSpacing.large) {
                        actionButtons
                        if isBlocked {
                            blockedProfileState
                        } else {
                            metricCard
                            profileTabs
                            tabContent
                        }
                    }
                    .padding(MaplogSpacing.large)
                }
            }
            .ignoresSafeArea(edges: .top)

            if let toastText {
                Text(toastText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .background(Color.maplogSurface)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .message:
                MessageComposerSheet(author: post.author) { _ in
                    showToast("\(post.author)에게 메시지를 보냈어요")
                }
                    .presentationDetents([.height(310)])
                    .presentationDragIndicator(.visible)
            case .share:
                ProfileShareSheet(post: post) { message in
                    showToast(message)
                }
                .presentationDetents([.height(334)])
                .presentationDragIndicator(.visible)
            case .report:
                ProfileReportSheet(author: post.author) { reason in
                    showToast("\(reason) 사유로 신고를 접수했어요")
                }
                .presentationDetents([.height(390)])
                .presentationDragIndicator(.visible)
            }
        }
        .confirmationDialog("프로필 옵션", isPresented: $showProfileOptions, titleVisibility: .visible) {
            Button("이 사용자 신고") {
                activeSheet = .report
            }
            Button(isBlocked ? "차단 해제" : "이 사용자 차단", role: isBlocked ? nil : .destructive) {
                toggleBlock()
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text(post.author)
        }
        .background(Color.maplogSurface)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .maplogTabBarHidden()
    }

    private var profileHero: some View {
        ZStack(alignment: .bottomLeading) {
            TravelImageView(style: post.imageStyle, height: 252, cornerRadius: 0, showsSymbol: false)
            LinearGradient(colors: [.black.opacity(0.28), .clear, .black.opacity(0.70)], startPoint: .top, endPoint: .bottom)

            HStack {
                profileCircleButton(systemImage: "chevron.left") {
                    dismiss()
                }
                Spacer()
                profileCircleButton(systemImage: "square.and.arrow.up") {
                    activeSheet = .share
                }
                profileCircleButton(systemImage: "ellipsis") {
                    showProfileOptions = true
                }
            }
            .padding(.horizontal, MaplogSpacing.page)
            .padding(.top, 54)
            .frame(maxHeight: .infinity, alignment: .top)

            VStack(alignment: .leading, spacing: 9) {
                TravelImageView(style: post.place.imageStyle, height: 78, cornerRadius: 39, showsSymbol: false)
                    .frame(width: 78)
                    .overlay(Circle().stroke(Color.maplogLime, lineWidth: 3))

                HStack(spacing: MaplogSpacing.xSmall) {
                    Text(post.author)
                        .font(.system(size: 29, weight: .black))
                        .foregroundStyle(.white)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Color.maplogLime)
                    if isBlocked {
                        Text("차단됨")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Color.maplogOnPrimary)
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .background(Color.maplogLime)
                            .clipShape(Capsule())
                    }
                }

                Text("도시의 짧은 동선과 장소 감도를 기록하는 맵로거")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(2)
            }
            .padding(MaplogSpacing.large)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                if isBlocked {
                    toggleBlock()
                } else {
                    toggleFollow()
                }
            } label: {
                Label(
                    blockAwarePrimaryTitle,
                    systemImage: isBlocked ? "person.crop.circle.badge.checkmark" : (isFollowing ? "checkmark" : "plus")
                )
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isFollowing && !isBlocked ? Color.maplogCanvas : Color.maplogLime)
                    .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                activeSheet = .message
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isBlocked ? Color.maplogMuted : Color.maplogOnPrimary)
                    .frame(width: 54, height: 50)
                    .background(isBlocked ? Color.maplogSurfaceRaised : Color.maplogPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("메시지")
            .disabled(isBlocked)
        }
    }

    private var blockAwarePrimaryTitle: String {
        if isBlocked {
            return "차단 해제"
        }
        return isFollowing ? "팔로잉" : "팔로우"
    }

    private var blockedProfileState: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.maplogMuted)
            Text("차단한 사용자입니다")
                .font(MaplogFont.sectionTitle)
                .foregroundStyle(Color.maplogInk)
            Text("게시물과 저장 루트를 숨겼어요. 차단 해제하면 다시 볼 수 있습니다.")
                .font(MaplogFont.callout)
                .foregroundStyle(Color.maplogMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            Button {
                activeSheet = .report
            } label: {
                Label("추가 신고하기", systemImage: "exclamationmark.bubble.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.maplogCanvas)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(Color.maplogCanvas.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var metricCard: some View {
        HStack {
            profileMetric("게시물", "\(authorPosts.count)")
            profileMetric("팔로워", isFollowing ? "12.9K" : "12.8K")
            profileMetric("루트", "\(authorRoutes.count)")
        }
        .padding(.vertical, 14)
        .maplogCard()
    }

    private var profileTabs: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: MaplogSpacing.xSmall) {
                        Text(tab)
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(selectedTab == tab ? Color.maplogInk : Color.maplogMuted)
                        Capsule()
                            .fill(selectedTab == tab ? Color.maplogLime : .clear)
                            .frame(height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.maplogSurface)
        .zIndex(2)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.maplogLine).frame(height: 1)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        if selectedTab == "맵로그" {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: MaplogSpacing.small) {
                ForEach(authorPosts) { item in
                    NavigationLink {
                        PopularMaplogDetailView(post: item, trip: MockMaplogData.routeTrip(for: item))
                    } label: {
                        VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                            TravelImageView(style: item.imageStyle, height: 168, showsSymbol: false)
                            Text(item.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.maplogInk)
                                .lineLimit(2)
                            Text(item.place.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.maplogMuted)
                        }
                        .padding(MaplogSpacing.xSmall)
                        .maplogCard()
                    }
                    .buttonStyle(.plain)
                }
            }
        } else if selectedTab == "루트" {
            VStack(spacing: MaplogSpacing.small) {
                ForEach(authorRoutes) { trip in
                    NavigationLink {
                        RouteDetailView(trip: trip)
                    } label: {
                        TripCardView(trip: trip, isLarge: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            VStack(spacing: MaplogSpacing.small) {
                ForEach(authorSavedSpots) { spot in
                    NavigationLink {
                        SpotDetailView(spot: spot)
                    } label: {
                        SpotRowCard(spot: spot)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func profileMetric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(Color.maplogInk)
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.maplogMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func profileCircleButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(MaplogFont.cardTitle)
                .foregroundStyle(Color.maplogInk)
                .frame(width: 44, height: 44)
                .background(Color.maplogSurface.opacity(0.92))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            toastText = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            withAnimation(.easeOut(duration: 0.2)) {
                if toastText == message {
                    toastText = nil
                }
            }
        }
    }

    private func toggleFollow() {
        if isFollowing {
            sessionStore.unfollow(author: post.author)
            showToast("팔로우를 취소했어요")
        } else {
            sessionStore.follow(author: post.author)
            showToast("\(post.author)을 팔로우했어요")
        }
    }

    private func toggleBlock() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            if isBlocked {
                sessionStore.unblock(author: post.author)
            } else {
                sessionStore.block(author: post.author)
            }
        }
        showToast(isBlocked ? "차단 목록에 추가했어요" : "차단을 해제했어요")
    }
}

private enum OtherProfileSheet: Identifiable {
    case message
    case share
    case report

    var id: String {
        switch self {
        case .message: return "message"
        case .share: return "share"
        case .report: return "report"
        }
    }
}

private struct ProfileReportSheet: View {
    let author: String
    let onSubmit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason = "스팸/홍보성 콘텐츠"
    @State private var detail = ""

    private let reasons = ["스팸/홍보성 콘텐츠", "부적절한 사진", "허위 장소 정보", "괴롭힘/불쾌한 메시지"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("사용자 신고")
                        .font(MaplogFont.screenTitle)
                        .foregroundStyle(Color.maplogInk)
                    Text(author)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.maplogMuted)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: MaplogSpacing.xSmall) {
                ForEach(reasons, id: \.self) { reason in
                    Button {
                        selectedReason = reason
                    } label: {
                        HStack(spacing: MaplogSpacing.small) {
                            Image(systemName: selectedReason == reason ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(selectedReason == reason ? Color.maplogOlive : Color.maplogMuted)
                            Text(reason)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.maplogInk)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(selectedReason == reason ? Color.maplogLime.opacity(0.18) : Color.maplogCanvas)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField("추가 설명 입력", text: $detail, axis: .vertical)
                .lineLimit(2...3)
                .font(.system(size: 15, weight: .medium))
                .padding(14)
                .background(Color.maplogCanvas)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            PrimaryActionButton("신고 접수", systemImage: "checkmark.shield.fill") {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onSubmit(selectedReason)
                }
            }
        }
        .padding(MaplogSpacing.xLarge)
        .background(Color.maplogSurface)
    }
}

private struct MessageComposerSheet: View {
    let author: String
    let onSend: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var message = "안녕하세요, 맵로그 잘 봤어요!"
    @State private var didSend = false

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("메시지 보내기")
                        .font(MaplogFont.screenTitle)
                        .foregroundStyle(Color.maplogInk)
                    Text(author)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.maplogMuted)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            TextField("메시지를 입력하세요", text: $message, axis: .vertical)
                .lineLimit(3...4)
                .font(.system(size: 16, weight: .medium))
                .padding(14)
                .background(Color.maplogCanvas)
                .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous))

            Button {
                sendMessage()
            } label: {
                Label(didSend ? "전송 완료" : "보내기", systemImage: didSend ? "checkmark" : "paperplane.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(trimmedMessage.isEmpty || didSend ? Color.maplogLine : Color.maplogLime)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(trimmedMessage.isEmpty || didSend)
        }
        .padding(MaplogSpacing.xLarge)
    }

    private func sendMessage() {
        guard !trimmedMessage.isEmpty else { return }
        let sentMessage = trimmedMessage
        didSend = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                onSend(sentMessage)
            }
        }
    }
}

private struct ProfileShareSheet: View {
    let post: VlogPost
    let onAction: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.large) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("프로필 공유")
                        .font(MaplogFont.screenTitle)
                        .foregroundStyle(Color.maplogInk)
                    Text(post.author)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.maplogMuted)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                shareOption(title: "링크", systemImage: "link") {
                    complete("프로필 링크를 복사했어요")
                }
                shareOption(title: "친구", systemImage: "person.2.fill") {
                    complete("친구에게 프로필을 보냈어요")
                }
                shareOption(title: "QR", systemImage: "qrcode") {
                    complete("프로필 QR을 저장했어요")
                }
            }

            HStack(spacing: MaplogSpacing.small) {
                TravelImageView(style: post.place.imageStyle, height: 82, cornerRadius: 41, showsSymbol: false)
                    .frame(width: 82)
                    .overlay(Circle().stroke(Color.maplogLime, lineWidth: 3))
                VStack(alignment: .leading, spacing: 6) {
                    Text(post.author)
                        .font(MaplogFont.sectionTitle)
                        .foregroundStyle(Color.maplogInk)
                    Text("도시의 짧은 동선과 장소 감도를 기록하는 맵로거")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.maplogMuted)
                        .lineLimit(2)
                    Text("루트 42 · 팔로워 3.4k")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.maplogOlive)
                }
                Spacer()
            }
            .padding(MaplogSpacing.small)
            .maplogCard()
        }
        .padding(MaplogSpacing.xLarge)
        .background(Color.maplogSurface)
    }

    private func shareOption(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(MaplogFont.sectionTitle)
                    .foregroundStyle(Color.maplogPrimary)
                    .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                    .contentShape(Rectangle())
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.maplogMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func complete(_ message: String) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onAction(message)
        }
    }
}

struct RouteDetailView: View {
    let trip: MaplogTrip
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @State private var showStartSheet = false
    @State private var showsShareSheet = false
    @State private var toastText: String?

    private var isGuidingRoute: Bool {
        sessionStore.isGuidingRoute(trip)
    }

    private var currentRouteIndex: Int {
        sessionStore.routeProgressIndex(for: trip)
    }

    private var currentRouteSpot: MaplogSpot? {
        guard trip.spots.indices.contains(currentRouteIndex) else {
            return trip.spots.first
        }
        return trip.spots[currentRouteIndex]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    routeTopBar
                    RouteDetailHeroMap(spots: trip.spots, nearbySpots: trip.nearbySpots)

                    VStack(alignment: .leading, spacing: 22) {
                        routeSummary
                        if sessionStore.hasSavedRoute(trip) {
                            savedRouteConfirmation
                        }
                        routeClipSection
                        nearbySpotGrid
                    }
                    .padding(.horizontal, MaplogSpacing.page)
                    .padding(.top, 22)
                    .padding(.bottom, 122)
                    .background(Color.maplogSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .offset(y: -28)
                }
            }

            bottomActionBar

            if let toastText {
                Text(toastText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .background(Color.maplogSurface)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
                    .padding(.bottom, 94)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.maplogSurface)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .maplogTabBarHidden()
        .sheet(isPresented: $showStartSheet) {
            RouteStartSheet(
                trip: trip,
                activeIndex: currentRouteIndex,
                isGuiding: isGuidingRoute,
                onStart: {
                    sessionStore.startRoute(trip)
                    showToast("\(currentRouteSpot?.name ?? trip.title) 안내를 시작했어요")
                },
                onAdvance: {
                    advanceRouteGuide()
                },
                onStop: {
                    sessionStore.stopRoute(trip)
                    showToast("루트 안내를 종료했어요")
                }
            )
                .presentationDetents([.height(isGuidingRoute ? 430 : 360)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsShareSheet) {
            RouteShareSheet(trip: trip) { message in
                showToast(message)
            }
            .presentationDetents([.height(328)])
            .presentationDragIndicator(.visible)
        }
    }

    private var routeTopBar: some View {
        HStack {
            MaplogNavigationButton(systemName: "chevron.left", accessibilityLabel: "뒤로 가기") {
                dismiss()
            }

            Spacer()
            Text("루트 상세")
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(Color.maplogInk)
            Spacer()

            MaplogNavigationButton(systemName: "square.and.arrow.up", accessibilityLabel: "루트 공유") {
                showsShareSheet = true
            }
        }
        .padding(.horizontal, MaplogSpacing.medium)
        .frame(height: 58)
        .background(Color.maplogSurface)
    }

    private var routeSummary: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.medium) {
            VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                Text(trip.title)
                    .font(.system(size: 25, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                Text(trip.subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.maplogMuted)
                    .lineSpacing(4)
            }

            HStack(spacing: 10) {
                TravelImageView(style: trip.coverStyle, height: 38, cornerRadius: 19, showsSymbol: false)
                    .frame(width: 38)
                Text("@jiwon.log")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                Spacer()
                InfoBadge(title: "\(trip.duration) · \(estimatedDistance)", systemImage: "figure.walk")
            }

            HStack(spacing: 10) {
                InfoBadge(title: trip.location, systemImage: "mappin.and.ellipse")
                InfoBadge(title: "\(trip.spots.count)개 장소", systemImage: "number.circle.fill")
                InfoBadge(title: "\(trip.spots.count * 15)초 클립", systemImage: "play.rectangle.fill")
            }
        }
    }

    private var routeClipSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "루트 클립", subtitle: "순서대로 따라가며 장소 정보를 확인하세요")

            VStack(spacing: 0) {
                ForEach(Array(trip.spots.enumerated()), id: \.element.id) { index, spot in
                    NavigationLink {
                        SpotDetailView(spot: spot)
                    } label: {
                        RouteTimelineRow(
                            index: index,
                            spot: spot,
                            isLast: index == trip.spots.count - 1,
                            isActive: isGuidingRoute && index == currentRouteIndex
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var savedRouteConfirmation: some View {
        HStack(spacing: MaplogSpacing.small) {
            Image(systemName: "bookmark.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.maplogPrimary)
            Text("루트가 저장되어 있어요")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.maplogInk)
            Spacer()
        }
        .frame(minHeight: 48)
        .padding(.horizontal, MaplogSpacing.medium)
        .maplogCard()
    }

    private var nearbySpotGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "경로 주변 명소")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: MaplogSpacing.small) {
                ForEach(trip.nearbySpots.isEmpty ? trip.spots : trip.nearbySpots) { spot in
                    NavigationLink {
                        SpotDetailView(spot: spot)
                    } label: {
                        VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                            TravelImageView(style: spot.imageStyle, height: 120, showsSymbol: false)
                            Text(spot.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.maplogInk)
                                .lineLimit(1)
                            Text("\(spot.category) · 1.2KM")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.maplogMuted)
                                .lineLimit(1)
                        }
                        .padding(MaplogSpacing.xSmall)
                        .maplogCard()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var bottomActionBar: some View {
        HStack(spacing: 10) {
            Button {
                toggleRouteSaved()
            } label: {
                Label(sessionStore.hasSavedRoute(trip) ? "저장됨" : "루트 저장", systemImage: sessionStore.hasSavedRoute(trip) ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.maplogOlive)
                    .frame(width: 94, height: 56)
            }
            .buttonStyle(MaplogPressFeedbackStyle())

            Button {
                showStartSheet = true
            } label: {
                Label(isGuidingRoute ? "안내 중 · \(currentRouteIndex + 1)/\(trip.spots.count)" : "지도에서 따라가기", systemImage: "location.north.fill")
                    .font(MaplogFont.cardTitle)
                    .foregroundStyle(Color.maplogOnPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.maplogLime, in: RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, MaplogSpacing.page)
        .padding(.top, 12)
        .padding(.bottom, 22)
        .background(Color.maplogSurface)
    }

    private var estimatedDistance: String {
        trip.spots.count <= 2 ? "2.1km" : "3.4km"
    }

    private func toggleRouteSaved() {
        if sessionStore.hasSavedRoute(trip) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                _ = sessionStore.removeSavedRoute(trip)
            }
            showToast("루트 저장을 해제했어요")
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                _ = sessionStore.saveRoute(trip)
            }
            showToast("루트를 보관함에 저장했어요")
        }
    }

    private func advanceRouteGuide() {
        guard sessionStore.advanceRoute(trip) else {
            sessionStore.stopRoute(trip)
            showToast("루트 안내를 완료했어요")
            return
        }

        let nextIndex = sessionStore.routeProgressIndex(for: trip)
        let nextSpot = trip.spots.indices.contains(nextIndex) ? trip.spots[nextIndex].name : trip.title
        showToast("\(nextSpot) 안내로 이동했어요")
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            toastText = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            withAnimation(.easeOut(duration: 0.2)) {
                if toastText == text {
                    toastText = nil
                }
            }
        }
    }
}

private struct RouteStartSheet: View {
    let trip: MaplogTrip
    let activeIndex: Int
    let isGuiding: Bool
    let onStart: () -> Void
    let onAdvance: () -> Void
    let onStop: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var clampedActiveIndex: Int {
        min(max(activeIndex, 0), max(trip.spots.count - 1, 0))
    }

    private var activeSpot: MaplogSpot? {
        guard trip.spots.indices.contains(clampedActiveIndex) else {
            return trip.spots.first
        }
        return trip.spots[clampedActiveIndex]
    }

    private var isLastStop: Bool {
        clampedActiveIndex >= trip.spots.count - 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.large) {
            HStack(spacing: 14) {
                TravelImageView(style: trip.coverStyle, height: 86, cornerRadius: MaplogRadius.small, showsSymbol: false)
                    .frame(width: 86)
                VStack(alignment: .leading, spacing: 6) {
                    Text("루트 시작")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.maplogOnPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.maplogLime)
                        .clipShape(Capsule())
                    Text(trip.title)
                        .font(MaplogFont.screenTitle)
                        .foregroundStyle(Color.maplogInk)
                    Text("\(trip.spots.count)개 장소 · \(trip.duration)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.maplogMuted)
                }
            }

            VStack(spacing: 10) {
                ForEach(Array(trip.spots.prefix(3).enumerated()), id: \.element.id) { index, spot in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                            .frame(width: 24, height: 24)
                            .background(index == clampedActiveIndex ? Color.maplogLime : Color.maplogCanvas)
                            .clipShape(Circle())
                        Text(spot.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.maplogInk)
                        Spacer()
                        Text(routeStatus(for: index))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(index == clampedActiveIndex ? Color.maplogOlive : Color.maplogMuted)
                    }
                }
            }

            if isGuiding, let activeSpot {
                VStack(alignment: .leading, spacing: 5) {
                    Text("현재 안내")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.maplogOlive)
                    Text(activeSpot.name)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                    Text(activeSpot.summary)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.maplogMuted)
                        .lineLimit(2)
                }
                .padding(14)
                .background(Color.maplogCanvas)
                .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
            }

            PrimaryActionButton(isGuiding ? (isLastStop ? "안내 완료" : "다음 장소로") : "안내 시작", systemImage: isGuiding ? "arrow.turn.down.right" : "location.north.fill") {
                if isGuiding {
                    onAdvance()
                } else {
                    onStart()
                }
                dismiss()
            }

            if isGuiding {
                Button {
                    onStop()
                    dismiss()
                } label: {
                    Text("안내 종료")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.maplogMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.maplogCanvas)
                        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(MaplogSpacing.xLarge)
    }

    private func routeStatus(for index: Int) -> String {
        guard isGuiding else {
            return index == 0 ? "출발" : "다음"
        }
        if index < clampedActiveIndex {
            return "완료"
        }
        if index == clampedActiveIndex {
            return "안내 중"
        }
        return "다음"
    }
}
