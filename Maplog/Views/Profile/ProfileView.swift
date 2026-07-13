import SwiftUI

private enum ProfileContentTab: String, CaseIterable {
    case logs = "로그"
    case savedRoutes = "저장된 경로"
}

private struct ProfileAvatarImage: View {
    let size: CGFloat

    var body: some View {
        Image("home_profile_avatar")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .accessibilityLabel("프로필 사진")
    }
}

struct ProfileView: View {
    @Environment(\.maplogSelectTab) private var selectTab
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @StateObject private var viewModel = ProfileViewModel()
    @State private var selectedTab: ProfileContentTab = .logs
    @State private var toastText: String?

    private var profileLogs: [TravelLog] {
        sessionStore.publishedLogs + viewModel.logs
    }

    private var profileStats: [(String, String)] {
        [
            ("맵로그", "\(profileLogs.count)"),
            ("짧은 클립", "\(profileLogs.reduce(0) { $0 + $1.clips })"),
            ("저장 경로", "\(sessionStore.savedRoutes.count)")
        ]
    }

    private static func durationText(for clips: Int) -> String {
        let safeClips = max(clips, 1)
        return "약 \(safeClips)–\(safeClips * 2)초"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: MaplogSpacing.xLarge) {
                    topBar
                    profileHeader
                    NavigationLink {
                        ProfileEditView {
                            showToast("프로필을 저장했어요")
                        }
                    } label: {
                        Label("프로필 편집", systemImage: "pencil")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color(uiColor: .separator).opacity(0.22), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    profileTabs

                    if selectedTab == .logs {
                        if profileLogs.isEmpty && sessionStore.savedDrafts.isEmpty {
                            emptyLogState
                        } else {
                            if !sessionStore.savedDrafts.isEmpty {
                                draftSection
                            }
                            if !profileLogs.isEmpty {
                                logGrid
                            }
                        }
                    } else {
                        routeLibraryShortcut
                        if sessionStore.savedRoutes.isEmpty {
                            emptySavedRoutes
                        } else {
                            savedRoutes
                        }
                    }
                }
                .padding(.horizontal, MaplogSpacing.page)
                .maplogListBottomPadding()
            }

