import SwiftUI

private enum SearchResultTab: String, CaseIterable {
    case all = "전체"
    case place = "장소"
    case festival = "축제"
    case route = "루트"
    case user = "사용자"
}

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @State private var query = "부산 야경"
    @State private var selectedTab: SearchResultTab = .all
    @State private var toastText: String?

    private let quickTerms = ["부산 야경", "축제", "루트", "카페", "서울 산책", "궁궐", "없는 검색어"]

    private var searchableSpots: [MaplogSpot] {
        MockMaplogData.spots
    }

    private var featuredEvent: FeaturedEvent {
        MockMaplogData.events.first { $0.location == "부산" } ?? MockMaplogData.events[0]
    }

    private var routePost: VlogPost {
        MockMaplogData.searchBusanNightPost
    }

    private var routeTrip: MaplogTrip {
        MockMaplogData.routeTrip(for: routePost)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: MaplogSpacing.xLarge) {
                    topSearchBar
                    tabBar
                    recentSearchSection

                    if shows(.festival) {
                        festivalSection
                    }

                    if shows(.route) {
                        routeSection
                    }

                    if shows(.user) {
                        userSection
                    }

                    if shows(.place) {
                        placesSection
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, MaplogSpacing.xxLarge)
            }
            .contentMargins(.horizontal, MaplogSpacing.page, for: .scrollContent)

            if let toastText {
                Text(toastText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 48)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.maplogCanvas)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .maplogTabBarHidden()
    }

    private var topSearchBar: some View {
        HStack(spacing: MaplogSpacing.small) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 48)
            }
            .buttonStyle(MaplogPressFeedbackStyle())

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("검색어를 입력하세요", text: $query)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit {
                        performSearch(query, message: "검색 결과를 업데이트했어요")
                    }

                Button {
                    query = ""
                    selectedTab = .all
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Color(uiColor: .tertiarySystemFill), in: Circle())
                }
                .buttonStyle(MaplogPressFeedbackStyle())
                .opacity(query.isEmpty ? 0 : 1)
                .disabled(query.isEmpty)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(Color.maplogSurface)
            .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous)
                    .stroke(Color.maplogBorder.opacity(0.82), lineWidth: 1)
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(SearchResultTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.caption.weight(selectedTab == tab ? .bold : .semibold))
                        .foregroundStyle(selectedTab == tab ? Color.maplogInk : Color.maplogMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 36)
                        .background(
                            selectedTab == tab ? Color.maplogLime : .clear,
                            in: RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous)
                        )
                }
                .buttonStyle(MaplogPressFeedbackStyle(pressedScale: 0.98))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
            }
        }
        .padding(4)
        .background(Color.maplogSurface, in: RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous)
                .stroke(Color.maplogBorder.opacity(0.78), lineWidth: 1)
        }
    }

    private var festivalSection: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            SearchSectionHeader(title: "축제", systemImage: "building.columns.fill") {
                selectedTab = .festival
            }

            if festivalResults.isEmpty {
                emptySection(message: "검색어와 맞는 축제가 없어요")
            } else {
                ForEach(festivalResults) { event in
                    ZStack(alignment: .topTrailing) {
                        NavigationLink {
                            FeaturedEventDetailView(event: event)
                        } label: {
                            SearchFestivalCard(
                                event: event,
                                isSaved: sessionStore.hasSavedEvent(event)
                            )
                        }
                            .buttonStyle(MaplogPressFeedbackStyle())

                        Button {
                            toggleEventSave(event)
                        } label: {
                            Image(systemName: sessionStore.hasSavedEvent(event) ? "bookmark.fill" : "bookmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(sessionStore.hasSavedEvent(event) ? AnyShapeStyle(Color.maplogOlive) : AnyShapeStyle(.secondary))
                                .frame(width: 44, height: 44)
                                .background(.regularMaterial, in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(MaplogPressFeedbackStyle())
                        .padding(.top, 14)
                        .padding(.trailing, 12)
                    }
                }
            }
        }
    }

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            SearchSectionHeader(title: "릴스 루트", systemImage: "play.rectangle.fill") {
                selectedTab = .route
            }

            if routeResults.isEmpty {
                emptySection(message: "검색어와 맞는 루트가 없어요")
            } else {
                ZStack(alignment: .topTrailing) {
                    NavigationLink {
                        PopularMaplogDetailView(post: routePost, trip: routeTrip)
                    } label: {
                        SearchRouteCard(
                            post: routePost,
                            isSaved: sessionStore.hasSavedRoute(routeTrip)
                        )
                    }
                    .buttonStyle(MaplogPressFeedbackStyle())

                    Button {
                        toggleRouteSave()
                    } label: {
                        Image(systemName: sessionStore.hasSavedRoute(routeTrip) ? "bookmark.fill" : "bookmark")
                            .font(.body.weight(.bold))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(MaplogPressFeedbackStyle())
                    .padding(MaplogSpacing.small)
                }

                if sessionStore.hasSavedRoute(routeTrip) {
                    NavigationLink {
                        SavedView()
                    } label: {
                        SearchSavedShortcut(title: "루트가 보관함에 저장됨")
                    }
                    .buttonStyle(MaplogPressFeedbackStyle())
                }
            }
        }
    }

    private var userSection: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            SearchSectionHeader(title: "사용자", systemImage: "person") {
                selectedTab = .user
            }

            if userResults.isEmpty {
                emptySection(message: "검색어와 맞는 사용자가 없어요")
            } else {
                SearchUserRow(
                    isFollowing: sessionStore.isFollowing(author: routePost.author),
                    post: routePost
                ) {
                    toggleUserFollow(routePost)
                }
            }
        }
    }

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            SearchSectionHeader(title: selectedTab == .place ? "장소 결과" : "장소", systemImage: "mappin.and.ellipse") {
                selectedTab = .place
            }

            if placeResults.isEmpty {
                emptySearchState
            } else {
                ForEach(placeResults) { spot in
                    ZStack(alignment: .topTrailing) {
                        NavigationLink {
                            SpotDetailView(spot: spot)
                        } label: {
                            SearchPlaceCard(spot: spot)
                        }
                        .buttonStyle(MaplogPressFeedbackStyle())

                        Button {
                            toggleSpotSave(spot)
                        } label: {
                                Image(systemName: sessionStore.hasSavedSpot(spot) ? "heart.fill" : "heart")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(sessionStore.hasSavedSpot(spot) ? AnyShapeStyle(Color.maplogOlive) : AnyShapeStyle(.secondary))
                                .frame(width: 44, height: 44)
                                .background(.regularMaterial, in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(MaplogPressFeedbackStyle())
                        .padding(.top, 12)
                        .padding(.trailing, 10)
                    }
                }
            }

            if selectedTab == .place {
                quickSearchTerms
            }
        }
    }

    private var quickSearchTerms: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Text("추천 검색어")
                .font(.headline)
                .foregroundStyle(.primary)

            FlowChips(items: quickTerms, selectedItem: query.isEmpty ? nil : query) { term in
                performSearch(term, message: "\(term) 결과를 다시 정렬했어요")
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var recentSearchSection: some View {
        if query.isEmpty && !sessionStore.recentSearchTerms.isEmpty {
            VStack(alignment: .leading, spacing: MaplogSpacing.small) {
                HStack {
                    Text("최근 검색")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Button {
                        sessionStore.clearRecentSearchTerms()
                        showToast("최근 검색어를 비웠어요")
                    } label: {
                        Text("전체 삭제")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(MaplogPressFeedbackStyle())
                }

                FlowChips(items: sessionStore.recentSearchTerms, selectedItem: nil) { term in
                    performSearch(term, message: "\(term) 검색으로 돌아왔어요")
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var placeResults: [MaplogSpot] {
        if isNoResultQuery { return [] }

        let terms = query
            .split(separator: " ")
            .map { String($0).lowercased() }

        guard !terms.isEmpty else { return searchableSpots }

        let matched = searchableSpots.filter { spot in
            let haystack = ([spot.name, spot.category, spot.area, spot.summary] + spot.tags)
                .joined(separator: " ")
                .lowercased()
            return terms.allSatisfy { haystack.localizedCaseInsensitiveContains($0) }
        }

        return matched
    }

    private var festivalResults: [FeaturedEvent] {
        if isNoResultQuery { return [] }
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return [featuredEvent]
        }
        let searchable = [featuredEvent]
        return searchable.filter { event in
            searchMatches([event.title, event.location, event.period, "부산 바다축제 해운대 야경 축제"])
        }
    }

    private var routeResults: [VlogPost] {
        isNoResultQuery ? [] : [routePost].filter { post in
            query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || searchMatches([post.title, post.caption, post.place.name] + post.hashtags)
        }
    }

    private var userResults: [VlogPost] {
        isNoResultQuery ? [] : [routePost].filter { post in
            query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || searchMatches(["부산야경러버", post.author, "팔로워 3.4k 루트 42 부산 야경"])
        }
    }

    private var isNoResultQuery: Bool {
        query.localizedCaseInsensitiveContains("없는")
            || query.localizedCaseInsensitiveContains("zz")
            || query.localizedCaseInsensitiveContains("no result")
    }

    private var emptySearchState: some View {
        VStack(spacing: MaplogSpacing.small) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("검색 결과가 없어요")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            Text("추천 검색어를 눌러 다시 탐색해보세요.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                performSearch("부산 야경", message: "부산 야경 결과로 돌아왔어요")
            } label: {
                Text("추천 결과 보기")
                    .font(.headline)
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 48)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())
            }
            .buttonStyle(MaplogPressFeedbackStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, MaplogSpacing.medium)
        .maplogCard(cornerRadius: MaplogRadius.xLarge)
    }

    private func emptySection(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.body.weight(.semibold))
            Text(message)
                .font(.subheadline.weight(.semibold))
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(MaplogSpacing.medium)
        .maplogCard(cornerRadius: MaplogRadius.medium)
    }

    private func searchMatches(_ values: [String]) -> Bool {
        let terms = query
            .split(separator: " ")
            .map { String($0).lowercased() }
        guard !terms.isEmpty else { return true }
        let haystack = values.joined(separator: " ").lowercased()
        return terms.allSatisfy { haystack.localizedCaseInsensitiveContains($0) }
    }

    private func shows(_ tab: SearchResultTab) -> Bool {
        selectedTab == .all || selectedTab == tab
    }

    private func toggleEventSave(_ event: FeaturedEvent) {
        if sessionStore.hasSavedEvent(event) {
            sessionStore.removeSavedEvent(event)
            showToast("축제 저장을 해제했어요")
        } else {
            sessionStore.saveEvent(event)
            showToast("축제를 저장했어요")
        }
    }

    private func toggleRouteSave() {
        if sessionStore.hasSavedRoute(routeTrip) {
            sessionStore.removeSavedRoute(routeTrip)
            showToast("루트 저장을 해제했어요")
        } else {
            sessionStore.saveRoute(routeTrip)
            showToast("루트를 보관함에 저장했어요")
        }
    }

    private func toggleSpotSave(_ spot: MaplogSpot) {
        if sessionStore.hasSavedSpot(spot) {
            sessionStore.removeSavedSpot(spot)
            showToast("장소 찜을 해제했어요")
        } else {
            sessionStore.saveSpot(spot)
            showToast("\(spot.name)을 찜했어요")
        }
    }

    private func toggleUserFollow(_ post: VlogPost) {
        if sessionStore.isFollowing(author: post.author) {
            sessionStore.unfollow(author: post.author)
            showToast("팔로우를 취소했어요")
        } else {
            sessionStore.follow(author: post.author)
            showToast("부산야경러버를 팔로우했어요")
        }
    }

    private func performSearch(_ term: String, message: String) {
        query = term
        selectedTab = .all
        sessionStore.recordSearch(term: term)
        showToast(message)
    }

    private func showToast(_ text: String) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            toastText = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                toastText = nil
            }
        }
    }
}

