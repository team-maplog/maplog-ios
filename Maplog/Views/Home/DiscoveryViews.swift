import SwiftUI

private struct ThemeSpot: Identifiable {
    let id: String
    let badge: String
    let title: String
    let summary: String
    let distance: String
    let style: PhotoStyle
    let count: String
    let spot: MaplogSpot
}

struct ThemeSpotsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    let onBack: (() -> Void)?
    @State private var showsAlertSettings = false
    @State private var themeAlertEnabled = false
    @State private var alertFrequency = "오픈 전날"
    @State private var toastText: String?

    init(onBack: (() -> Void)? = nil) {
        self.onBack = onBack
    }

    private let themes: [ThemeSpot] = [
        ThemeSpot(
            id: "theme-ader-error",
            badge: "인기",
            title: "Ader Error x Zara 성수",
            summary: "감각적인 미디어 아트와 함께하는 한정판 콜라보레이션 팝업. 예약 필수!",
            distance: "0.5km",
            style: .city,
            count: "342개 맵로그",
            spot: MaplogSpot(
                id: "theme-ader-error-spot",
                name: "Ader Error x Zara 성수",
                category: "팝업",
                area: "서울 성동구",
                summary: "감각적인 미디어 아트와 함께하는 한정판 콜라보레이션 팝업. 주말 성수동 코스로 저장하기 좋은 핫플.",
                rating: 4.8,
                imageStyle: .city,
                tags: ["성수동", "팝업스토어", "예약"],
                pinX: 0.36,
                pinY: 0.52
            )
        ),
        ThemeSpot(
            id: "theme-tamburins",
            badge: "신규",
            title: "탬버린즈 플래그십 스토어",
            summary: "새로운 향수 컬렉션 런칭 기념 특별 전시. 다채로운 시향 공간 마련.",
            distance: "1.2km",
            style: .market,
            count: "128개 맵로그",
            spot: MaplogSpot(
                id: "theme-tamburins-spot",
                name: "탬버린즈 플래그십 스토어",
                category: "뷰티",
                area: "서울 성동구",
                summary: "향과 오브제가 이어지는 플래그십 전시 공간. 신상 컬렉션과 포토존을 함께 둘러보기 좋다.",
                rating: 4.7,
                imageStyle: .market,
                tags: ["성수동", "향수", "전시"],
                pinX: 0.42,
                pinY: 0.48
            )
        ),
        ThemeSpot(
            id: "theme-bluebottle",
            badge: "마감임박",
            title: "블루보틀 커피 트럭 성수",
            summary: "성수동 골목길에 깜짝 등장한 블루보틀 커피 트럭. 한정판 굿즈 판매.",
            distance: "0.8km",
            style: .forest,
            count: "89개 맵로그",
            spot: MaplogSpot(
                id: "theme-bluebottle-spot",
                name: "블루보틀 커피 트럭 성수",
                category: "카페",
                area: "서울 성동구",
                summary: "성수동 골목 안에서 만나는 커피 트럭. 산책 중 들러 한정 굿즈와 커피를 챙기기 좋은 코스.",
                rating: 4.6,
                imageStyle: .forest,
                tags: ["성수동", "커피", "굿즈"],
                pinX: 0.30,
                pinY: 0.61
            )
        )
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: MaplogSpacing.large) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("인기 테마")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(Color.maplogLime)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 7)
                                .background(.black)
                                .clipShape(Capsule())
                            Text("지금 가장 핫한 성수동 팝업스토어")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(Color.maplogInk)
                            Text("주말 데이트 코스로 딱 좋은 성수동 신상 핫플 모음. 생생한 숏폼으로 미리 만나보세요.")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.maplogMuted)
                                .lineSpacing(4)
                        }

                        ForEach(themes) { theme in
                            ZStack(alignment: .bottomTrailing) {
                                NavigationLink {
                                    SpotDetailView(spot: theme.spot)
                                } label: {
                                    ThemeSpotCard(
                                        theme: theme,
                                        isSaved: sessionStore.hasSavedSpot(theme.spot)
                                    )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    toggleSave(theme)
                                } label: {
                                    Image(systemName: sessionStore.hasSavedSpot(theme.spot) ? "bookmark.fill" : "bookmark")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(sessionStore.hasSavedSpot(theme.spot) ? Color.maplogInk : Color.maplogMuted)
                                        .frame(width: 42, height: 42)
                                        .background(sessionStore.hasSavedSpot(theme.spot) ? Color.maplogLime : Color.maplogCanvas)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .padding(MaplogSpacing.medium)
                            }
                        }
                    }
                    .padding(.horizontal, MaplogSpacing.page)
                    .padding(.top, 28)
                    .maplogListBottomPadding()
                }
            }

            if let toastText {
                DiscoveryToastView(text: toastText)
                    .padding(.bottom, 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.maplogSurface)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showsAlertSettings) {
            ThemeAlertSettingsSheet(
                isEnabled: $themeAlertEnabled,
                frequency: $alertFrequency
            ) { message in
                showToast(message)
            }
            .presentationDetents([.height(360)])
            .presentationDragIndicator(.visible)
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()
            Text("Maplog")
                .font(MaplogFont.sectionTitle)
                .foregroundStyle(Color.maplogOlive)
            Spacer()

            Button {
                showsAlertSettings = true
            } label: {
                Image(systemName: themeAlertEnabled ? "bell.fill" : "bell")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(themeAlertEnabled ? Color.maplogInk : Color.maplogMuted)
                    .frame(width: 44, height: 44)
                    .background(themeAlertEnabled ? Color.maplogLime : .clear)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(height: 58)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.maplogLine).frame(height: 1)
        }
    }

    private func toggleSave(_ theme: ThemeSpot) {
        if sessionStore.hasSavedSpot(theme.spot) {
            sessionStore.removeSavedSpot(theme.spot)
            showToast("테마 저장을 해제했어요")
        } else {
            sessionStore.saveSpot(theme.spot)
            showToast("테마를 보관함에 저장했어요")
        }
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

    private func goBack() {
        if let onBack {
            onBack()
            return
        }
        dismiss()
        presentationMode.wrappedValue.dismiss()
    }
}