            if let toastText {
                Text(toastText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 48)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
                    .padding(.bottom, 92)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color(uiColor: .systemBackground))
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("내 Maplog")
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
            Text("짧은 클립으로 쌓은 여행 기록")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 12)
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: MaplogSpacing.medium) {
                ProfileAvatarImage(size: 72)

                ForEach(profileStats, id: \.0) { stat in
                    VStack(spacing: 4) {
                        Text(stat.1)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(stat.0)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                Text(sessionStore.profile.displayName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                Label(sessionStore.profile.location, systemImage: "mappin.and.ellipse")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(sessionStore.profile.bio)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var profileTabs: some View {
        HStack(spacing: 0) {
            ForEach(ProfileContentTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 10) {
                        Text(tab.rawValue)
                            .font(.subheadline.weight(selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary)
                        Capsule()
                            .fill(selectedTab == tab ? Color.maplogLime : .clear)
                            .frame(height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Color(uiColor: .systemBackground).opacity(0.001))
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("\(tab.rawValue) 탭")
                .buttonStyle(.plain)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .zIndex(2)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.maplogLine)
                .frame(height: 1)
        }
    }

    private var logGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: MaplogSpacing.small), GridItem(.flexible(), spacing: MaplogSpacing.small)], spacing: MaplogSpacing.large) {
            ForEach(profileLogs) { log in
                NavigationLink {
                    MyLogDetailView(log: log) { deletedLog in
                        deleteLog(deletedLog)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        TravelLogImageView(log: log, cornerRadius: 14)
                            .frame(height: 174)
                            .overlay(alignment: .bottomLeading) {
                                Label("\(log.city) · \(Self.durationText(for: log.clips))", systemImage: "mappin.circle.fill")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 9)
                                    .frame(minHeight: 28)
                                    .background(.black.opacity(0.38), in: Capsule())
                                    .padding(9)
                            }

                        VStack(alignment: .leading, spacing: 5) {
                            Text(log.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text("\(log.clips)개 클립 · \(log.date)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 1)
                        .padding(.top, 9)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var draftSection: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            SectionHeader(title: "작성 중", subtitle: "\(sessionStore.savedDrafts.count)개 임시저장 로그")
            VStack(spacing: MaplogSpacing.small) {
                ForEach(sessionStore.savedDrafts) { draft in
                    DraftActionRow(
                        draft: draft,
                        onDelete: {
                            deleteDraft(draft)
                        }
                    )
                }
            }
        }
    }

    private var emptyLogState: some View {
        VStack(spacing: 14) {
            Image(systemName: "map.circle.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.maplogMuted)
            Text("아직 남아있는 로그가 없어요")
                .font(MaplogFont.sectionTitle)
                .foregroundStyle(Color.maplogInk)
            Text("촬영 탭에서 새 맵로그를 만들면 여기에 다시 쌓입니다.")
                .font(MaplogFont.callout)
                .foregroundStyle(Color.maplogMuted)
                .multilineTextAlignment(.center)
            Button {
                selectTab(.capture)
            } label: {
                Label("새 로그 촬영하기", systemImage: "camera.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(Color.maplogCanvas)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var routeLibraryShortcut: some View {
        NavigationLink {
            RouteLibraryView()
        } label: {
            HStack(spacing: MaplogSpacing.small) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.maplogPrimary)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("루트 보관함")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.maplogInk)
                    Text(sessionStore.savedRoutes.isEmpty ? "저장된 경로가 없는 상태도 확인할 수 있어요" : "\(sessionStore.savedRoutes.count)개 루트 저장됨")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.maplogMuted)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.maplogMuted)
            }
            .padding(14)
            .maplogCard()
        }
        .buttonStyle(.plain)
    }

    private var savedPlacesShortcut: some View {
        NavigationLink {
            SavedView()
        } label: {
            HStack(spacing: MaplogSpacing.small) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Color.maplogPrimary)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("장소 보관함")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.maplogInk)
                    Text(sessionStore.savedSpots.isEmpty ? "추천 장소와 저장한 장소를 확인해요" : "\(sessionStore.savedSpots.count)개 장소 저장됨")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.maplogMuted)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.maplogMuted)
            }
            .padding(14)
            .maplogCard()
        }
        .buttonStyle(.plain)
    }

    private var savedRoutes: some View {
        VStack(spacing: MaplogSpacing.small) {
            SectionHeader(title: "저장된 경로", subtitle: "\(sessionStore.savedRoutes.count)개 루트가 프로필에 표시됩니다")
            ForEach(sessionStore.savedRoutes) { trip in
                SavedRouteActionCard(
                    trip: trip,
                    note: "프로필 저장 탭에 보관됨",
                    onRemove: {
                        removeSavedRoute(trip)
                    }
                )
            }
        }
    }

    private var emptySavedRoutes: some View {
        VStack(spacing: 14) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Color.maplogMuted)
            Text("저장한 경로가 아직 없어요")
                .font(MaplogFont.sectionTitle)
                .foregroundStyle(Color.maplogInk)
            Text("루트 상세에서 저장하면 이 탭과 루트 보관함에 바로 표시됩니다.")
                .font(MaplogFont.callout)
                .foregroundStyle(Color.maplogMuted)
                .multilineTextAlignment(.center)
            NavigationLink {
                RouteLibraryView()
            } label: {
                Label("추천 루트 보러가기", systemImage: "sparkles")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(Color.maplogCanvas)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func deleteLog(_ log: TravelLog) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            sessionStore.deleteLog(log)
            viewModel.deleteLog(log)
        }
        showToast("기록을 삭제했어요")
    }

    private func deleteDraft(_ draft: MaplogDraft) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            sessionStore.deleteDraft(draft)
        }
        showToast("\(draft.title) 임시저장을 삭제했어요")
    }

    private func removeSavedRoute(_ trip: MaplogTrip) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            _ = sessionStore.removeSavedRoute(trip)
        }
        showToast("\(trip.title) 저장을 해제했어요")
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

