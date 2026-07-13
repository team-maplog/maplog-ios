import SwiftUI

struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.maplogSelectTab) private var selectTab
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedCategory = "추천"
    @State private var selectedChip = "전체"
    @State private var showsThemeSpots = false
    @State private var showsNearbyRecommendations = false
    @State private var showsLocationPermissionPrompt = false
    @State private var showsCurrentLocationSearch = false
    @State private var categoryDestination: HomeCategoryDestination?
    @State private var chipDestination: HomeChipDestination?
    @State private var homeScrollPosition: String? = "home-intro"

    private let categories = ["여행", "추천", "AI", "테마", "지역", "관광"]
    private let chips = ["전체", "축제", "맛집", "야경", "가족", "자연", "카페", "포토스팟"]
    private let services = [
        ("디지털\n관광주민증", "badge.plus.radiowaves.right"),
        ("대한민국\n반값여행", "percent"),
        ("맛집차트", "fork.knife"),
        ("가볼래-터", "safari")
    ]
    private let aiDigests = MockMaplogData.aiDigests
    private let spotlightEvent = MockMaplogData.spotlightEvent
    private let homeVideos = HomeMaplogThumbnailItem.samples
    private let homePosts = MockMaplogData.posts
    private let nearbyPlaces = HomeNearbyPlace.samples

    private var featuredPost: VlogPost? {
        homePosts.first
    }

    private var discoveryPosts: [VlogPost] {
        Array(homePosts.dropFirst())
    }

    private var homeFestivalEvents: [FeaturedEvent] {
        [spotlightEvent] + MockMaplogData.events
    }

    private var isHomeReelActive: Bool {
        guard let homeScrollPosition else { return false }
        return homeScrollPosition != "home-intro"
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    homeIntro
                        .id("home-intro")

                    ForEach(homePosts) { post in
                        homeMaplogPage(for: post)
                        .frame(maxWidth: .infinity)
                        .containerRelativeFrame(.vertical)
                        .id(post.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.top, 12)
            }
            .scrollPosition(id: $homeScrollPosition, anchor: .top)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .ignoresSafeArea(
                .container,
                edges: isHomeReelActive ? [.top, .bottom] : []
            )
            .onChange(of: homeScrollPosition) { previousPosition, newPosition in
                guard
                    previousPosition == "home-intro",
                    let newPosition,
                    newPosition != "home-intro"
                else {
                    return
                }

                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) {
                    scrollProxy.scrollTo(newPosition, anchor: .top)
                }
            }
        }
        .background(isHomeReelActive ? Color.black : Color(uiColor: .systemBackground))
        .preferredColorScheme(isHomeReelActive ? .dark : nil)
        .maplogReelTabBarStyle(isHomeReelActive)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showsThemeSpots) {
            ThemeSpotsView {
                showsThemeSpots = false
            }
        }
        .navigationDestination(isPresented: $showsNearbyRecommendations) {
            NearbyRecommendationsView {
                showsNearbyRecommendations = false
            }
        }
        .navigationDestination(item: $categoryDestination) { destination in
            categoryDestinationView(for: destination)
        }
        .navigationDestination(item: $chipDestination) { destination in
            chipDestinationView(for: destination)
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

    private var homeIntroContent: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xLarge) {
            homeHeader
                .padding(.horizontal, MaplogSpacing.page)
            weekendFestivalCarousel
        }
        .padding(.bottom, 24)
    }

    private var homeHeader: some View {
        HStack(spacing: MaplogSpacing.small) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Maplog")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Button {
                    if !sessionStore.locationPermissionStatus.isAllowed {
                        showsLocationPermissionPrompt = true
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin.and.ellipse")
                        Text(sessionStore.locationPermissionStatus.isAllowed ? "서울 성수동" : "위치 설정")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityHint("현재 위치 권한 설정을 엽니다")
            }

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

    private var topCategoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.maplogInk)

                ForEach(categories, id: \.self) { category in
                    Button {
                        openCategory(category)
                    } label: {
                        categoryLabel(category)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .contentMargins(.horizontal, 1, for: .scrollContent)
    }

    private func openCategory(_ category: String) {
        selectedCategory = category

        switch category {
        case "여행":
            categoryDestination = .routes
        case "AI":
            categoryDestination = .ai
        case "테마":
            showsThemeSpots = true
        case "지역":
            categoryDestination = .region
        case "관광":
            categoryDestination = .tourism
        default:
            break
        }
    }

    private func categoryLabel(_ category: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(category)
                if category == "AI" {
                    Text("AI")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                }
            }
            .font(.headline.weight(selectedCategory == category ? .bold : .semibold))
            .foregroundStyle(selectedCategory == category ? Color.maplogInk : Color.maplogMuted)

            Rectangle()
                .fill(selectedCategory == category ? Color.maplogLime : .clear)
                .frame(height: 2)
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

    private var searchField: some View {
        MaplogSearchButton(placeholder: "축제, 장소, 루트를 검색해보세요") {
            SearchView()
        }
    }

    private var discoverySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            MaplogSectionHeader(
                "더 둘러보기",
                subtitle: "검색하거나 관심 있는 여행 테마를 골라보세요"
            )
            searchField
            horizontalChips
            secondaryCategoryMenu
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.xLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MaplogRadius.xLarge, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.18), lineWidth: 1)
        }
    }

    private var secondaryCategoryMenu: some View {
        Menu {
            ForEach(categories, id: \.self) { category in
                Button(category) {
                    openCategory(category)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.maplogOlive)
                Text("여행 아이디어 더 보기")
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(Color(uiColor: .tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .accessibilityHint("여행, AI, 테마, 지역, 관광 메뉴를 엽니다")
    }

    private var horizontalChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(chips, id: \.self) { chip in
                    Button {
                        selectedChip = chip
                        openChip(chip)
                    } label: {
                        MaplogFilterChip(title: chip, isSelected: selectedChip == chip)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func openChip(_ chip: String) {
        switch chip {
        case "축제":
            chipDestination = .festivals
        case "맛집":
            showsNearbyRecommendations = true
        case "야경":
            chipDestination = .mapSearch("야경")
        case "가족":
            chipDestination = .mapSearch("가족 여행")
        case "자연":
            chipDestination = .mapSearch("자연 산책")
        case "카페":
            chipDestination = .mapSearch("성수동 카페")
        case "포토스팟":
            chipDestination = .mapSearch("포토스팟")
        default:
            break
        }
    }

    private var weekendFestivalCarousel: some View {
        VStack(alignment: .leading, spacing: 14) {
            MaplogSectionHeader(
                "기록하기 좋은 주말 축제",
                systemImage: "sparkles",
                subtitle: "짧은 클립으로 남기기 좋은 행사"
            ) {
                Button {
                    chipDestination = .festivals
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

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(homeFestivalEvents) { event in
                        NavigationLink {
                            FeaturedEventDetailView(event: event)
                        } label: {
                            HomeFestivalCarouselCard(
                                event: event,
                                isSpotlight: event.id == spotlightEvent.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, MaplogSpacing.page, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
        }
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

    private var maplogClipSection: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            MaplogSectionHeader("릴스 피드", systemImage: "play.rectangle.fill") {
                Button {
                    categoryDestination = .routes
                } label: {
                    Label("전체보기", systemImage: "chevron.right")
                        .font(MaplogFont.caption)
                }
                .buttonStyle(MaplogPressFeedbackStyle(pressedScale: 0.98))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MaplogSpacing.medium) {
                    ForEach(homeVideos) { clip in
                        NavigationLink {
                            SpotDetailView(spot: clip.spot)
                        } label: {
                            HomeMaplogThumbnailCard(clip: clip)
                        }
                        .buttonStyle(MaplogPressFeedbackStyle(pressedScale: 0.98))
                    }
                }
                .padding(.trailing, MaplogSpacing.xLarge)
            }
            .padding(.trailing, -MaplogSpacing.page)
        }
    }

    private var serviceShortcuts: some View {
        HStack(spacing: MaplogSpacing.medium) {
            ForEach(services, id: \.0) { item in
                if item.0.contains("맛집") {
                    Button {
                        showsNearbyRecommendations = true
                    } label: {
                        serviceShortcutLabel(title: item.0, icon: item.1)
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink {
                        serviceDestination(for: item.0)
                    } label: {
                        serviceShortcutLabel(title: item.0, icon: item.1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func homeMaplogPage(for post: VlogPost) -> some View {
        if reduceMotion {
            HomeMaplogClipPager(
                post: post,
                onNext: {
                    showNextHomePost(after: post)
                },
                onReturnHome: returnToHomeIntro
            )
        } else {
            HomeMaplogClipPager(
                post: post,
                onNext: {
                    showNextHomePost(after: post)
                },
                onReturnHome: returnToHomeIntro
            )
            .scrollTransition(.interactive, axis: .vertical) { content, phase in
                content.opacity(phase.isIdentity ? 1 : 0.18)
            }
        }
    }

    private func returnToHomeIntro() {
        guard homeScrollPosition != "home-intro" else { return }

        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
            homeScrollPosition = "home-intro"
        }
    }

    private func showNextHomePost(after post: VlogPost) {
        guard let currentIndex = homePosts.firstIndex(where: { $0.id == post.id }) else {
            return
        }

        let nextIndex = (currentIndex + 1) % homePosts.count
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.32)) {
            homeScrollPosition = homePosts[nextIndex].id
        }
    }

    private var nearbyRecommendationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            MaplogSectionHeader(
                "추천 장소",
                systemImage: "mappin.and.ellipse",
                subtitle: "서울 성수동에서 지금 가볼 만한 곳"
            )

            VStack(spacing: 14) {
                ForEach(nearbyPlaces) { place in
                    NavigationLink {
                        SpotDetailView(spot: place.spot)
                    } label: {
                        HomeNearbyPlaceCard(place: place)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func serviceShortcutLabel(title: String, icon: String) -> some View {
        let accessibilityTitle = title.replacingOccurrences(of: "\n", with: " ")

        return VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.maplogPrimary)
                .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.maplogMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 108, alignment: .top)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTitle)
    }

    private func toggleSpotlightEventSaved() {
        if sessionStore.hasSavedEvent(spotlightEvent) {
            sessionStore.removeSavedEvent(spotlightEvent)
        } else {
            sessionStore.saveEvent(spotlightEvent)
        }
    }

    @ViewBuilder
    private func serviceDestination(for title: String) -> some View {
        let cleanTitle = title.replacingOccurrences(of: "\n", with: " ")
        if title.contains("맛집") {
            NearbyRecommendationsView()
        } else if title.contains("가볼래") {
            RouteLibraryView()
        } else {
            ServiceDetailView(title: cleanTitle)
        }
    }

    @ViewBuilder
    private func categoryDestinationView(for destination: HomeCategoryDestination) -> some View {
        switch destination {
        case .routes:
            RouteLibraryView()
        case .ai:
            AIDigestHubView(digests: aiDigests)
        case .region:
            MapSearchView(query: "서울 성수동")
        case .tourism:
            FestivalListView()
        }
    }

    @ViewBuilder
    private func chipDestinationView(for destination: HomeChipDestination) -> some View {
        switch destination {
        case .festivals:
            FestivalListView()
        case .mapSearch(let query):
            MapSearchView(query: query)
        }
    }

    private var aiSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("AI 여행 요약\n여행기사 · 사용자 후기를 요약했어요.")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.maplogInk)
                .lineSpacing(3)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(aiDigests) { digest in
                        NavigationLink {
                            AIDigestDetailView(digest: digest)
                        } label: {
                            SummaryCard(digest: digest)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

}

private struct HomeFestivalCarouselCard: View {
    let event: FeaturedEvent
    let isSpotlight: Bool

    private var imageName: String {
        if isSpotlight {
            return "home_gwanghwamun_photo"
        }
        return event.thumbnailAssetName ?? event.imageStyle.assetName
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 264, height: 172)
                .clipped()

            LinearGradient(
                colors: [.black.opacity(0.04), .clear, .black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 7) {
                Text("이번 주말")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 26)
                    .background(Color.maplogLime, in: Capsule())

                Spacer()

                Text(event.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Label(event.location, systemImage: "mappin.and.ellipse")
                    Label(event.period, systemImage: "calendar")
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
        .shadow(color: .black.opacity(0.09), radius: 10, x: 0, y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(event.title), \(event.location), \(event.period)")
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
                accessibilityLabel: sessionStore.hasSavedRoute(trip) ? "저장 해제" : "저장"
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
        if sessionStore.hasSavedRoute(trip) {
            sessionStore.removeSavedRoute(trip)
            showToast("저장을 해제했어요")
        } else {
            sessionStore.saveRoute(trip)
            showToast("루트를 저장했어요")
        }
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

private struct HomeMaplogThumbnailItem: Identifiable {
    let id: String
    let title: String
    let author: String
    let duration: String
    let assetName: String?
    let style: PhotoStyle
    let spot: MaplogSpot

    static let samples: [HomeMaplogThumbnailItem] = [
        HomeMaplogThumbnailItem(
            id: "home-vlog-cafe",
            title: "성수동 카페거리 완벽 가이드",
            author: "@seoul_vibe",
            duration: "0:15",
            assetName: "home_clip_seongsu",
            style: .cafe,
            spot: MockMaplogData.forestCafe
        ),
        HomeMaplogThumbnailItem(
            id: "home-vlog-night",
            title: "남산 로맨틱 야경 코스",
            author: "@night_walker",
            duration: "0:32",
            assetName: "home_clip_namsan",
            style: .night,
            spot: MockMaplogData.seoulTower
        ),
        HomeMaplogThumbnailItem(
            id: "home-vlog-date",
            title: "주말 데이트 산책 루트",
            author: "@date_map",
            duration: "0:28",
            assetName: nil,
            style: .forest,
            spot: MockMaplogData.jejuOreum
        )
    ]
}

private struct HomeMaplogThumbnailCard: View {
    let clip: HomeMaplogThumbnailItem

    private var imageName: String {
        clip.assetName ?? clip.style.assetName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
            ZStack(alignment: .topTrailing) {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 140, height: 250)
                    .background(Color.maplogCanvas)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))

                Label(clip.duration, systemImage: "play.fill")
                    .font(MaplogFont.badge)
                    .foregroundStyle(.white)
                    .padding(.horizontal, MaplogSpacing.xSmall)
                    .frame(height: 24)
                    .background(.black.opacity(0.44))
                    .clipShape(Capsule())
                    .padding(MaplogSpacing.xSmall)
            }

            Text(clip.title)
                .font(MaplogFont.callout)
                .foregroundStyle(Color.maplogTextPrimary)
                .lineLimit(2)
                .frame(width: 140, alignment: .leading)

            Text(clip.author)
                .font(MaplogFont.caption)
                .foregroundStyle(Color.maplogTextSecondary)
                .frame(width: 140, alignment: .leading)
        }
    }
}

private struct HomeNearbyPlace: Identifiable {
    let id: String
    let title: String
    let summary: String
    let category: String
    let rating: String
    let distance: String
    let assetName: String?
    let style: PhotoStyle
    let spot: MaplogSpot

    static let samples: [HomeNearbyPlace] = [
        HomeNearbyPlace(
            id: "nearby-dining-wood",
            title: "다이닝 우드",
            summary: "분위기 좋은 모던 한식 파인다이닝",
            category: "맛집",
            rating: "4.8",
            distance: "300m",
            assetName: "nearby_dining",
            style: .cafe,
            spot: MaplogSpot(
                id: "home-nearby-dining-wood",
                name: "다이닝 우드",
                category: "맛집",
                area: "서울 성수동",
                summary: "분위기 좋은 모던 한식 파인다이닝. 조용한 저녁 코스로 추천되는 장소입니다.",
                rating: 4.8,
                imageStyle: .cafe,
                tags: ["맛집", "파인다이닝", "성수동"],
                pinX: 0.44,
                pinY: 0.58
            )
        ),
        HomeNearbyPlace(
            id: "nearby-seoul-forest",
            title: "서울숲 공원",
            summary: "도심 속에서 즐기는 여유로운 산책",
            category: "자연",
            rating: "4.7",
            distance: "800m",
            assetName: nil,
            style: .forest,
            spot: MaplogSpot(
                id: "home-nearby-seoul-forest",
                name: "서울숲 공원",
                category: "자연",
                area: "서울 성동구",
                summary: "도심 속에서 여유롭게 산책하기 좋은 공원. 카페거리와 함께 묶기 좋아요.",
                rating: 4.7,
                imageStyle: .forest,
                tags: ["자연", "산책", "성수동"],
                pinX: 0.54,
                pinY: 0.48
            )
        )
    ]
}

private struct HomeNearbyPlaceCard: View {
    let place: HomeNearbyPlace

    var body: some View {
        HStack(spacing: MaplogSpacing.medium) {
            Group {
                if let assetName = place.assetName {
                    Image(assetName)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(place.style.assetName)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text(place.title)
                    .font(.headline)
                    .foregroundStyle(Color.maplogInk)
                    .lineLimit(2)

                Text(place.summary)
                    .font(.subheadline)
                    .foregroundStyle(Color.maplogMuted)
                    .lineLimit(2)

                HStack(spacing: MaplogSpacing.xSmall) {
                    Label(place.rating, systemImage: "star.fill")
                        .foregroundStyle(Color.maplogLime)
                    Text("•")
                        .foregroundStyle(Color.maplogMuted.opacity(0.65))
                    Text(place.distance)
                        .foregroundStyle(Color.maplogMuted)
                }
                .font(.caption.weight(.semibold))
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            Text(place.category)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.maplogOlive)
                .padding(.horizontal, 9)
                .frame(height: 25)
                .background(Color.maplogLime.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(MaplogSpacing.small)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.maplogLine.opacity(0.7), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.035), radius: 14, x: 0, y: 6)
    }
}

private enum HomeCategoryDestination: Hashable, Identifiable {
    case routes
    case ai
    case region
    case tourism

    var id: String {
        switch self {
        case .routes: return "routes"
        case .ai: return "ai"
        case .region: return "region"
        case .tourism: return "tourism"
        }
    }
}

private enum HomeChipDestination: Hashable, Identifiable {
    case festivals
    case mapSearch(String)

    var id: String {
        switch self {
        case .festivals:
            return "festivals"
        case .mapSearch(let query):
            return "map-search-\(query)"
        }
    }
}

private struct SummaryCard: View {
    let digest: AIDigest

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Text(digest.badge)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, MaplogSpacing.xSmall)
                .padding(.vertical, 5)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            Text(digest.title)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.blue)
                .lineLimit(2)

            Text(digest.summary)
                .font(MaplogFont.callout)
                .foregroundStyle(Color.maplogMuted)
                .lineSpacing(5)
                .lineLimit(6)

            Spacer(minLength: 0)

            Label(digest.readTime, systemImage: "sparkles")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Color.maplogInk)
        }
        .padding(MaplogSpacing.medium)
        .frame(width: 250, height: 230, alignment: .topLeading)
        .maplogCard()
    }
}

private struct AIDigestHubView: View {
    let digests: [AIDigest]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("AI 여행 요약")
                        .font(.system(size: 29, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                    Text("기사와 사용자 후기를 묶어 오늘 바로 볼 만한 여행 힌트로 정리했어요.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.maplogMuted)
                        .lineSpacing(4)
                }

                ForEach(digests) { digest in
                    NavigationLink {
                        AIDigestDetailView(digest: digest)
                    } label: {
                        AIDigestListCard(digest: digest)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(MaplogSpacing.page)
            .padding(.bottom, 116)
        }
        .background(Color.maplogSurface)
        .navigationTitle("AI")
        .navigationBarTitleDisplayMode(.inline)
        .maplogTabBarHidden()
    }
}

private struct AIDigestListCard: View {
    let digest: AIDigest

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TravelImageView(style: digest.imageStyle, height: 168, cornerRadius: 14, showsSymbol: false)
                .overlay(alignment: .topLeading) {
                    Text(digest.badge)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Color.maplogLime)
                        .clipShape(Capsule())
                        .padding(MaplogSpacing.small)
                }

            VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                Text(digest.title)
                    .font(MaplogFont.screenTitle)
                    .foregroundStyle(Color.maplogInk)
                    .lineLimit(2)
                Text(digest.summary)
                    .font(MaplogFont.callout)
                    .foregroundStyle(Color.maplogMuted)
                    .lineSpacing(4)
                    .lineLimit(3)
                HStack(spacing: 10) {
                    Label(digest.source, systemImage: "doc.text.fill")
                    Label(digest.readTime, systemImage: "clock.fill")
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.maplogMuted)
            }
            .padding(.horizontal, 2)
        }
        .padding(14)
        .maplogCard()
    }
}

struct AIDigestDetailView: View {
    let digest: AIDigest
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @State private var toastText: String?

    private var isSaved: Bool {
        sessionStore.hasSavedDigest(digest)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    hero
                    if isSaved {
                        SavedConfirmationCard(
                            title: "저장한 요약에 보관됨",
                            subtitle: "보관함에서 다시 읽고 관련 장소로 이어갈 수 있어요.",
                            buttonTitle: "보관함에서 확인",
                            systemImage: "bookmark.fill"
                        ) {
                            SavedView()
                        }
                    }
                    insightSection
                    relatedSpot
                    mapCTA
                }
                .padding(.horizontal, MaplogSpacing.page)
                .padding(.top, 16)
                .padding(.bottom, 112)
            }

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
        .background(Color.maplogSurface)
        .navigationTitle("AI 여행 요약")
        .navigationBarTitleDisplayMode(.inline)
        .maplogTabBarHidden()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleDigestSaved()
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.maplogInk)
                }
            }
        }
    }

    private var hero: some View {
        TravelImageView(style: digest.imageStyle, height: 250, cornerRadius: 14, showsSymbol: false)
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.74)], startPoint: .top, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(digest.badge)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.maplogLime)
                        .clipShape(Capsule())

                    Text(digest.title)
                        .font(.system(size: 27, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: 10) {
                        Label(digest.source, systemImage: "doc.text.fill")
                        Label(digest.readTime, systemImage: "clock.fill")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                }
                .padding(18)
            }
    }

    private var insightSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "요약", subtitle: digest.summary)

            VStack(spacing: 10) {
                ForEach(Array(digest.points.enumerated()), id: \.offset) { index, point in
                    HStack(alignment: .top, spacing: MaplogSpacing.small) {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                            .frame(width: 30, height: 30)
                            .background(Color.maplogLime)
                            .clipShape(Circle())

                        Text(point)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.maplogInk)
                            .lineSpacing(4)

                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(Color.maplogCanvas)
                    .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
                }
            }
        }
    }

    private var relatedSpot: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "추천 장소", subtitle: "요약과 함께 보면 좋은 장소")

            NavigationLink {
                SpotDetailView(spot: digest.spot)
            } label: {
                HStack(spacing: 14) {
                    TravelImageView(style: digest.spot.imageStyle, height: 82, cornerRadius: 10, showsSymbol: false)
                        .frame(width: 82)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(digest.spot.name)
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                        Text(digest.spot.summary)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.maplogMuted)
                            .lineLimit(2)
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.maplogMuted)
                }
                .padding(MaplogSpacing.small)
                .maplogCard()
            }
            .buttonStyle(.plain)
        }
    }

    private var mapCTA: some View {
        NavigationLink {
            MapSearchView(query: digest.query)
        } label: {
            Label("지도에서 관련 루트 보기", systemImage: "map.fill")
                .font(MaplogFont.cardTitle)
                .foregroundStyle(Color.maplogInk)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.maplogLime)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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

    private func toggleDigestSaved() {
        if isSaved {
            sessionStore.removeSavedDigest(digest)
            showToast("AI 요약 저장을 해제했어요")
        } else {
            sessionStore.saveDigest(digest)
            showToast("AI 요약을 보관함에 저장했어요")
        }
    }
}