private struct SearchSectionHeader: View {
    let title: String
    let systemImage: String
    let onMore: () -> Void

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                onMore()
            } label: {
                HStack(spacing: 3) {
                    Text("더보기")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .black))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(minHeight: 44)
            }
            .buttonStyle(MaplogPressFeedbackStyle())
        }
    }
}

private struct SearchFestivalCard: View {
    let event: FeaturedEvent
    let isSaved: Bool

    var body: some View {
        HStack(alignment: .top, spacing: MaplogSpacing.xLarge) {
            Image("event_ocean_film_hero")
                .resizable()
                .scaledToFill()
                .frame(width: 88, height: 108)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))

            VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                Text("진행 중")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.maplogOlive)
                    .padding(.horizontal, MaplogSpacing.xSmall)
                    .frame(height: 24)
                    .background(Color.maplogLime.opacity(0.32), in: Capsule())

                Text(event.location == "부산" ? "부산 바다축제" : event.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Label("해운대해수욕장 일원", systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("야외 영화와 밤바다를 즐기는 특별 프로그램")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        }
        .padding(MaplogSpacing.small)
        .padding(.trailing, 50)
        .maplogCard(cornerRadius: MaplogRadius.large)
        .accessibilityValue(isSaved ? "저장됨" : "저장 안 됨")
    }
}