private struct DraftActionRow: View {
    let draft: MaplogDraft
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            NavigationLink {
                UploadView(draft: draft)
            } label: {
                HStack(spacing: 13) {
                    TravelImageView(style: draft.imageStyle, height: 86, cornerRadius: MaplogRadius.small, showsSymbol: false)
                        .frame(width: 86)
                        .overlay(alignment: .topLeading) {
                            Text("작성 중")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(Color.maplogInk)
                                .padding(.horizontal, MaplogSpacing.xSmall)
                                .frame(height: 24)
                                .background(Color.maplogLime)
                                .clipShape(Capsule())
                                .padding(7)
                        }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(draft.title)
                            .font(MaplogFont.cardTitle)
                            .foregroundStyle(Color.maplogInk)
                            .lineLimit(1)
                        Label(draft.placeName, systemImage: "mappin.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.maplogMuted)
                            .lineLimit(1)
                        Text(draft.metadata)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.maplogMuted)
                            .lineLimit(1)
                        Text(draft.updatedAtText)
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(Color.maplogOlive)
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 42, height: 42)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(draft.title) 임시저장 삭제")
        }
        .padding(MaplogSpacing.small)
        .maplogCard()
    }
}

struct MyLogDetailView: View {
    let log: TravelLog
    var onDelete: (TravelLog) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss
    @State private var selectedClip = 0
    @State private var showDeleteDialog = false
    @State private var showsShareSheet = false
    @State private var toastText: String?

    private var spot: MaplogSpot {
        MockMaplogData.spots.first { log.place.contains($0.name) || $0.name.contains(log.place) } ?? MockMaplogData.seoulTower
    }

    private var previewDraft: ComposerDraft {
        ComposerDraft(
            placeName: log.place,
            title: log.title,
            mood: "기록",
            rating: 5,
            note: log.note,
            imageStyle: log.imageStyle,
            clipCount: log.clips
        )
    }