private struct ThemeAlertSettingsSheet: View {
    @Binding var isEnabled: Bool
    @Binding var frequency: String
    let onDone: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private let options = ["오픈 전날", "오픈 1시간 전", "마감 전날"]

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.large) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("팝업 알림")
                        .font(MaplogFont.screenTitle)
                        .foregroundStyle(Color.maplogInk)
                    Text("성수동 신상 테마가 열리거나 마감되기 전에 알려드릴게요.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.maplogMuted)
                        .lineLimit(2)
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

            Toggle(isOn: $isEnabled) {
                Label("새 팝업 알림 받기", systemImage: isEnabled ? "bell.fill" : "bell")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Color.maplogInk)
            }
            .tint(Color.maplogLime)
            .padding(14)
            .background(Color.maplogCanvas)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 10) {
                ForEach(options, id: \.self) { option in
                    Button {
                        isEnabled = true
                        frequency = option
                    } label: {
                        Text(option)
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(frequency == option ? Color.maplogInk : Color.maplogMuted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(frequency == option ? Color.maplogLime : Color.maplogCanvas)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                let message = isEnabled ? "\(frequency) 알림을 켰어요" : "팝업 알림을 껐어요"
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onDone(message)
                }
            } label: {
                Label("설정 완료", systemImage: "checkmark")
                    .font(MaplogFont.cardTitle)
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(MaplogSpacing.xLarge)
    }
}

private struct NearbyPlace: Identifiable {
    let id: String
    let name: String
    let kind: String
    let distance: String
    let summary: String
    let rating: String
    let reviews: String
    let assetName: String
    let spot: MaplogSpot
}

struct NearbyRecommendationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    let onBack: (() -> Void)?
    @State private var selectedFilter = "전체"
    @State private var query = ""
    @State private var sortMode = "거리순"
    @State private var toastText: String?

    init(onBack: (() -> Void)? = nil) {
        self.onBack = onBack
    }

    private let filters = ["전체", "한식", "일식", "양식", "카페"]
    private var places: [NearbyPlace] {
        [
            NearbyPlace(
                id: "nearby-dining",
                name: "다이닝 우드",
                kind: "모던 한식",
                distance: "1.2km",
                summary: "제철 식재료를 활용한 현대적인 한식 다이닝",
                rating: "4.8",
                reviews: "124",
                assetName: "nearby_dining",
                spot: MaplogSpot(
                    id: "nearby-dining-spot",
                    name: "다이닝 우드",
                    category: "한식",
                    area: "서울 성동구",
                    summary: "제철 식재료를 활용한 현대적인 한식 다이닝. 조용한 분위기에서 코스 메뉴를 즐기기 좋다.",
                    rating: 4.8,
                    imageStyle: .forest,
                    tags: ["한식", "다이닝", "성수동"],
                    pinX: 0.40,
                    pinY: 0.55
                )
            ),
            NearbyPlace(
                id: "nearby-dessert",
                name: "오블리끄 랩",
                kind: "카페/디저트",
                distance: "2.5km",
                summary: "프랑스 정통 방식의 수제 디저트와 커피",
                rating: "4.9",
                reviews: "89",
                assetName: "nearby_dessert",
                spot: MaplogSpot(
                    id: "nearby-dessert-spot",
                    name: "오블리끄 랩",
                    category: "카페",
                    area: "서울 성동구",
                    summary: "프랑스 정통 방식의 수제 디저트와 커피를 함께 즐기는 카페. 오후 산책 코스로 어울린다.",
                    rating: 4.9,
                    imageStyle: .cafe,
                    tags: ["카페", "디저트", "커피"],
                    pinX: 0.34,
                    pinY: 0.60
                )
            ),
            NearbyPlace(
                id: "nearby-sushi",
                name: "스시 마코토",
                kind: "일식 오마카세",
                distance: "3.1km",
                summary: "당일 공수한 신선한 재료의 오마카세",
                rating: "4.7",
                reviews: "210",
                assetName: "nearby_sushi",
                spot: MaplogSpot(
                    id: "nearby-sushi-spot",
                    name: "스시 마코토",
                    category: "일식",
                    area: "서울 강남구",
                    summary: "당일 공수한 신선한 재료로 구성한 오마카세. 예약 후 방문하기 좋은 조용한 맛집.",
                    rating: 4.7,
                    imageStyle: .market,
                    tags: ["일식", "오마카세", "예약"],
                    pinX: 0.54,
                    pinY: 0.42
                )
            )
        ]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        searchField
                        filterChips

                        if filteredPlaces.isEmpty {
                            nearbyEmptyState
                        } else {
                            VStack(spacing: MaplogSpacing.medium) {
                                ForEach(filteredPlaces) { place in
                                    ZStack(alignment: .topTrailing) {
                                        NavigationLink {
                                            SpotDetailView(spot: place.spot)
                                        } label: {
                                            nearbyPlaceCard(
                                                place,
                                                isSaved: sessionStore.hasSavedSpot(place.spot)
                                            )
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            toggleSave(place)
                                        } label: {
                                            Image(systemName: sessionStore.hasSavedSpot(place.spot) ? "heart.fill" : "heart")
                                                .font(.system(size: 22, weight: .semibold))
                                                .foregroundStyle(sessionStore.hasSavedSpot(place.spot) ? Color.maplogLime : Color.maplogMuted)
                                                .frame(width: 44, height: 44)
                                                .contentShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.top, 15)
                                        .padding(.trailing, 14)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, MaplogSpacing.page)
                    .padding(.top, 16)
                    .maplogListBottomPadding()
                }
                .background(Color.maplogCanvas.opacity(0.58))
            }

            if let toastText {
                DiscoveryToastView(text: toastText)
                    .padding(.bottom, 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.maplogSurface)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        HStack {
            Button {
                goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()
            Text("맛집")
                .font(MaplogFont.sectionTitle)
                .foregroundStyle(Color.maplogOlive)
            Spacer()

            Button {
                sortMode = sortMode == "거리순" ? "평점순" : "거리순"
                showToast("\(sortMode)으로 정렬했어요")
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(height: 64)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.maplogLine).frame(height: 1)
        }
    }

    private var searchField: some View {
        HStack(spacing: MaplogSpacing.small) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .bold))
            TextField("지역, 식당 이름 검색", text: $query)
                .font(.system(size: 16, weight: .semibold))
                .textInputAutocapitalization(.never)
        }
        .foregroundStyle(Color.maplogMuted)
        .padding(.horizontal, 18)
        .frame(height: 58)
        .background(Color.maplogSurface)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.04), radius: 16, x: 0, y: 8)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(filters, id: \.self) { filter in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(selectedFilter == filter ? Color.maplogInk : Color.maplogMuted)
                            .padding(.horizontal, 18)
                            .frame(height: 42)
                            .background(selectedFilter == filter ? Color.maplogLime : .white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var filteredPlaces: [NearbyPlace] {
        let result = places.filter { place in
            let matchesFilter = selectedFilter == "전체" || place.kind.contains(selectedFilter)
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesQuery = trimmedQuery.isEmpty
                || place.name.localizedCaseInsensitiveContains(trimmedQuery)
                || place.kind.localizedCaseInsensitiveContains(trimmedQuery)
                || place.summary.localizedCaseInsensitiveContains(trimmedQuery)
            return matchesFilter && matchesQuery
        }

        if sortMode == "평점순" {
            return result.sorted { (Double($0.rating) ?? 0) > (Double($1.rating) ?? 0) }
        }
        return result
    }

    private var nearbyEmptyState: some View {
        VStack(spacing: MaplogSpacing.small) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.maplogMuted)
            Text("조건에 맞는 맛집이 없어요")
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(Color.maplogInk)
            Text("다른 카테고리나 검색어로 다시 찾아보세요.")
                .font(MaplogFont.callout)
                .foregroundStyle(Color.maplogMuted)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                    selectedFilter = "전체"
                    query = ""
                }
            } label: {
                Text("전체 보기")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 18)
                    .frame(height: 42)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 18)
        .background(Color.maplogSurface)
        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 18, x: 0, y: 8)
    }

    private func nearbyPlaceCard(_ place: NearbyPlace, isSaved: Bool) -> some View {
        HStack(spacing: 14) {
            Image(place.assetName)
                .resizable()
                .scaledToFill()
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous))
                .frame(width: 112)

            VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.maplogInk)
                        Text("\(place.kind) · \(place.distance)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.maplogMuted)
                    }
                    Spacer()
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSaved ? Color.maplogLime : Color.maplogMuted)
                }

                Text(place.summary)
                    .font(MaplogFont.callout)
                    .foregroundStyle(Color.maplogMuted)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.maplogLime)
                    Text("\(place.rating)  (\(place.reviews))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.maplogInk)
                }
            }
        }
        .padding(14)
        .background(Color.maplogSurface)
        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 18, x: 0, y: 8)
    }

    private func toggleSave(_ place: NearbyPlace) {
        if sessionStore.hasSavedSpot(place.spot) {
            sessionStore.removeSavedSpot(place.spot)
            showToast("찜을 해제했어요")
        } else {
            sessionStore.saveSpot(place.spot)
            showToast("찜한 맛집에 저장했어요")
        }
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

    private func goBack() {
        if let onBack {
            onBack()
            return
        }
        dismiss()
        presentationMode.wrappedValue.dismiss()
    }
}

