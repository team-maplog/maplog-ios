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
                VStack(alignment: .leading, spacing: 22) {
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
                .padding(.horizontal, MaplogSpacing.page)
                .padding(.top, 14)
                .padding(.bottom, 56)
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
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .maplogTabBarHidden()
    }

    private var topSearchBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 34, height: 48)
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.maplogMuted)

                TextField("검색어를 입력하세요", text: $query)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.maplogInk)
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
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.maplogMuted)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .opacity(query.isEmpty ? 0 : 1)
                .disabled(query.isEmpty)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(Color(red: 0.97, green: 0.97, blue: 0.98))
            .clipShape(Capsule())
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 22) {
                ForEach(SearchResultTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 9) {
                            Text(tab.rawValue)
                                .font(.system(size: 16, weight: selectedTab == tab ? .bold : .semibold))
                                .foregroundStyle(selectedTab == tab ? Color.maplogInk : Color.maplogMuted)
                            Capsule()
                                .fill(selectedTab == tab ? Color.maplogLime : .clear)
                                .frame(width: tab == .all ? 36 : 30, height: 3)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.maplogLine)
                .frame(height: 1)
                .padding(.horizontal, -MaplogSpacing.page)
        }
    }

    private var festivalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                        .buttonStyle(.plain)

                        Button {
                            toggleEventSave(event)
                        } label: {
                            Image(systemName: sessionStore.hasSavedEvent(event) ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 21, weight: .bold))
                                .foregroundStyle(sessionStore.hasSavedEvent(event) ? Color.maplogInk : Color.maplogMuted)
                                .frame(width: 42, height: 42)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 14)
                        .padding(.trailing, 12)
                    }
                }
            }
        }
    }

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SearchSectionHeader(title: "Maplog", systemImage: "figure.walk.motion") {
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
                    .buttonStyle(.plain)

                    Button {
                        toggleRouteSave()
                    } label: {
                        Image(systemName: sessionStore.hasSavedRoute(routeTrip) ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                            .frame(width: 38, height: 38)
                            .background(.white.opacity(0.92))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                }

                if sessionStore.hasSavedRoute(routeTrip) {
                    NavigationLink {
                        SavedView()
                    } label: {
                        SearchSavedShortcut(title: "루트가 보관함에 저장됨")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var userSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
        VStack(alignment: .leading, spacing: 12) {
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
                            SpotRowCard(spot: spot)
                        }
                        .buttonStyle(.plain)

                        Button {
                            toggleSpotSave(spot)
                        } label: {
                            Image(systemName: sessionStore.hasSavedSpot(spot) ? "heart.fill" : "heart")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(sessionStore.hasSavedSpot(spot) ? Color.maplogLime : Color.maplogMuted)
                                .frame(width: 42, height: 42)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("추천 검색어")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Color.maplogInk)

            FlowChips(items: quickTerms, selectedItem: query.isEmpty ? nil : query) { term in
                performSearch(term, message: "\(term) 결과를 다시 정렬했어요")
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var recentSearchSection: some View {
        if query.isEmpty && !sessionStore.recentSearchTerms.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("최근 검색")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Color.maplogInk)

                    Spacer()

                    Button {
                        sessionStore.clearRecentSearchTerms()
                        showToast("최근 검색어를 비웠어요")
                    } label: {
                        Text("전체 삭제")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.maplogMuted)
                    }
                    .buttonStyle(.plain)
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
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Color.maplogMuted)
            Text("검색 결과가 없어요")
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(Color.maplogInk)
            Text("추천 검색어를 눌러 다시 탐색해보세요.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.maplogMuted)
                .multilineTextAlignment(.center)
            Button {
                performSearch("부산 야경", message: "부산 야경 결과로 돌아왔어요")
            } label: {
                Text("추천 결과 보기")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 18)
                    .frame(height: 42)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .background(Color.maplogCanvas)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func emptySection(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 18, weight: .bold))
            Text(message)
                .font(.system(size: 14, weight: .bold))
            Spacer()
        }
        .foregroundStyle(Color.maplogMuted)
        .padding(16)
        .background(Color.maplogCanvas)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            toastText = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.2)) {
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
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Color.maplogInk)

            Spacer()

            Button {
                onMore()
            } label: {
                HStack(spacing: 3) {
                    Text("더보기")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .black))
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.maplogMuted)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct SearchFestivalCard: View {
    let event: FeaturedEvent
    let isSaved: Bool

    var body: some View {
        HStack(spacing: 14) {
            TravelImageView(style: .festival, height: 80, cornerRadius: 8, showsSymbol: false)
                .frame(width: 80)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text("진행중")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.maplogOlive)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.maplogLime.opacity(0.32))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                    Text("해운대해수욕장 일원")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.maplogMuted)
                        .lineLimit(1)
                }

                Text(event.location == "부산" ? "부산 바다축제" : event.title)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .lineLimit(1)

                Text("한여름 밤의 짜릿한 축제, 다채로운 공연과 야경을 함께 즐겨보세요.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.maplogMuted)
                    .lineLimit(2)
            }

            Spacer(minLength: 6)

            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(isSaved ? Color.maplogInk : Color.maplogMuted)
        }
        .padding(14)
        .maplogCard()
    }
}