    private var durationText: String {
        let safeClips = max(log.clips, 1)
        return "약 \(safeClips)–\(safeClips * 2)초"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    VStack(alignment: .leading, spacing: MaplogSpacing.section) {
                        summaryCard
                        clipStrip
                        relatedPlaceCard
                        routeCard
                    }
                    .padding(.horizontal, MaplogSpacing.page)
                    .padding(.bottom, 116)
                }
            }
            .ignoresSafeArea(edges: .top)

            bottomActionBar

            if let toastText {
                Text(toastText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 48)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
                    .padding(.bottom, 98)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showsShareSheet) {
            LogShareSheet(log: log) { message in
                showToast(message)
            }
            .presentationDetents([.height(334)])
            .presentationDragIndicator(.visible)
        }
        .alert("기록을 삭제하시겠어요?", isPresented: $showDeleteDialog) {
            Button("삭제", role: .destructive) {
                deleteLog()
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("삭제된 기록은 복구할 수 없습니다.")
        }
        .background(Color(uiColor: .systemBackground))
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .maplogTabBarHidden()
    }

    private var header: some View {
        TravelImageView(style: log.imageStyle, height: 360, cornerRadius: 0, showsSymbol: false)
            .overlay {
                LinearGradient(colors: [.black.opacity(0.36), .clear, .black.opacity(0.68)], startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .top) {
                HStack {
                    detailCircleButton(systemImage: "chevron.left") {
                        dismiss()
                    }
                    Spacer()
                    detailCircleButton(systemImage: "square.and.arrow.up") {
                        showsShareSheet = true
                    }
                }
                .padding(.horizontal, MaplogSpacing.page)
                .padding(.top, 54)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("\(log.city) · \(log.date)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                    Text(log.title)
                        .font(.title.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(log.place)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.88))
                }
                .padding(MaplogSpacing.large)
            }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            HStack(spacing: 6) {
                Text("\(log.clips)개 클립")
                Text("·")
                Text(durationText)
                Text("·")
                Text("공개")
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)

            Text(log.note)
                .font(.body)
                .foregroundStyle(.primary)
                .lineSpacing(3)

            Text("#\(log.city)  ·  #여행기록  ·  #루트")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.maplogOlive)
        }
    }

    private var clipStrip: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Text("클립 \(log.clips)개")
                .font(.title3.weight(.semibold))
            Text("장면을 탭해 대표 이미지를 볼 수 있어요")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MaplogSpacing.small) {
                    ForEach(0..<log.clips, id: \.self) { index in
                        Button {
                            selectedClip = index
                            showToast("\(index + 1)번째 클립을 선택했어요")
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                TravelImageView(style: clipStyle(for: index), height: 148, cornerRadius: MaplogRadius.large, showsSymbol: false)
                                    .frame(width: 112)
                                Text("\(index + 1)번째 장면")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                            .opacity(selectedClip == index ? 1 : 0.62)
                        }
                        .buttonStyle(MaplogPressFeedbackStyle())
                        .accessibilityLabel("\(index + 1)번째 클립")
                        .accessibilityValue(selectedClip == index ? "선택됨" : "선택되지 않음")
                    }
                }
            }
        }
    }

    private var relatedPlaceCard: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            SectionHeader(title: "기록한 장소")

            NavigationLink {
                SpotDetailView(spot: spot)
            } label: {
                HStack(spacing: MaplogSpacing.small) {
                    MaplogSpotImageView(spot: spot, height: 84, cornerRadius: MaplogRadius.medium)
                        .frame(width: 84)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(spot.category) · \(spot.area)")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(spot.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(String(format: "평점 %.1f", spot.rating))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .frame(minHeight: 84)
                .contentShape(Rectangle())
            }
            .buttonStyle(MaplogPressFeedbackStyle())
        }
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            SectionHeader(title: "이 로그의 이동 경로")

            NavigationLink {
                RouteDetailView(trip: MockMaplogData.trips[0])
            } label: {
                VStack(alignment: .leading, spacing: MaplogSpacing.small) {
                    TravelImageView(
                        style: MockMaplogData.trips[0].coverStyle,
                        height: 188,
                        cornerRadius: MaplogRadius.large,
                        showsSymbol: false
                    )
                    Text(MockMaplogData.trips[0].title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(MockMaplogData.trips[0].subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text("\(MockMaplogData.trips[0].location) · \(MockMaplogData.trips[0].spots.count)개 장소")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(MaplogPressFeedbackStyle())
        }
    }

    private var bottomActionBar: some View {
        HStack(spacing: MaplogSpacing.small) {
            Button {
                showDeleteDialog = true
            } label: {
                Label("삭제", systemImage: "trash")
                    .font(.headline)
                    .foregroundStyle(Color.maplogDanger)
                    .frame(minWidth: 72, minHeight: 56)
            }
            .buttonStyle(MaplogPressFeedbackStyle())
            .accessibilityHint("이 기록을 삭제합니다")

            NavigationLink {
                LogPreviewView(draft: previewDraft)
            } label: {
                Label("완성 영상 보기", systemImage: "play.circle.fill")
                    .font(MaplogFont.cardTitle)
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.maplogLime)
                    .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous))
            }
            .buttonStyle(MaplogPressFeedbackStyle())
        }
        .padding(.horizontal, MaplogSpacing.page)
        .padding(.top, 12)
        .padding(.bottom, 22)
        .background(.regularMaterial)
    }

    private func detailCircleButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(MaplogFont.cardTitle)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .shadow(color: .black.opacity(0.30), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(MaplogPressFeedbackStyle())
    }

    private func clipStyle(for index: Int) -> PhotoStyle {
        let styles = [log.imageStyle, spot.imageStyle, PhotoStyle.city, PhotoStyle.cafe, PhotoStyle.palace]
        return styles[index % styles.count]
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

    private func deleteLog() {
        onDelete(log)
        dismiss()
    }
}