private struct DiscoveryToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.maplogInk)
            .padding(.horizontal, 18)
            .frame(height: 48)
            .background(Color.maplogSurface)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
    }
}

private struct ThemeSpotCard: View {
    let theme: ThemeSpot
    let isSaved: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                TravelImageView(style: theme.style, height: 264)
                    .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous))
                Text(theme.badge)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(theme.badge == "마감임박" ? Color.white.opacity(0.92) : Color.maplogLime)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(MaplogSpacing.small)
                Label(theme.count, systemImage: "play.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.92))
                    .clipShape(Capsule())
                    .padding(MaplogSpacing.small)
            }
            VStack(alignment: .leading, spacing: 9) {
                Text(theme.title)
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                Text(theme.summary)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.maplogMuted)
                    .lineSpacing(4)
                HStack {
                    Label(theme.distance, systemImage: "mappin.and.ellipse")
                    Spacer()
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(isSaved ? Color.maplogInk : Color.maplogMuted)
                        .frame(width: 42, height: 42)
                        .background(isSaved ? Color.maplogLime : Color.maplogCanvas)
                        .clipShape(Circle())
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.maplogMuted)
            }
            .padding(MaplogSpacing.medium)
        }
        .maplogCard()
    }
}

struct MapSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    let onPickSpot: ((MaplogSpot) -> Void)?
    @State private var query: String
    @State private var selectedFilter = "전체"
    @State private var selectedSpot: MaplogSpot? = MockMaplogData.forestCafe
    @State private var activeSuggestedTrip: MaplogTrip?
    @State private var toastText: String?
    private let filters = ["전체", "영업중", "주차가능", "포토존", "카페"]

    init(query: String, onPickSpot: ((MaplogSpot) -> Void)? = nil) {
        _query = State(initialValue: query)
        self.onPickSpot = onPickSpot
    }

    private var searchResults: [MaplogSpot] {
        MockMaplogData.spots.filter { spot in
            let matchesFilter: Bool
            switch selectedFilter {
            case "영업중":
                matchesFilter = true
            case "주차가능":
                matchesFilter = ["spot-seoul-tower", "spot-busan-market"].contains(spot.id)
            case "포토존":
                matchesFilter = spot.tags.contains("사진") || spot.category == "야경" || spot.imageStyle == .city
            case "카페":
                matchesFilter = spot.category == "카페" || spot.tags.contains("커피")
            default:
                matchesFilter = true
            }

            let queryTerms = query
                .split(whereSeparator: { $0.isWhitespace })
                .map(String.init)
            let searchableText = ([spot.name, spot.area, spot.category, spot.summary] + spot.tags).joined(separator: " ")
            let matchesQuery = queryTerms.isEmpty || queryTerms.allSatisfy { term in
                searchableText.localizedCaseInsensitiveContains(term)
            }

            return matchesFilter && matchesQuery
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            MockMapCanvas(spots: searchResults, selectedSpot: $selectedSpot)
                .ignoresSafeArea()

            VStack(spacing: MaplogSpacing.small) {
                searchBar
                filterChips

                Spacer()
                resultPanel
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
                    .padding(.bottom, 338)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            syncSelectedSpot()
        }
        .onChange(of: query) { _, _ in
            syncSelectedSpot()
        }
        .sheet(item: $activeSuggestedTrip) { trip in
            SuggestedRouteSheet(
                trip: trip,
                isAlreadySaved: sessionStore.hasSavedRoute(trip),
                onSave: {
                    saveRoute(trip)
                }
            )
            .presentationDetents([.height(330)])
            .presentationDragIndicator(.visible)
        }
        .toolbar(.hidden, for: .navigationBar)
        .maplogTabBarHidden()
    }

    private var searchBar: some View {
        HStack(spacing: MaplogSpacing.small) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 28, height: 36)
            }
            .buttonStyle(.plain)

            TextField("장소 검색", text: $query)
                .font(.system(size: 18, weight: .semibold))
                .textInputAutocapitalization(.never)
                .submitLabel(.search)

            Button {
                query = ""
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 28, height: 36)
            }
            .buttonStyle(.plain)
            .opacity(query.isEmpty ? 0 : 1)
            .disabled(query.isEmpty)
        }
        .foregroundStyle(Color.maplogMuted)
        .padding(.horizontal, 18)
        .frame(height: 58)
        .background(Color.maplogSurface)
        .clipShape(Capsule())
        .padding(.horizontal, MaplogSpacing.page)
        .padding(.top, 16)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(filters, id: \.self) { filter in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                            selectedFilter = filter
                            syncSelectedSpot()
                        }
                    } label: {
                        ChipView(title: filter, isSelected: selectedFilter == filter)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, MaplogSpacing.page)
        }
    }

    private var resultPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(Color.maplogLine)
                .frame(width: 52, height: 5)
                .frame(maxWidth: .infinity)

            HStack {
                Text("검색 결과")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                Text("\(searchResults.count)")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())
                Spacer()
                Text(selectedFilter)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.maplogMuted)
            }

            if searchResults.isEmpty {
                emptyResultCard
            } else {
                resultStrip

                if let selectedSpot {
                    selectedSpotCard(selectedSpot)
                }
            }
        }
        .padding(MaplogSpacing.large)
        .padding(.bottom, 22)
        .background(Color.maplogSurface)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: -8)
    }

    private var resultStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MaplogSpacing.small) {
                ForEach(searchResults) { spot in
                    Button {
                        selectedSpot = spot
                    } label: {
                        MapSearchResultCard(
                            spot: spot,
                            isSelected: selectedSpot?.id == spot.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyResultCard: some View {
        VStack(spacing: MaplogSpacing.small) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.maplogMuted)
            Text("검색 결과가 없어요")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.maplogInk)
            Text("필터를 바꾸거나 다른 장소 이름으로 검색해보세요.")
                .font(MaplogFont.callout)
                .foregroundStyle(Color.maplogMuted)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Button {
                    resetSearch(to: "성수동")
                } label: {
                    Label("추천 검색", systemImage: "sparkles")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.maplogLime)
                        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    resetSearch(to: "")
                } label: {
                    Label("초기화", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.maplogSurface)
                        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, MaplogSpacing.medium)
        .padding(.vertical, 28)
        .background(Color.maplogCanvas)
        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous))
    }

    private func selectedSpotCard(_ spot: MaplogSpot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: MaplogSpacing.small) {
                TravelImageView(style: spot.imageStyle, height: 76, cornerRadius: 10, showsSymbol: false)
                    .frame(width: 76)
                VStack(alignment: .leading, spacing: 6) {
                    Text(spot.name)
                        .font(MaplogFont.sectionTitle)
                        .foregroundStyle(Color.maplogInk)
                    Text("\(spot.category) · 도보 5분")
                        .font(MaplogFont.callout)
                        .foregroundStyle(Color.maplogMuted)
                    HStack(spacing: MaplogSpacing.small) {
                        Label(String(format: "%.1f", spot.rating), systemImage: "star.fill")
                        Label("999+", systemImage: "figure.walk")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.maplogMuted)
                }
                Spacer()
                Button {
                    toggleSave(spot)
                } label: {
                    Image(systemName: sessionStore.hasSavedSpot(spot) ? "heart.fill" : "heart")
                        .font(MaplogFont.screenTitle)
                        .foregroundStyle(sessionStore.hasSavedSpot(spot) ? Color.maplogLime : Color.maplogInk)
                        .frame(width: 44, height: 44)
                        .background(Color.maplogCanvas)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                if let onPickSpot {
                    Button {
                        onPickSpot(spot)
                        dismiss()
                    } label: {
                        Label("이 장소 선택", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.maplogLime)
                            .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        activeSuggestedTrip = suggestedTrip(for: spot)
                    } label: {
                        Label("길찾기", systemImage: "location.north.line.fill")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.maplogCanvas)
                            .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                NavigationLink {
                    SpotDetailView(spot: spot)
                } label: {
                    Label("상세보기", systemImage: "chevron.right")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.maplogLime)
                        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(MaplogSpacing.small)
        .background(Color.maplogCanvas.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous))
    }

    private func syncSelectedSpot() {
        if let selectedSpot, searchResults.contains(where: { $0.id == selectedSpot.id }) {
            return
        }
        selectedSpot = searchResults.first
    }

    private func resetSearch(to newQuery: String) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            query = newQuery
            selectedFilter = "전체"
            syncSelectedSpot()
        }

        let toast = newQuery.isEmpty ? "전체 장소를 불러왔어요" : "\(newQuery) 추천 장소를 불러왔어요"
        showToast(toast)
    }

    private func suggestedTrip(for spot: MaplogSpot) -> MaplogTrip {
        MockMaplogData.routeTrip(for: spot)
    }

    private func saveRoute(_ trip: MaplogTrip) {
        guard !sessionStore.hasSavedRoute(trip) else {
            showToast("이미 보관함에 있는 루트예요")
            return
        }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            _ = sessionStore.saveRoute(trip)
        }
        showToast("루트 보관함에 저장했어요")
    }

    private func toggleSave(_ spot: MaplogSpot) {
        if sessionStore.hasSavedSpot(spot) {
            sessionStore.removeSavedSpot(spot)
            showToast("찜을 해제했어요")
        } else {
            sessionStore.saveSpot(spot)
            showToast("찜한 장소에 저장했어요")
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
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

private struct MapSearchResultCard: View {
    let spot: MaplogSpot
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
            TravelImageView(style: spot.imageStyle, height: 86, cornerRadius: MaplogRadius.medium, showsSymbol: false)
                .frame(width: 118)
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                            .frame(width: 24, height: 24)
                            .background(Color.maplogLime)
                            .clipShape(Circle())
                            .padding(MaplogSpacing.xSmall)
                    }
                }

            Text(spot.name)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color.maplogInk)
                .lineLimit(1)
            Text("\(spot.category) · \(spot.area)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.maplogMuted)
                .lineLimit(1)
        }
        .padding(MaplogSpacing.xSmall)
        .frame(width: 134, alignment: .leading)
        .background(isSelected ? Color.maplogLime.opacity(0.18) : Color.maplogCanvas)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color.maplogLime : .clear, lineWidth: 2)
        }
    }
}