private struct SearchRouteCard: View {
    let post: VlogPost
    let isSaved: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                Image("search_busan_route")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.16), .black.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Label("1~2초 릴스", systemImage: "play.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, MaplogSpacing.xSmall)
                    .frame(height: 28)
                    .background(.white.opacity(0.92), in: Capsule())
                    .padding(MaplogSpacing.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                    Text(post.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: MaplogSpacing.xSmall) {
                        Label("3개 장소", systemImage: "mappin.and.ellipse")
                        Text("2.4km")
                        Text("40분")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.90))
                }
                .padding(MaplogSpacing.medium)

                Image(systemName: "person.crop.circle.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.34), radius: 4, y: 2)
                    .padding(MaplogSpacing.medium)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 216)
        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous))
        .maplogCard(cornerRadius: MaplogRadius.large, style: .photo)
        .accessibilityValue(isSaved ? "저장됨" : "저장 안 됨")
    }
}

private struct SearchSavedShortcut: View {
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Label(title, systemImage: "bookmark.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("보관함")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Color.maplogMuted)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(Color.maplogSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous)
                .stroke(Color.maplogBorder.opacity(0.72), lineWidth: 1)
        }
    }
}

private struct SearchUserRow: View {
    let isFollowing: Bool
    let post: VlogPost
    let onFollowTapped: () -> Void

