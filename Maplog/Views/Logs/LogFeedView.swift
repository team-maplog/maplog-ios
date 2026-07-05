import SwiftUI

struct LogFeedView: View {
    @Environment(\.maplogSelectTab) private var selectTab
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @State private var selectedMode = "추천"
    @State private var currentPost = MockMaplogData.posts[0]
    @State private var selectedPlaceForSheet: MaplogSpot?
    @State private var selectedProfilePost: VlogPost?
    @State private var selectedCommentPost: VlogPost?
    @State private var sharePost: VlogPost?
    @State private var activeClipIndex = 0
    @State private var actionToast: String?

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

    private var backgroundPost: VlogPost {
        visiblePosts.first ?? currentPost
    }

    private var currentPostIsMine: Bool {
        currentPost.author == "@\(sessionStore.profile.displayName)"
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                TravelImageView(style: backgroundPost.imageStyle, height: proxy.size.height + 20, cornerRadius: 0)
                    .ignoresSafeArea()
                LinearGradient(colors: [.black.opacity(0.12), .black.opacity(0.74)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                    if visiblePosts.isEmpty {
                        Spacer()
                        emptyFeedState
                            .padding(.horizontal, MaplogSpacing.page)
                            .padding(.bottom, 132)
                    } else {
                        Spacer()
                        postMeta
                            .frame(width: max(min(proxy.size.width - 148, 240), 188), alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, MaplogSpacing.page)
                        .padding(.bottom, 108)
                    }
                }

                if !visiblePosts.isEmpty {
                    sideActions
                        .frame(width: 56)
                        .position(x: proxy.size.width - 48, y: proxy.size.height - 300)
                }

                if let actionToast {
                    Text(actionToast)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(.black.opacity(0.78))
                        .clipShape(Capsule())
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 34)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 36)
                    .onEnded { value in
                        guard abs(value.translation.height) > abs(value.translation.width) else { return }
                        switchPost(by: value.translation.height < 0 ? 1 : -1)
                    }
            )
        }
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
                .presentationDetents([.height(430), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $sharePost) { post in
            VlogShareSheet(post: post) { message in
                showToast(message)
            }
                .presentationDetents([.height(360)])
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
        .onAppear {
            moveToFirstVisiblePost(preferFirst: selectedMode == "추천")
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            HStack(spacing: 28) {
                modeButton("팔로잉")
                modeButton("추천")
            }
            Spacer()
            NavigationLink {
                SearchView()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, MaplogSpacing.page)
        .padding(.top, 54)
    }

    private func modeButton(_ title: String) -> some View {
        Button {
            selectedMode = title
            activeClipIndex = 0
            if title == "팔로잉" && unblockedPosts.filter({ sessionStore.isFollowing(author: $0.author) }).isEmpty {
                showToast("팔로우한 맵로거가 아직 없어요")
            }
        } label: {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 19, weight: selectedMode == title ? .bold : .medium))
                    .foregroundStyle(selectedMode == title ? .white : .white.opacity(0.62))
                Circle()
                    .fill(selectedMode == title ? Color.maplogLime : .clear)
                    .frame(width: 6, height: 6)
            }
        }
        .buttonStyle(.plain)
    }

    private var emptyFeedState: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
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
                    .foregroundStyle(Color.maplogInk)
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
        HStack(spacing: 12) {
            TravelImageView(style: post.imageStyle, height: 48, cornerRadius: 24, showsSymbol: false)
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
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 12)
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

    private var postMeta: some View {
        VStack(alignment: .leading, spacing: 13) {
            if currentPostIsMine {
                Button {
                    selectTab(.profile)
                } label: {
                    Text(currentPost.author)
                        .font(.system(size: 21, weight: .black))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    selectedProfilePost = currentPost
                } label: {
                    Text(currentPost.author)
                        .font(.system(size: 21, weight: .black))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }

            Text(currentPost.title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
            Text(currentPost.caption)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)

            HStack(spacing: 8) {
                ForEach(currentPost.hashtags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.18))
                        .clipShape(Capsule())
                }
            }

            Button {
                selectedPlaceForSheet = currentPost.place
            } label: {
                HStack(spacing: 10) {
                    TravelImageView(style: currentPost.place.imageStyle, height: 52, cornerRadius: 8)
                        .frame(width: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentPost.place.name)
                            .font(.system(size: 14, weight: .black))
                        Text(currentPost.place.area)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.maplogMuted)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .black))
                }
                .foregroundStyle(Color.maplogInk)
                .padding(9)
                .background(.white.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            NavigationLink {
                PopularMaplogDetailView(post: currentPost, trip: routeTrip(for: currentPost))
            } label: {
                Label("이 루트 지도에서 보기", systemImage: "map.fill")
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var sideActions: some View {
        VStack(spacing: 22) {
            Button {
                if currentPostIsMine {
                    selectTab(.profile)
                    showToast("내 프로필을 열었어요")
                } else {
                    toggleFollow(for: currentPost)
                }
            } label: {
                VStack(spacing: -4) {
                    Circle()
                        .fill(.white)
                        .frame(width: 52, height: 52)
                        .overlay {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 42))
                                .foregroundStyle(.gray)
                        }
                    Image(systemName: authorBadgeSystemImage)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(authorBadgeForegroundColor)
                        .background(Circle().fill(authorBadgeBackgroundColor))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(authorActionAccessibilityLabel)

            actionButton(
                icon: sessionStore.hasLikedVlogPost(currentPost) ? "heart.fill" : "heart",
                count: likeCountText(for: currentPost),
                tint: sessionStore.hasLikedVlogPost(currentPost) ? Color.maplogLime : .white
            ) {
                toggleLike(for: currentPost)
            }
            actionButton(icon: "message.fill", count: commentCountText(for: currentPost)) {
                selectedCommentPost = currentPost
            }
            actionButton(
                icon: sessionStore.hasSavedRoute(routeTrip(for: currentPost)) ? "bookmark.fill" : "bookmark",
                count: "저장",
                tint: sessionStore.hasSavedRoute(routeTrip(for: currentPost)) ? Color.maplogLime : .white
            ) {
                toggleSave(for: currentPost)
            }
            actionButton(icon: "square.and.arrow.up", count: "공유") {
                sharePost = currentPost
            }
            ZStack {
                Circle()
                    .fill(.black.opacity(0.34))
                    .frame(width: 52, height: 52)
                Circle()
                    .stroke(Color.maplogMuted, lineWidth: 4)
                    .frame(width: 42, height: 42)
                Circle()
                    .fill(Color(red: 0.95, green: 0.20, blue: 0.08))
                    .frame(width: 12, height: 12)
                    .offset(
                        x: CGFloat(activeClipIndex % 2 == 0 ? 0 : 8),
                        y: CGFloat(activeClipIndex % 2 == 0 ? 0 : -6)
                    )
            }
            .onTapGesture {
                activeClipIndex = (activeClipIndex + 1) % 4
                showToast("\(activeClipIndex + 1)번째 클립 재생 중")
            }
        }
        .foregroundStyle(.white)
    }

    private var authorBadgeSystemImage: String {
        if currentPostIsMine {
            return "checkmark.seal.fill"
        }
        return sessionStore.isFollowing(author: currentPost.author) ? "checkmark.circle.fill" : "plus.circle.fill"
    }

    private var authorBadgeForegroundColor: Color {
        currentPostIsMine || sessionStore.isFollowing(author: currentPost.author) ? .white : Color.maplogLime
    }

    private var authorBadgeBackgroundColor: Color {
        currentPostIsMine || sessionStore.isFollowing(author: currentPost.author) ? Color.maplogLime : .clear
    }

    private var authorActionAccessibilityLabel: String {
        if currentPostIsMine {
            return "내 프로필 열기"
        }
        return sessionStore.isFollowing(author: currentPost.author) ? "\(currentPost.author) 언팔로우" : "\(currentPost.author) 팔로우"
    }

    private func actionButton(icon: String, count: String, tint: Color = .white, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(tint)
                Text(count)
                    .font(.system(size: 12, weight: .bold))
            }
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

    private func switchPost(by offset: Int) {
        let posts = visiblePosts
        guard !posts.isEmpty else { return }
        let currentIndex = posts.firstIndex(where: { $0.id == currentPost.id }) ?? 0
        let nextIndex = (currentIndex + offset + posts.count) % posts.count
        currentPost = posts[nextIndex]
        activeClipIndex = 0
        showToast(offset > 0 ? "다음 맵로그를 보고 있어요" : "이전 맵로그를 보고 있어요")
    }

    private func moveToFirstVisiblePost(preferFirst: Bool = false) {
        guard let firstPost = visiblePosts.first else {
            return
        }

        guard preferFirst || !visiblePosts.contains(where: { $0.id == currentPost.id }) else {
            return
        }

        currentPost = firstPost
        activeClipIndex = 0
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
                    .background(.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
                    .padding(.bottom, 106)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            routeTopBar
        }
        .background(Color.white)
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
            Button {
                close()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()
            Text("루트 상세")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.maplogInk)
            Spacer()

            Button {
                showsShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 48)
        .frame(height: 106)
        .background(.white)
    }

    private var header: some View {
        TravelImageView(style: post.imageStyle, height: 286, cornerRadius: 0, showsSymbol: false)
            .padding(.top, 106)
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .top, endPoint: .bottom)
                    .padding(.top, 106)
            }
            .overlay {
                Image(systemName: "play.fill")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 82, height: 82)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .padding(.top, 106)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(post.title)
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    HStack(spacing: 12) {
                        Label("\(routeStops.count)개 장소", systemImage: "mappin.and.ellipse")
                        Label("2.5km", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                        Label(trip.duration, systemImage: "clock")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
                }
                .padding(20)
            }
    }

    private var itinerary: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("루트 일정")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Color.maplogInk)

            VStack(spacing: 0) {
                ForEach(Array(routeStops.enumerated()), id: \.element.id) { index, stop in
                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(index == 0 ? Color.maplogLime : Color.maplogLine)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().stroke(.white, lineWidth: 3))
                            Rectangle()
                                .fill(index == routeStops.count - 1 ? .clear : Color.maplogLine)
                                .frame(width: 2, height: 104)
                        }
                        .frame(width: 20)

                        NavigationLink {
                            SpotDetailView(spot: stop.spot)
                        } label: {
                            HStack(spacing: 14) {
                                TravelImageView(style: stop.spot.imageStyle, height: 78, cornerRadius: 8, showsSymbol: false)
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
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 6)
                                            .background(Color.maplogCanvas)
                                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    }

                                    Text(stop.subtitle)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.maplogMuted)
                                        .lineLimit(1)

                                    Label("지도에서 보기", systemImage: "map")
                                        .font(.system(size: 13, weight: .black))
                                        .foregroundStyle(Color.maplogOlive)
                                }
                            }
                            .padding(14)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 8)
                            .overlay {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Color.maplogLine, lineWidth: 1)
                            }
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
        SavedConfirmationCard(
            title: "루트가 보관함에 저장됨",
            subtitle: "보관함에서 이 동선과 방문 순서를 다시 열 수 있어요.",
            buttonTitle: "보관함에서 확인",
            systemImage: "bookmark.fill"
        ) {
            SavedView()
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
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
                .frame(width: 128, height: 82)
                .background(Color.maplogCanvas)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            NavigationLink {
                RouteDetailView(trip: trip)
            } label: {
                Label("따라가기 시작", systemImage: "play.circle.fill")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 82)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, MaplogSpacing.page)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .background(.white)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.maplogLine).frame(height: 1)
        }
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
                        .background(.white)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.14), radius: 16, x: 0, y: 8)
                        .padding(.bottom, 94)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(Color.maplogInk)
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
            .overlay(Color.black.opacity(0.48))
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
                                        .foregroundStyle(Color.maplogInk)
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
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(Color.maplogCanvas)
                        .clipShape(Capsule())
                }

                Label("\(spot.area) · 계동길 5", systemImage: "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.maplogMuted)

                HStack(spacing: 8) {
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
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, MaplogSpacing.page)
            .padding(.bottom, 18)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.24), radius: 28, x: 0, y: -10)
    }

    private var reviewBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(Color.maplogLine)
                .frame(height: 1)

            HStack(alignment: .top, spacing: 12) {
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
                        .font(.system(size: 14, weight: .medium))
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

            HStack(spacing: 12) {
                ForEach(relatedPosts.prefix(2)) { item in
                    NavigationLink {
                        PopularMaplogDetailView(post: item, trip: MockMaplogData.routeTrip(for: item))
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            TravelImageView(style: item.imageStyle, height: 122, cornerRadius: 12, showsSymbol: false)
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
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Color.maplogInk)
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
        .background(.white)
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
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.54))
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

private struct VlogCommentsSheet: View {
    let post: VlogPost
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @State private var draft = ""

    private var baseCommentCount: Int {
        Int(post.comments.filter(\.isNumber)) ?? 0
    }

    private var totalCommentCount: Int {
        baseCommentCount + sessionStore.vlogCommentCount(for: post.id)
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

    private let avatarLetters = [
        "채", "민", "서", "준", "아"
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("댓글")
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                        Text("\(totalCommentCount)개의 반응")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.maplogMuted)
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                            .frame(width: 36, height: 36)
                            .background(Color.maplogCanvas)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(Array(comments.enumerated()), id: \.element.id) { index, comment in
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(Color.maplogCanvas)
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        Text(comment.isMine ? String(sessionStore.profile.displayName.prefix(1)) : avatarLetters[index % avatarLetters.count])
                                            .font(.system(size: 15, weight: .black))
                                            .foregroundStyle(Color.maplogInk)
                                    }

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(comment.author)
                                        .font(.system(size: 13, weight: .black))
                                        .foregroundStyle(Color.maplogInk)
                                    Text(comment.body)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Color.maplogInk)
                                }
                                Spacer()
                                Text(comment.timeText)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.maplogMuted)
                            }
                            .padding(.horizontal, MaplogSpacing.page)
                        }
                    }
                    .padding(.bottom, 18)
                }

                HStack(spacing: 10) {
                    TextField("댓글을 입력하세요", text: $draft)
                        .font(.system(size: 15, weight: .medium))
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(Color.maplogCanvas)
                        .clipShape(Capsule())

                    Button {
                        guard sessionStore.addVlogComment(postID: post.id, body: draft) != nil else { return }
                        draft = ""
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                            .frame(width: 48, height: 48)
                            .background(Color.maplogLime)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                }
                .padding(20)
                .background(.white)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.maplogLine).frame(height: 1)
                }
            }
            .background(Color.white)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct VlogShareSheet: View {
    let post: VlogPost
    let onAction: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("공유")
                        .font(.system(size: 24, weight: .black))
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
                        .frame(width: 36, height: 36)
                        .background(Color.maplogCanvas)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
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

            HStack(spacing: 12) {
                TravelImageView(style: post.imageStyle, height: 92, cornerRadius: 12, showsSymbol: false)
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
            .padding(12)
            .maplogCard()
        }
        .padding(24)
        .background(Color.white)
    }

    private func shareOption(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 52, height: 52)
                    .background(Color.maplogCanvas)
                    .clipShape(Circle())
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

                    VStack(spacing: 20) {
                        actionButtons
                        if isBlocked {
                            blockedProfileState
                        } else {
                            metricCard
                            profileTabs
                            tabContent
                        }
                    }
                    .padding(20)
                }
            }
            .ignoresSafeArea(edges: .top)

            if let toastText {
                Text(toastText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .background(.white)
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
        .background(Color.white)
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

                HStack(spacing: 8) {
                    Text(post.author)
                        .font(.system(size: 29, weight: .black))
                        .foregroundStyle(.white)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Color.maplogLime)
                    if isBlocked {
                        Text("차단됨")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Color.maplogInk)
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
            .padding(20)
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
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                activeSheet = .message
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isBlocked ? Color.maplogMuted : Color.maplogInk)
                    .frame(width: 54, height: 50)
                    .background(Color.maplogCanvas)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Color.maplogInk)
            Text("게시물과 저장 루트를 숨겼어요. 차단 해제하면 다시 볼 수 있습니다.")
                .font(.system(size: 14, weight: .medium))
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
                    VStack(spacing: 8) {
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
        .background(Color.white)
        .zIndex(2)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.maplogLine).frame(height: 1)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        if selectedTab == "맵로그" {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(authorPosts) { item in
                    NavigationLink {
                        PopularMaplogDetailView(post: item, trip: MockMaplogData.routeTrip(for: item))
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            TravelImageView(style: item.imageStyle, height: 168, showsSymbol: false)
                            Text(item.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.maplogInk)
                                .lineLimit(2)
                            Text(item.place.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.maplogMuted)
                        }
                        .padding(8)
                        .maplogCard()
                    }
                    .buttonStyle(.plain)
                }
            }
        } else if selectedTab == "루트" {
            VStack(spacing: 12) {
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
            VStack(spacing: 12) {
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
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.42))
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
                        .font(.system(size: 24, weight: .black))
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
                        .frame(width: 36, height: 36)
                        .background(Color.maplogCanvas)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 8) {
                ForEach(reasons, id: \.self) { reason in
                    Button {
                        selectedReason = reason
                    } label: {
                        HStack(spacing: 12) {
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
        .padding(24)
        .background(Color.white)
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
                        .font(.system(size: 22, weight: .black))
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
                        .frame(width: 36, height: 36)
                        .background(Color.maplogCanvas)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            TextField("메시지를 입력하세요", text: $message, axis: .vertical)
                .lineLimit(3...4)
                .font(.system(size: 16, weight: .medium))
                .padding(14)
                .background(Color.maplogCanvas)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

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
        .padding(24)
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
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("프로필 공유")
                        .font(.system(size: 24, weight: .black))
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
                        .frame(width: 36, height: 36)
                        .background(Color.maplogCanvas)
                        .clipShape(Circle())
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

            HStack(spacing: 12) {
                TravelImageView(style: post.place.imageStyle, height: 82, cornerRadius: 41, showsSymbol: false)
                    .frame(width: 82)
                    .overlay(Circle().stroke(Color.maplogLime, lineWidth: 3))
                VStack(alignment: .leading, spacing: 6) {
                    Text(post.author)
                        .font(.system(size: 20, weight: .black))
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
            .padding(12)
            .maplogCard()
        }
        .padding(24)
        .background(Color.white)
    }

    private func shareOption(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 54, height: 54)
                    .background(Color.maplogCanvas)
                    .clipShape(Circle())
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
                    RouteDetailHeroMap(spots: trip.spots)

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
                    .background(.white)
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
                    .background(.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
                    .padding(.bottom, 94)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.white)
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
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()
            Text("루트 상세")
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(Color.maplogInk)
            Spacer()

            Button {
                showsShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 58)
        .background(.white)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.maplogLine).frame(height: 1)
        }
    }

    private var routeSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
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
        SavedConfirmationCard(
            title: "루트가 보관함에 저장됨",
            subtitle: "보관함에서 이 동선과 방문 순서를 다시 열 수 있어요.",
            buttonTitle: "보관함에서 확인",
            systemImage: "bookmark.fill"
        ) {
            SavedView()
        }
    }

    private var nearbySpotGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "경로 주변 명소")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(trip.spots) { spot in
                    NavigationLink {
                        SpotDetailView(spot: spot)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
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
                        .padding(8)
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
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 126, height: 56)
                    .background(Color.maplogCanvas)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                showStartSheet = true
            } label: {
                Label(isGuidingRoute ? "안내 중 · \(currentRouteIndex + 1)/\(trip.spots.count)" : "지도에서 따라가기", systemImage: "location.north.fill")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, MaplogSpacing.page)
        .padding(.top, 12)
        .padding(.bottom, 22)
        .background(.white)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.maplogLine).frame(height: 1)
        }
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
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                TravelImageView(style: trip.coverStyle, height: 86, cornerRadius: 8, showsSymbol: false)
                    .frame(width: 86)
                VStack(alignment: .leading, spacing: 6) {
                    Text("루트 시작")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.maplogLime)
                        .clipShape(Capsule())
                    Text(trip.title)
                        .font(.system(size: 22, weight: .black))
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
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
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