private enum RouteLibrarySheet: Identifiable {
    case options
    case suggestion

    var id: String {
        switch self {
        case .options: return "options"
        case .suggestion: return "suggestion"
        }
    }
}

struct RouteLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @State private var activeSheet: RouteLibrarySheet?
    @State private var sortMode = "최근 저장순"
    @State private var routeAlertsEnabled = true
    @State private var showClearDialog = false
    @State private var toastText: String?

    private var suggestedTrip: MaplogTrip {
        MockMaplogData.routeTrip(for: MockMaplogData.forestCafe)
    }

    private var displayedRoutes: [MaplogTrip] {
        sortMode == "최근 저장순" ? sessionStore.savedRoutes : Array(sessionStore.savedRoutes.reversed())
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                libraryTopBar

                if sessionStore.savedRoutes.isEmpty {
                    emptyRouteContent
                } else {
                    savedRouteContent
                }
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
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .options:
                RouteLibraryOptionsSheet(
                    sortMode: $sortMode,
                    routeAlertsEnabled: $routeAlertsEnabled,
                    hasSavedRoutes: !sessionStore.savedRoutes.isEmpty,
                    onShowSuggestion: {
                        activeSheet = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            activeSheet = .suggestion
                        }
                    },
                    onClearEmptyLibrary: {
                        activeSheet = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            showClearDialog = true
                        }
                    }
                )
                .presentationDetents([.height(350)])
                .presentationDragIndicator(.visible)
            case .suggestion:
                SuggestedRouteSheet(
                    trip: suggestedTrip,
                    isAlreadySaved: sessionStore.hasSavedRoute(suggestedTrip),
                    onSave: {
                        saveRoute(suggestedTrip)
                    }
                )
                    .presentationDetents([.height(330)])
                    .presentationDragIndicator(.visible)
            }
        }
        .background(Color.maplogSurface)
        .confirmationDialog("루트를 삭제하시겠어요?", isPresented: $showClearDialog, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                clearRoutes()
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("삭제된 루트는 복구할 수 없습니다.")
        }
        .maplogTabBarHidden()
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var libraryTopBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 40, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()
            Text("루트 보관함")
                .font(MaplogFont.sectionTitle)
            Spacer()
            Button {
                activeSheet = .options
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 40, height: 44)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Color.maplogInk)
        .padding(.horizontal, 22)
        .frame(height: 58)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.maplogLine).frame(height: 1)
        }
    }

    private var emptyRouteContent: some View {
        VStack {
            Spacer()

            VStack(spacing: MaplogSpacing.xLarge) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white)
                        .frame(width: 112, height: 112)
                        .rotationEffect(.degrees(-4))
                        .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 12)
                    Image(systemName: "map")
                        .font(.system(size: 46, weight: .regular))
                        .foregroundStyle(Color.maplogMuted.opacity(0.7))
                        .frame(width: 112, height: 112)
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: 46, height: 46)
                        .background(Color.maplogLime)
                        .clipShape(Circle())
                        .offset(x: 12, y: 10)
                }

                VStack(spacing: 9) {
                    Text("따라가고 싶은 루트를 저장해보세요")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(Color.maplogInk)
                    Text("지도를 탐색하며 마음에 드는 루트를 발견하고 저장하면 여기에 표시돼요.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.maplogMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 34)

                VStack(spacing: 10) {
                    NavigationLink {
                        MapSearchView(query: "성수동 카페")
                    } label: {
                        Label("지도에서 탐색하기", systemImage: "safari")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(Color.maplogLime)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        activeSheet = .suggestion
                    } label: {
                        Label("추천 루트 저장해보기", systemImage: "sparkles")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.maplogCanvas)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
            }

            Spacer()
        }
    }

    private var savedRouteContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: MaplogSpacing.small) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("저장한 루트 \(sessionStore.savedRoutes.count)개")
                            .font(.system(size: 27, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                        Text(routeAlertsEnabled ? "출발 전 알림이 켜져 있어요" : "알림 없이 조용히 저장합니다")
                            .font(MaplogFont.callout)
                            .foregroundStyle(Color.maplogMuted)
                    }

                    Spacer()

                    Text(sortMode)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(Color.maplogLime)
                        .clipShape(Capsule())
                }

                Button {
                    activeSheet = .suggestion
                } label: {
                    HStack(spacing: MaplogSpacing.small) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                            .frame(width: 36, height: 36)
                            .background(Color.maplogLime)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text("새 추천 루트 추가")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.maplogInk)
                            Text("Maplog 추천 루트를 보관함에 담아보세요")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.maplogMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Color.maplogMuted)
                    }
                    .padding(14)
                    .background(Color.maplogCanvas)
                    .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
                }
                .buttonStyle(.plain)

                VStack(spacing: 14) {
                    ForEach(displayedRoutes) { trip in
                        SavedRouteActionCard(
                            trip: trip,
                            note: routeAlertsEnabled ? "출발 1시간 전 알림" : "알림 꺼짐",
                            onRemove: {
                                removeRoute(trip)
                            }
                        )
                    }
                }
            }
            .padding(22)
            .padding(.bottom, 110)
        }
    }

    private func removeRoute(_ trip: MaplogTrip) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            _ = sessionStore.removeSavedRoute(trip)
        }
        showToast("\(trip.title) 저장을 해제했어요")
    }

    private func saveRoute(_ trip: MaplogTrip) {
        guard !sessionStore.hasSavedRoute(trip) else {
            showToast("이미 보관함에 있는 루트예요")
            return
        }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            _ = sessionStore.saveRoute(trip)
        }
        showToast("루트 보관함에 저장했어요")
    }

    private func clearRoutes() {
        guard !sessionStore.savedRoutes.isEmpty else {
            showToast("삭제할 저장 루트가 아직 없어요")
            return
        }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            sessionStore.clearSavedRoutes()
        }
        showToast("저장 루트를 모두 비웠어요")
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            toastText = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            withAnimation(.easeOut(duration: 0.2)) {
                toastText = nil
            }
        }
    }
}