    var body: some View {
        HStack(spacing: MaplogSpacing.small) {
            NavigationLink {
                OtherProfileView(post: post)
            } label: {
                HStack(spacing: 13) {
                    Circle()
                        .fill(Color.maplogCanvas)
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(Color.maplogMuted.opacity(0.85))
                        }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("부산야경러버")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("팔로워 3.4k · 루트 42")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(MaplogPressFeedbackStyle())

            Spacer()

            Button {
                onFollowTapped()
            } label: {
                Text(isFollowing ? "팔로잉" : "팔로우")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isFollowing ? Color.maplogInk : .white)
                    .padding(.horizontal, MaplogSpacing.medium)
                    .frame(minHeight: 44)
                    .background(isFollowing ? Color.maplogLime : Color.maplogInk)
                    .clipShape(Capsule())
            }
            .buttonStyle(MaplogPressFeedbackStyle())
        }
        .padding(MaplogSpacing.medium)
        .maplogCard(cornerRadius: MaplogRadius.large)
    }
}

private struct SearchPlaceCard: View {
    let spot: MaplogSpot

    var body: some View {
        HStack(spacing: 14) {
            TravelImageView(
                style: spot.imageStyle,
                height: MaplogSize.listThumbnail,
                cornerRadius: MaplogRadius.medium,
                showsSymbol: false
            )
            .frame(width: MaplogSize.listThumbnail)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: MaplogSpacing.xSmall) {
                    Text(spot.category)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.maplogOlive)
                        .padding(.horizontal, 9)
                        .frame(minHeight: 26)
                        .background(Color.maplogLime.opacity(0.25), in: Capsule())

                    Label(String(format: "%.1f", spot.rating), systemImage: "star.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(spot.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(spot.area)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 44)
        }
        .padding(MaplogSpacing.small)
        .maplogCard(cornerRadius: MaplogRadius.large)
    }
}

struct FlowChips: View {
    let items: [String]
    var selectedItem: String?
    let onSelect: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: MaplogSpacing.xSmall)], alignment: .leading, spacing: MaplogSpacing.xSmall) {
            ForEach(items, id: \.self) { item in
                Button {
                    onSelect(item)
                } label: {
                    ChipView(title: item, isSelected: selectedItem == item)
                }
                .buttonStyle(MaplogPressFeedbackStyle())
            }
        }
    }
}
