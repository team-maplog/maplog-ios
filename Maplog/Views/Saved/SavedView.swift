import SwiftUI

struct SavedView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @State private var toastText: String?
    private let spots = MockMaplogData.spots

    private var recommendedSpots: [MaplogSpot] {
        spots.filter { spot in
            !sessionStore.hasSavedSpot(spot)
        }
    }

    private var savedDigests: [AIDigest] {
        MockMaplogData.aiDigests.filter { digest in
            sessionStore.hasSavedDigest(digest)
        }
    }

    private var savedSpotSubtitle: String {
        sessionStore.savedSpots.isEmpty ? "장소 상세나 추천 목록에서 저장하면 여기에 쌓입니다." : "\(sessionStore.savedSpots.count)개 장소가 저장됐어요."
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MaplogSpacing.xLarge) {
                    topBar

                    VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                        Text("저장한 Maplog")
                            .font(MaplogFont.largeTitle)
                            .tracking(-0.4)
                            .foregroundStyle(Color.maplogInk)
                        Text("다시 보고 싶은 장소와 루트를 모아두는 화면입니다.")
                            .font(MaplogFont.callout)
                            .foregroundStyle(Color.maplogMuted)
                    }

                    VStack(alignment: .leading, spacing: MaplogSpacing.small) {
                        SectionHeader(
                            title: "컬렉션",
                            subtitle: "저장한 루트를 테마별로 나눠 보세요."
                        )
                        ForEach(sessionStore.routeCollections) { collection in
                            NavigationLink {
                                SavedRouteCollectionDetailView(collection: collection)
                            } label: {
                                RouteCollectionCard(
                                    collection: collection,
                                    routeCount: sessionStore.routes(in: collection).count
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    savedRouteSection

                    visitChecklistSection

                    if !sessionStore.issuedServicePasses.isEmpty {
                        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
                            SectionHeader(title: "발급한 패스", subtitle: "\(sessionStore.issuedServicePasses.count)개 여행 패스가 준비됐어요.")
                            ForEach(sessionStore.issuedServicePasses) { pass in
                                SavedServicePassActionRow(
                                    pass: pass,
                                    onRemove: {
                                        removeServicePass(pass)
                                    }
                                )
                            }
                        }
                    }

                    if !sessionStore.savedEvents.isEmpty {
                        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
                            SectionHeader(title: "관심 행사", subtitle: "\(sessionStore.savedEvents.count)개 행사를 저장했어요.")
                            ForEach(sessionStore.savedEvents) { event in
                                NavigationLink {
                                    FeaturedEventDetailView(event: event)
                                } label: {
                                    SavedEventRow(event: event)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !savedDigests.isEmpty {
                        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
                            SectionHeader(title: "저장한 요약", subtitle: "\(savedDigests.count)개 AI 여행 요약을 저장했어요.")
                            ForEach(savedDigests) { digest in
                                SavedDigestActionRow(
                                    digest: digest,
                                    onRemove: {
                                        removeSavedDigest(digest)
                                    }
                                )
                            }
                        }
                    }

                    savedSpotSection
                    recommendedSpotSection
                }
                .maplogPagePadding()
                .padding(.top, MaplogSpacing.xSmall)
                .padding(.bottom, MaplogSpacing.xxLarge)
            }

            if let toastText {
                MaplogToast(message: toastText)
                    .padding(.bottom, MaplogSpacing.xLarge)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .maplogScreenSurface()
        .maplogTabBarHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: MaplogSize.iconMedium, weight: .semibold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("보관함")
                .font(MaplogFont.sectionTitle)
                .foregroundStyle(Color.maplogInk)

            Spacer()

            Color.clear
                .frame(width: 42, height: 42)
        }
        .padding(.top, MaplogSpacing.xxSmall)
    }

    @ViewBuilder
    private var savedRouteSection: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            SectionHeader(
                title: "저장한 루트",
                subtitle: sessionStore.savedRoutes.isEmpty ? "따라가고 싶은 루트를 저장하면 여기에 표시됩니다." : "\(sessionStore.savedRoutes.count)개 루트가 저장됐어요."
            )

            if sessionStore.savedRoutes.isEmpty {
                SavedEmptyStateCard(
                    icon: "bookmark.slash",
                    title: "저장한 루트가 없어요",
                    subtitle: "추천 루트나 지도에서 마음에 드는 동선을 보관해보세요."
                ) {
                    NavigationLink {
                        RouteLibraryView()
                    } label: {
                        SavedEmptyStateCTA(title: "추천 루트 보러가기", systemImage: "sparkles")
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ForEach(sessionStore.savedRoutes) { trip in
                    SavedRouteActionCard(
                        trip: trip,
                        note: "보관함에서 바로 열 수 있어요",
                        onRemove: {
                            removeSavedRoute(trip)
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var visitChecklistSection: some View {
        if !sessionStore.visitChecklistSpots.isEmpty {
            VStack(alignment: .leading, spacing: MaplogSpacing.small) {
                SectionHeader(title: "방문 전 확인", subtitle: "\(sessionStore.visitChecklistSpots.count)개 장소를 방문 전 확인 목록에 담았어요.")
                ForEach(sessionStore.visitChecklistSpots) { spot in
                    VisitChecklistSpotRow(
                        spot: spot,
                        onRemove: {
                            removeVisitChecklistSpot(spot)
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var savedSpotSection: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            SectionHeader(title: "저장한 장소", subtitle: savedSpotSubtitle)

            if sessionStore.savedSpots.isEmpty {
                SavedEmptyStateCard(
                    icon: "heart.slash",
                    title: "저장한 장소가 없어요",
                    subtitle: "추천 장소를 저장하거나 장소 상세에서 하트를 눌러보세요."
                ) {
                    NavigationLink {
                        MapSearchView(query: "성수동 카페")
                    } label: {
                        SavedEmptyStateCTA(title: "장소 탐색하기", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ForEach(sessionStore.savedSpots) { spot in
                    SavedSpotActionRow(
                        spot: spot,
                        isSaved: true,
                        onToggleSave: {
                            toggleSpotSaved(spot)
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var recommendedSpotSection: some View {
        if !recommendedSpots.isEmpty {
            VStack(alignment: .leading, spacing: MaplogSpacing.small) {
                SectionHeader(title: "추천 장소", subtitle: "저장하면 위 보관함에 바로 추가됩니다.")
                ForEach(recommendedSpots) { spot in
                    SavedSpotActionRow(
                        spot: spot,
                        isSaved: false,
                        onToggleSave: {
                            toggleSpotSaved(spot)
                        }
                    )
                }
            }
        }
    }

    private func toggleSpotSaved(_ spot: MaplogSpot) {
        if sessionStore.hasSavedSpot(spot) {
            sessionStore.removeSavedSpot(spot)
            showToast("\(spot.name) 저장을 해제했어요")
        } else {
            sessionStore.saveSpot(spot)
            showToast("\(spot.name)\(objectParticle(for: spot.name)) 저장했어요")
        }
    }

    private func removeSavedRoute(_ trip: MaplogTrip) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            _ = sessionStore.removeSavedRoute(trip)
        }
        showToast("\(trip.title) 저장을 해제했어요")
    }

    private func removeSavedDigest(_ digest: AIDigest) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            sessionStore.removeSavedDigest(digest)
        }
        showToast("\(digest.title) 저장을 해제했어요")
    }

    private func removeServicePass(_ pass: MaplogServicePass) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            sessionStore.revokeServicePass(title: pass.title)
        }
        showToast("\(pass.title) 패스를 해제했어요")
    }

    private func removeVisitChecklistSpot(_ spot: MaplogSpot) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            _ = sessionStore.removeVisitChecklistSpot(spot)
        }
        showToast("\(spot.name) 방문 전 확인을 해제했어요")
    }

    private func objectParticle(for text: String) -> String {
        guard let scalar = text.unicodeScalars.last else {
            return "를"
        }

        let value = scalar.value
        guard value >= 0xAC00, value <= 0xD7A3 else {
            return "를"
        }

        return (value - 0xAC00) % 28 == 0 ? "를" : "을"
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

private struct SavedRouteCollectionDetailView: View {
    @EnvironmentObject private var sessionStore: MaplogSessionStore

    let collection: MaplogRouteCollection

    private var currentCollection: MaplogRouteCollection {
        sessionStore.routeCollections.first { $0.id == collection.id } ?? collection
    }

    private var routes: [MaplogTrip] {
        sessionStore.routes(in: currentCollection)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: MaplogSpacing.xLarge) {
                header

                if routes.isEmpty {
                    VStack(spacing: MaplogSpacing.small) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(Color.maplogMuted)
                        Text("아직 담긴 루트가 없어요")
                            .font(.headline)
                            .foregroundStyle(Color.maplogInk)
                        Text("릴스의 저장 버튼에서 이 컬렉션을 선택하면 여기에 모입니다.")
                            .font(.subheadline)
                            .foregroundStyle(Color.maplogMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(MaplogSpacing.xxLarge)
                    .frame(maxWidth: .infinity)
                    .background(Color.maplogCanvas, in: RoundedRectangle(cornerRadius: MaplogRadius.xLarge, style: .continuous))
                } else {
                    VStack(alignment: .leading, spacing: MaplogSpacing.small) {
                        SectionHeader(title: "담아둔 루트", subtitle: "\(routes.count)개 루트")

                        ForEach(routes) { trip in
                            CollectionRouteCard(trip: trip) {
                                _ = sessionStore.removeRoute(trip, from: currentCollection.id)
                            }
                        }
                    }
                }
            }
            .maplogPagePadding()
            .padding(.top, MaplogSpacing.medium)
            .padding(.bottom, MaplogSpacing.xxLarge)
        }
        .maplogScreenSurface()
        .navigationTitle(currentCollection.title)
        .navigationBarTitleDisplayMode(.inline)
        .maplogTabBarHidden()
    }

    private var header: some View {
        HStack(spacing: MaplogSpacing.medium) {
            TravelImageView(
                style: currentCollection.coverStyle,
                height: 88,
                cornerRadius: MaplogRadius.large,
                showsSymbol: false
            )
            .frame(width: 88)

            VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                Text(currentCollection.title)
                    .font(MaplogFont.screenTitle)
                    .foregroundStyle(Color.maplogInk)
                    .lineLimit(2)
                Text("나만의 저장 컬렉션 · \(routes.count)개 루트")
                    .font(MaplogFont.callout)
                    .foregroundStyle(Color.maplogMuted)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(MaplogSpacing.small)
        .background(Color.maplogCanvas, in: RoundedRectangle(cornerRadius: MaplogRadius.xLarge, style: .continuous))
    }
}

private struct CollectionRouteCard: View {
    let trip: MaplogTrip
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            NavigationLink {
                RouteDetailView(trip: trip)
            } label: {
                TripCardView(trip: trip, isLarge: true)
            }
            .buttonStyle(.plain)

            HStack {
                Label("이 컬렉션에 저장됨", systemImage: "bookmark.fill")
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogMuted)

                Spacer(minLength: 8)

                Button(action: onRemove) {
                    Label("컬렉션에서 제거", systemImage: "minus.circle")
                        .font(MaplogFont.caption)
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, MaplogSpacing.small)
                        .frame(minHeight: 34)
                        .background(Color.maplogCanvas, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(trip.title)을 이 컬렉션에서 제거")
            }
        }
    }
}

private struct RouteCollectionCard: View {
    let collection: MaplogRouteCollection
    let routeCount: Int

    var body: some View {
        HStack(spacing: MaplogSpacing.small) {
            TravelImageView(
                style: collection.coverStyle,
                height: 68,
                cornerRadius: MaplogRadius.medium,
                showsSymbol: false
            )
            .frame(width: 68)

            VStack(alignment: .leading, spacing: MaplogSpacing.xxxSmall) {
                Text(collection.title)
                    .font(MaplogFont.cardTitle)
                    .foregroundStyle(Color.maplogInk)
                    .lineLimit(1)
                Text("\(routeCount)개 루트")
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogMuted)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.maplogMuted)
                .accessibilityHidden(true)
        }
        .padding(MaplogSpacing.xSmall)
        .maplogCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(collection.title), \(routeCount)개 루트")
    }
}

private struct SavedEmptyStateCard<CTA: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder var cta: () -> CTA

    var body: some View {
        VStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Color.maplogMuted)
            Text(title)
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(Color.maplogInk)
            Text(subtitle)
                .font(MaplogFont.callout)
                .foregroundStyle(Color.maplogMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            cta()
                .padding(.top, 4)
        }
        .padding(MaplogSpacing.large)
        .frame(maxWidth: .infinity)
        .background(Color.maplogCanvas)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct VisitChecklistSpotRow: View {
    let spot: MaplogSpot
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: MaplogSpacing.small) {
            NavigationLink {
                SpotDetailView(spot: spot)
            } label: {
                HStack(spacing: MaplogSpacing.small) {
                    TravelImageView(style: spot.imageStyle, height: 82, cornerRadius: MaplogRadius.small)
                        .frame(width: 82)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("방문 준비")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                            .padding(.horizontal, MaplogSpacing.xSmall)
                            .padding(.vertical, 4)
                            .background(Color.maplogLime)
                            .clipShape(Capsule())
                        Text(spot.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.maplogInk)
                            .lineLimit(1)
                        Text("전화 · 영업시간 · 주소 확인 필요")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.maplogMuted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.maplogMuted)
                    .frame(width: 42, height: 42)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(spot.name) 방문 전 확인 해제")
        }
        .padding(10)
        .maplogCard()
    }
}

private struct SavedEmptyStateCTA: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 15, weight: .black))
            .foregroundStyle(Color.maplogInk)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.maplogLime)
            .clipShape(Capsule())
    }
}

private struct SavedSpotActionRow: View {
    let spot: MaplogSpot
    let isSaved: Bool
    let onToggleSave: () -> Void

    var body: some View {
        HStack(spacing: MaplogSpacing.small) {
            NavigationLink {
                SpotDetailView(spot: spot)
            } label: {
                HStack(spacing: MaplogSpacing.small) {
                    TravelImageView(style: spot.imageStyle, height: 82, cornerRadius: MaplogRadius.small)
                        .frame(width: 82)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(spot.category)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.maplogInk)
                                .padding(.horizontal, MaplogSpacing.xSmall)
                                .padding(.vertical, 4)
                                .background(Color.maplogLime)
                                .clipShape(Capsule())
                            Label(String(format: "%.1f", spot.rating), systemImage: "star.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.maplogMuted)
                        }
                        Text(spot.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.maplogInk)
                            .lineLimit(1)
                        Text(spot.area)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.maplogMuted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            NavigationLink {
                MapSearchView(query: spot.name)
            } label: {
                Image(systemName: "map.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.maplogPrimary)
                    .frame(width: 42, height: 42)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(spot.name) 지도에서 보기")

            Button(action: onToggleSave) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isSaved ? Color.maplogPrimary : Color.maplogMuted)
                    .frame(width: 42, height: 42)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSaved ? "장소 저장 해제" : "장소 저장")
        }
        .padding(10)
        .maplogCard()
    }
}

private struct SavedDigestActionRow: View {
    let digest: AIDigest
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: MaplogSpacing.small) {
            NavigationLink {
                AIDigestDetailView(digest: digest)
            } label: {
                HStack(spacing: MaplogSpacing.small) {
                    TravelImageView(style: digest.imageStyle, height: 82, cornerRadius: MaplogRadius.small, showsSymbol: false)
                        .frame(width: 82)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(digest.badge)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.maplogInk)
                            .padding(.horizontal, MaplogSpacing.xSmall)
                            .padding(.vertical, 4)
                            .background(Color.maplogLime)
                            .clipShape(Capsule())
                        Text(digest.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.maplogInk)
                            .lineLimit(1)
                        Text(digest.source)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.maplogMuted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Button(action: onRemove) {
                Image(systemName: "bookmark.slash")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 42, height: 42)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(digest.title) 저장 해제")
        }
        .padding(10)
        .maplogCard()
    }
}

private struct SavedCollectionDetailView: View {
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @State private var toastText: String?

    let collection: SavedCollection
    let spots: [MaplogSpot]
    let summary: String

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MaplogSpacing.xLarge) {
                    header

                    NavigationLink {
                        MapSearchView(query: collection.title)
                    } label: {
                        Label("컬렉션 지도에서 보기", systemImage: "map.fill")
                            .font(MaplogFont.cardTitle)
                            .foregroundStyle(Color.maplogInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.maplogLime)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: MaplogSpacing.small) {
                        SectionHeader(title: "대표 장소", subtitle: "\(spots.count)개 장소를 먼저 확인해보세요.")
                        ForEach(spots) { spot in
                            SavedCollectionSpotRow(
                                spot: spot,
                                isSaved: sessionStore.hasSavedSpot(spot),
                                onToggleSave: {
                                    toggleSave(spot)
                                }
                            )
                        }
                    }
                }
                .padding(MaplogSpacing.page)
                .padding(.bottom, 96)
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
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.inline)
        .maplogTabBarHidden()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.medium) {
            HStack(spacing: -18) {
                ForEach(Array(collection.styles.enumerated()), id: \.offset) { _, style in
                    TravelImageView(style: style, height: 118, cornerRadius: MaplogRadius.medium)
                        .frame(width: 118)
                        .overlay(
                            RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous)
                                .stroke(.white, lineWidth: 4)
                        )
                }
            }

            VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                Text(collection.title)
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                Text(summary)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.maplogMuted)
                    .lineSpacing(4)
                HStack(spacing: MaplogSpacing.xSmall) {
                    InfoBadge(title: "\(collection.count)개 저장됨", systemImage: "bookmark.fill")
                    InfoBadge(title: "\(spots.count)개 대표 장소", systemImage: "mappin.and.ellipse")
                }
            }
        }
        .padding(MaplogSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.maplogCanvas)
        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.xLarge, style: .continuous))
    }

    private func toggleSave(_ spot: MaplogSpot) {
        if sessionStore.hasSavedSpot(spot) {
            sessionStore.removeSavedSpot(spot)
            showToast("저장한 장소에서 제거했어요")
        } else {
            sessionStore.saveSpot(spot)
            showToast("\(spot.name)\(objectParticle(for: spot.name)) 저장했어요")
        }
    }

    private func objectParticle(for text: String) -> String {
        guard let scalar = text.unicodeScalars.last else {
            return "를"
        }

        let value = scalar.value
        guard value >= 0xAC00, value <= 0xD7A3 else {
            return "를"
        }

        return (value - 0xAC00) % 28 == 0 ? "를" : "을"
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

private struct SavedCollectionSpotRow: View {
    let spot: MaplogSpot
    let isSaved: Bool
    let onToggleSave: () -> Void

    var body: some View {
        HStack(spacing: MaplogSpacing.small) {
            NavigationLink {
                SpotDetailView(spot: spot)
            } label: {
                HStack(spacing: 14) {
                    TravelImageView(style: spot.imageStyle, height: 86, cornerRadius: MaplogRadius.small)
                        .frame(width: 86)

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 6) {
                            Text(spot.category)
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(Color.maplogInk)
                                .padding(.horizontal, MaplogSpacing.xSmall)
                                .frame(height: 22)
                                .background(Color.maplogLime)
                                .clipShape(Capsule())
                            Text(String(format: "%.1f", spot.rating))
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(Color.maplogMuted)
                        }
                        Text(spot.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.maplogInk)
                            .lineLimit(1)
                        Text(spot.area)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.maplogMuted)
                            .lineLimit(1)
                    }

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            NavigationLink {
                MapSearchView(query: spot.name)
            } label: {
                Image(systemName: "map.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.maplogPrimary)
                    .frame(width: 42, height: 42)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(spot.name) 지도에서 보기")

            Button(action: onToggleSave) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isSaved ? Color.maplogPrimary : Color.maplogMuted)
                    .frame(width: 42, height: 42)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSaved ? "장소 저장 해제" : "장소 저장")
        }
        .padding(MaplogSpacing.small)
        .maplogCard()
    }
}