private struct RouteLibraryOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var sortMode: String
    @Binding var routeAlertsEnabled: Bool
    let hasSavedRoutes: Bool
    let onShowSuggestion: () -> Void
    let onClearEmptyLibrary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("보관함 관리")
                    .font(MaplogFont.screenTitle)
                    .foregroundStyle(Color.maplogInk)
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

            VStack(spacing: 10) {
                RouteLibraryOptionRow(
                    title: "추천 루트 미리보기",
                    subtitle: "지금 저장할 만한 루트를 한 장으로 확인",
                    systemImage: "sparkles"
                ) {
                    onShowSuggestion()
                }

                RouteLibraryOptionRow(
                    title: sortMode,
                    subtitle: sortMode == "최근 저장순" ? "누르면 오래된 저장순으로 바뀝니다" : "누르면 최근 저장순으로 바뀝니다",
                    systemImage: "arrow.up.arrow.down"
                ) {
                    sortMode = sortMode == "최근 저장순" ? "오래된 저장순" : "최근 저장순"
                }

                Toggle(isOn: $routeAlertsEnabled) {
                    Label("저장 루트 알림", systemImage: routeAlertsEnabled ? "bell.fill" : "bell")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.maplogInk)
                }
                .tint(Color.maplogLime)
                .padding(14)
                .background(Color.maplogCanvas)
                .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous))

                RouteLibraryOptionRow(
                    title: "보관함 비우기",
                    subtitle: hasSavedRoutes ? "저장한 루트를 모두 삭제합니다" : "빈 상태에서는 안내 토스트만 보여줍니다",
                    systemImage: "trash"
                ) {
                    onClearEmptyLibrary()
                }
            }
        }
        .padding(MaplogSpacing.xLarge)
    }
}