private struct LogShareSheet: View {
    let log: TravelLog
    let onAction: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.large) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("기록 공유")
                        .font(MaplogFont.screenTitle)
                        .foregroundStyle(Color.maplogInk)
                    Text(log.title)
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

            HStack(spacing: 10) {
                shareOption(title: "링크", systemImage: "link") {
                    complete("기록 링크를 복사했어요")
                }
                shareOption(title: "친구", systemImage: "person.2.fill") {
                    complete("친구에게 기록을 보냈어요")
                }
                shareOption(title: "카드", systemImage: "square.and.arrow.down") {
                    complete("기록 카드를 저장했어요")
                }
            }

            HStack(spacing: MaplogSpacing.small) {
                TravelImageView(style: log.imageStyle, height: 86, cornerRadius: MaplogRadius.medium, showsSymbol: false)
                    .frame(width: 86)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(log.city) · \(log.date)")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.maplogMuted)
                    Text(log.title)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .lineLimit(2)
                    Text("\(log.place) · \(log.clips) clips")
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

struct ProfileEditView: View {
    var onSave: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @State private var displayName = "채림"
    @State private var location = "Seoul"
    @State private var bio = "모험을 사랑하는 여행자 ✈️ 새로운 맵로그를 찾아서"
    @State private var isPublic = true
    @State private var avatarStyle: PhotoStyle = .night
    @State private var editToastText = "프로필 사진 미리보기를 변경했어요"
    @State private var showsSavedToast = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(spacing: MaplogSpacing.small) {
                        ProfileAvatarImage(size: 96)
                        Button {
                            rotateAvatarStyle()
                        } label: {
                            Label("사진 변경", systemImage: "camera.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.maplogInk)
                                .padding(.horizontal, 14)
                                .frame(height: 38)
                                .background(Color.maplogCanvas)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)

                    editField(title: "이름", text: $displayName)
                    editField(title: "지역", text: $location)

                    VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                        Text("소개")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.maplogMuted)
                        TextField("소개를 입력하세요", text: $bio, axis: .vertical)
                            .lineLimit(3...5)
                            .font(.system(size: 16, weight: .medium))
                            .padding(14)
                            .background(Color.maplogCanvas)
                            .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous))
                    }

                    Toggle(isOn: $isPublic) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("프로필 공개")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.maplogInk)
                            Text("다른 사용자가 내 맵로그와 저장 루트를 볼 수 있어요.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.maplogMuted)
                        }
                    }
                    .tint(Color.maplogLime)
                    .padding(MaplogSpacing.medium)
                    .maplogCard()
                }
                .padding(MaplogSpacing.large)
                .padding(.bottom, 110)
            }

            VStack(spacing: MaplogSpacing.xSmall) {
                if showsSavedToast {
                    Text(editToastText)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, MaplogSpacing.medium)
                        .frame(height: 44)
                        .background(Color.maplogSurface)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: 8)
                }

                PrimaryActionButton("저장", systemImage: "checkmark") {
                    saveProfile()
                }
                .padding(.horizontal, MaplogSpacing.page)
            }
            .padding(.bottom, 22)
        }
        .navigationTitle("프로필 편집")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.maplogSurface)
        .maplogTabBarHidden()
        .onAppear(perform: loadProfile)
    }

    private func editField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.maplogMuted)
            TextField(title, text: text)
                .font(.system(size: 16, weight: .medium))
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Color.maplogCanvas)
                .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous))
        }
    }

    private func loadProfile() {
        displayName = sessionStore.profile.displayName
        location = sessionStore.profile.location
        bio = sessionStore.profile.bio
        isPublic = sessionStore.profile.isPublic
        avatarStyle = sessionStore.profile.avatarStyle
    }

    private func rotateAvatarStyle() {
        let styles: [PhotoStyle] = [.night, .city, .forest, .cafe, .palace]
        let currentIndex = styles.firstIndex(of: avatarStyle) ?? 0
        avatarStyle = styles[(currentIndex + 1) % styles.count]
        showsSavedToastTemporarily("프로필 사진 미리보기를 변경했어요")
    }

    private func saveProfile() {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = MaplogUserProfile(
            displayName: trimmedName.isEmpty ? "채림" : trimmedName,
            location: trimmedLocation.isEmpty ? "Seoul" : trimmedLocation,
            bio: trimmedBio.isEmpty ? "새로운 맵로그를 찾아서" : trimmedBio,
            isPublic: isPublic,
            avatarStyle: avatarStyle
        )
        sessionStore.updateProfile(profile)
        onSave?()
        dismiss()
    }

    private func showsSavedToastTemporarily(_ message: String) {
        editToastText = message
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            showsSavedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                showsSavedToast = false
            }
        }
    }
}