private struct SavedServicePassActionRow: View {
    let pass: MaplogServicePass
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: MaplogSpacing.small) {
            NavigationLink {
                ServiceDetailView(title: pass.title)
            } label: {
                HStack(spacing: 14) {
                    TravelImageView(style: pass.heroStyle, height: 88, cornerRadius: MaplogRadius.small, showsSymbol: false)
                        .frame(width: 88)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(pass.issuedTitle)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.maplogInk)
                            .lineLimit(2)
                        Text(pass.badge)
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                            .padding(.horizontal, 9)
                            .frame(height: 24)
                            .background(Color.maplogLime)
                            .clipShape(Capsule())
                        Text(pass.summary)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.maplogMuted)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.maplogMuted)
                    .frame(width: 42, height: 42)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(pass.title) 패스 해제")
        }
        .padding(MaplogSpacing.small)
        .maplogCard()
    }
}

private struct SavedEventRow: View {
    let event: FeaturedEvent

    var body: some View {
        HStack(spacing: 14) {
            TravelImageView(style: event.imageStyle, height: 92, cornerRadius: MaplogRadius.small)
                .frame(width: 92)

            VStack(alignment: .leading, spacing: 7) {
                Text(event.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .lineLimit(2)
                Label(event.location, systemImage: "mappin.and.ellipse")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.maplogMuted)
                Text(event.period)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.maplogMuted)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color.maplogMuted)
        }
        .padding(MaplogSpacing.small)
        .maplogCard()
    }
}

struct CollectionCard: View {
    let collection: SavedCollection

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: -18) {
                ForEach(Array(collection.styles.enumerated()), id: \.offset) { _, style in
                    TravelImageView(style: style, height: 64, cornerRadius: MaplogRadius.small)
                        .frame(width: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous)
                                .stroke(.white, lineWidth: 3)
                        )
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(collection.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                Text("\(collection.count)개 저장됨")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.maplogMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color.maplogMuted)
        }
        .padding(MaplogSpacing.small)
        .maplogCard()
    }
}