private struct SearchRouteCard: View {
    let post: VlogPost
    let isSaved: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { proxy in
                Image("search_busan_route")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: 168)
                    .clipped()
            }
            .frame(height: 168)
            .clipShape(RoundedRectangle(cornerRadius: MaplogSpacing.cardRadius, style: .continuous))
                .overlay {
                    LinearGradient(colors: [.clear, .black.opacity(0.66)], startPoint: .center, endPoint: .bottom)
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(post.title)
                            .font(.system(size: 19, weight: .black))
                            .foregroundStyle(.white)
                        HStack(spacing: 8) {
                            Label("3컷", systemImage: "camera")
                            Text("2.4km")
                            Text("40분")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                    }
                    .padding(18)
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: isSaved ? "bookmark.fill" : "person.crop.circle.fill")
                        .font(.system(size: isSaved ? 18 : 26, weight: .bold))
                        .foregroundStyle(isSaved ? Color.maplogInk : .white)
                        .frame(width: 34, height: 34)
                        .background(isSaved ? Color.maplogLime : .black.opacity(0.34))
                        .clipShape(Circle())
                        .padding(14)
                }

            HStack(spacing: 10) {
                Label("4.8", systemImage: "star.fill")
                    .foregroundStyle(Color.maplogLime)
                Text("조회 1.2k")
                Text("야경명소")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.maplogMuted)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.maplogCanvas)
                    .clipShape(Capsule())
                Spacer()
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.maplogMuted)
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .maplogCard()
    }
}

private struct SearchSavedShortcut: View {
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Label(title, systemImage: "bookmark.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color.maplogInk)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("보관함")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color.maplogMuted)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Color.maplogMuted)
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(Color.maplogCanvas)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SearchUserRow: View {
    let isFollowing: Bool
    let post: VlogPost
    let onFollowTapped: () -> Void

    var body: some View {
        HStack(spacing: 12) {
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
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                        Text("팔로워 3.4k · 루트 42")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.maplogMuted)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                onFollowTapped()
            } label: {
                Text(isFollowing ? "팔로잉" : "팔로우")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(isFollowing ? Color.maplogInk : .white)
                    .frame(width: 78, height: 38)
                    .background(isFollowing ? Color.maplogLime : Color.maplogInk)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .maplogCard()
    }
}

struct FlowChips: View {
    let items: [String]
    var selectedItem: String?
    let onSelect: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button {
                    onSelect(item)
                } label: {
                    ChipView(title: item, isSelected: selectedItem == item)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
