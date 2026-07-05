import SwiftUI

struct HomeView: View {
    @Environment(\.maplogSelectTab) private var selectTab
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedCategory = "추천"
    @State private var selectedChip = "전체"
    @State private var showsThemeSpots = false
    @State private var showsNearbyRecommendations = false
    @State private var showsLocationPermissionPrompt = false
    @State private var categoryDestination: HomeCategoryDestination?
    @State private var chipDestination: HomeChipDestination?

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
    private let homeVideos = HomeMaplogClip.samples
    private let nearbyPlaces = HomeNearbyPlace.samples

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                homeHeader
                searchField
                horizontalChips
                weekendRecommendation
                maplogClipSection
                nearbyRecommendationSection
            }
            .padding(.horizontal, MaplogSpacing.page)
            .padding(.top, 8)
            .maplogListBottomPadding()
        }
        .background(Color.white)
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
        .sheet(isPresented: $showsLocationPermissionPrompt) {
            LocationPermissionPromptSheet(
                onAllow: {
                    sessionStore.allowLocationPermission()
                },
                onSkip: {
                    sessionStore.skipLocationPermission()
                }
            )
            .presentationDetents([.height(384)])
            .presentationDragIndicator(.hidden)
        }
    }

    private var homeHeader: some View {
        HStack(spacing: 12) {
            Button {
                selectTab(.profile)
            } label: {
                Image("home_profile_avatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.maplogLine, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("마이페이지로 이동")

            VStack(alignment: .leading, spacing: 2) {
                Text("좋은 저녁이에요")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.maplogMuted)
                Button {
                    if !sessionStore.locationPermissionStatus.isAllowed {
                        showsLocationPermissionPrompt = true
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text("서울 성수동")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.maplogInk)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            NavigationLink {
                NotificationsView()
            } label: {
                Image(systemName: "bell")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.maplogMuted)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
        }
    }

    private var topCategoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 22) {
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
            .padding(.top, 14)
        }
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
            .font(.system(size: 17, weight: selectedCategory == category ? .bold : .semibold))
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
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: 46, height: 46)
                        .background(Color.maplogCanvas)
                        .clipShape(Circle())
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

    private var weekendRecommendation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("이번 주말, 여기 어때요?")
                .font(MaplogFont.screenTitle)
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
                .padding(16)
            }
        }
    }

    private var serviceShortcuts: some View {
        HStack(spacing: 16) {
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

    private var maplogClipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MaplogSectionHeader("Maplog", systemImage: "film.stack") {
                Button {
                    categoryDestination = .routes
                } label: {
                    HStack(spacing: 4) {
                        Text("전체보기")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(homeVideos) { clip in
                        NavigationLink {
                            SpotDetailView(spot: clip.spot)
                        } label: {
                            HomeMaplogClipCard(clip: clip)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 18)
            }
            .padding(.trailing, -MaplogSpacing.page)
        }
    }

    private var nearbyRecommendationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            MaplogSectionHeader("내 주변 추천 장소")

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
                .foregroundStyle(Color.maplogOlive)
                .frame(width: 58, height: 58)
                .background(.white)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.maplogLine, lineWidth: 1))
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

private struct HomeWeekendCard: View {
    let event: FeaturedEvent

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image("home_gwanghwamun_photo")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 438)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.24), .black.opacity(0.88)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

            VStack(alignment: .leading, spacing: 11) {
                Text("오늘 진행 중")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 12)
                    .frame(height: 25)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())

                Spacer()

                Text("서울라이트 광화문")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)

                Text("전통과 현대가 만나는 빛의 축제. 이번 주말까지만 진행되는 특별한 야경을 놓치지 마세요.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineSpacing(4)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label("4.9", systemImage: "star.fill")
                        .foregroundStyle(Color.maplogLime)
                    Text("•")
                        .foregroundStyle(.white.opacity(0.5))
                    Text("서울 종로구")
                        .foregroundStyle(.white.opacity(0.86))
                }
                .font(.system(size: 14, weight: .semibold))
            }
            .padding(18)
        }
        .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 10)
    }
}

private struct HomeMaplogClip: Identifiable {
    let id: String
    let title: String
    let author: String
    let duration: String
    let assetName: String?
    let style: PhotoStyle
    let spot: MaplogSpot

    static let samples: [HomeMaplogClip] = [
        HomeMaplogClip(
            id: "home-vlog-cafe",
            title: "성수동 카페거리 완벽 가이드",
            author: "@seoul_vibe",
            duration: "0:15",
            assetName: "home_clip_seongsu",
            style: .cafe,
            spot: MockMaplogData.forestCafe
        ),
        HomeMaplogClip(
            id: "home-vlog-night",
            title: "남산 로맨틱 야경 코스",
            author: "@night_walker",
            duration: "0:32",
            assetName: "home_clip_namsan",
            style: .night,
            spot: MockMaplogData.seoulTower
        ),
        HomeMaplogClip(
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

private struct HomeMaplogClipCard: View {
    let clip: HomeMaplogClip
    private var imageName: String {
        clip.assetName ?? clip.style.assetName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topTrailing) {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 140, height: 250)
                    .background(Color.maplogCanvas)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    }

                Label(clip.duration, systemImage: "play.fill")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(.black.opacity(0.44))
                    .clipShape(Capsule())
                    .padding(8)
            }

            Text(clip.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.maplogInk)
                .lineLimit(2)
                .frame(width: 140, alignment: .leading)

            Text(clip.author)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.maplogMuted)
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
        HStack(spacing: 16) {
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
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text(place.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.maplogInk)
                    .lineLimit(1)

                Text(place.summary)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.maplogMuted)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(place.rating, systemImage: "star.fill")
                        .foregroundStyle(Color.maplogLime)
                    Text("•")
                        .foregroundStyle(Color.maplogMuted.opacity(0.65))
                    Text(place.distance)
                        .foregroundStyle(Color.maplogMuted)
                }
                .font(.system(size: 12, weight: .semibold))
            }

            Spacer(minLength: 0)

            Text(place.category)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.maplogOlive)
                .padding(.horizontal, 9)
                .frame(height: 25)
                .background(Color.maplogLime.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(12)
        .background(.white)
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
        VStack(alignment: .leading, spacing: 12) {
            Text(digest.badge)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            Text(digest.title)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.blue)
                .lineLimit(2)

            Text(digest.summary)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.maplogMuted)
                .lineSpacing(5)
                .lineLimit(6)

            Spacer(minLength: 0)

            Label(digest.readTime, systemImage: "sparkles")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Color.maplogInk)
        }
        .padding(16)
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
        .background(Color.white)
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
                        .padding(12)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(digest.title)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .lineLimit(2)
                Text(digest.summary)
                    .font(.system(size: 14, weight: .medium))
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
                    .background(.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.white)
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
                    HStack(alignment: .top, spacing: 12) {
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
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                .padding(12)
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
                .font(.system(size: 17, weight: .black))
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