private struct RouteLibraryOptionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MaplogSpacing.small) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 38, height: 38)
                    .background(Color.maplogLime.opacity(0.72))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.maplogInk)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.maplogMuted)
                        .lineLimit(1)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color.maplogMuted)
            }
            .padding(14)
            .background(Color.maplogCanvas)
            .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SuggestedRouteSheet: View {
    let trip: MaplogTrip
    let isAlreadySaved: Bool
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: MaplogSpacing.large) {
                HStack(spacing: 14) {
                    TravelImageView(style: trip.coverStyle, height: 88)
                        .frame(width: 88)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(trip.location) · 추천 루트")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.maplogMuted)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.maplogCanvas)
                            .clipShape(Capsule())
                        Text(trip.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.maplogInk)
                        Text("\(trip.subtitle) · \(trip.spots.count)개 장소")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.maplogMuted)
                            .lineLimit(2)
                    }
                    Spacer()
                }

                HStack(spacing: 10) {
                    ForEach(Array(trip.spots.enumerated()), id: \.offset) { index, spot in
                        VStack(spacing: 6) {
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(Color.maplogInk)
                                .frame(width: 24, height: 24)
                                .background(Color.maplogLime)
                                .clipShape(Circle())
                            Text(spot.name)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.maplogInk)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(MaplogSpacing.small)
                .background(Color.maplogCanvas)
                .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))

                HStack(spacing: MaplogSpacing.small) {
                    Button {
                        onSave()
                        dismiss()
                    } label: {
                        Label(isAlreadySaved ? "저장됨" : "보관함에 저장", systemImage: isAlreadySaved ? "checkmark" : "bookmark.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.maplogInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(isAlreadySaved ? Color.maplogLime.opacity(0.62) : Color.maplogCanvas)
                            .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isAlreadySaved)

                    NavigationLink {
                        RouteDetailView(trip: trip)
                    } label: {
                        Label("루트 보기", systemImage: "map.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.maplogInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(Color.maplogLime)
                            .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(MaplogSpacing.xLarge)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
