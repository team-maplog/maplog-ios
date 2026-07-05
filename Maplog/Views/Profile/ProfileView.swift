import SwiftUI

private enum ProfileContentTab: String, CaseIterable {
    case logs = "로그"
    case savedRoutes = "저장된 경로"
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

    private static func durationText(for clips: Int) -> String {
        let totalSeconds = max(clips, 1) * 15
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    topBar
                    profileHeader
                    NavigationLink {
                        ProfileEditView {
                            showToast("프로필을 저장했어요")
                        }
                    } label: {
                        Label("프로필 편집", systemImage: "pencil")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.maplogInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.maplogLime)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                        savedPlacesShortcut
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
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .background(.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
                    .padding(.bottom, 92)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        HStack {
           
            Text("Maplog")
                .font(.system(size: 21, weight: .black))
                .foregroundStyle(Color.maplogOlive)
        }
        .font(.system(size: 21, weight: .bold))
        .foregroundStyle(Color.maplogOlive)
        .padding(.top, 18)
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 22) {
                ZStack(alignment: .bottomTrailing) {
                    TravelImageView(style: sessionStore.profile.avatarStyle, height: 78, cornerRadius: 39)
                        .frame(width: 78)
                        .overlay(Circle().stroke(Color.maplogLime, lineWidth: 3))
                    Image(systemName: sessionStore.profile.isPublic ? "checkmark.seal.fill" : "lock.circle.fill")
                        .font(.system(size: 21))
                        .foregroundStyle(Color.maplogLime)
                        .background(Circle().fill(.white))
                }

                ForEach(viewModel.stats(logCount: profileLogs.count), id: \.0) { stat in
                    VStack(spacing: 4) {
                        Text(stat.1)
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                        Text(stat.0)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.maplogMuted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(sessionStore.profile.displayName)
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                Label(sessionStore.profile.location, systemImage: "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.maplogMuted)
                Text(sessionStore.profile.bio)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.maplogMuted)
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
                            .font(.system(size: 16, weight: selectedTab == tab ? .black : .medium))
                            .foregroundStyle(selectedTab == tab ? Color.maplogInk : Color.maplogMuted)
                        Capsule()
                            .fill(selectedTab == tab ? Color.maplogLime : .clear)
                            .frame(height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Color.white.opacity(0.001))
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("\(tab.rawValue) 탭")
                .buttonStyle(.plain)
            }
        }
        .background(Color.white)
        .zIndex(2)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.maplogLine)
                .frame(height: 1)
        }
    }

    private var logGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 18) {
            ForEach(profileLogs) { log in
                NavigationLink {
                    MyLogDetailView(log: log) { deletedLog in
                        deleteLog(deletedLog)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        TravelImageView(style: log.imageStyle, height: 180)
                            .overlay(alignment: .bottomLeading) {
                                Label("\(log.city) · \(Self.durationText(for: log.clips))", systemImage: "mappin.circle.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(8)
                            }
                        Text(log.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.maplogInk)
                        Text("\(log.clips) clips · \(log.date)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.maplogMuted)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var draftSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "작성 중", subtitle: "\(sessionStore.savedDrafts.count)개 임시저장 로그")
            VStack(spacing: 12) {
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
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Color.maplogInk)
            Text("촬영 탭에서 새 맵로그를 만들면 여기에 다시 쌓입니다.")
                .font(.system(size: 14, weight: .medium))
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
            HStack(spacing: 12) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 48, height: 48)
                    .background(Color.maplogLime)
                    .clipShape(Circle())

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
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 48, height: 48)
                    .background(Color.maplogCanvas)
                    .clipShape(Circle())

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
        VStack(spacing: 12) {
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
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Color.maplogInk)
            Text("루트 상세에서 저장하면 이 탭과 루트 보관함에 바로 표시됩니다.")
                .font(.system(size: 14, weight: .medium))
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
                    TravelImageView(style: draft.imageStyle, height: 86, cornerRadius: 8, showsSymbol: false)
                        .frame(width: 86)
                        .overlay(alignment: .topLeading) {
                            Text("작성 중")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(Color.maplogInk)
                                .padding(.horizontal, 8)
                                .frame(height: 24)
                                .background(Color.maplogLime)
                                .clipShape(Capsule())
                                .padding(7)
                        }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(draft.title)
                            .font(.system(size: 17, weight: .black))
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
                    .background(Color.maplogCanvas)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(draft.title) 임시저장 삭제")
        }
        .padding(12)
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
        let totalSeconds = max(log.clips, 1) * 15
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    VStack(alignment: .leading, spacing: 20) {
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
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .background(.white)
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
        .confirmationDialog("기록을 삭제하시겠어요?", isPresented: $showDeleteDialog, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                deleteLog()
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("삭제된 기록은 복구할 수 없습니다.")
        }
        .background(Color.white)
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
                    detailCircleButton(systemImage: "ellipsis") {
                        showDeleteDialog = true
                    }
                }
                .padding(.horizontal, MaplogSpacing.page)
                .padding(.top, 54)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("\(log.city) · \(log.date)")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Color.maplogLime)
                        .clipShape(Capsule())
                    Text(log.title)
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(.white)
                    Text(log.place)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.88))
                }
                .padding(20)
            }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label("\(log.clips) clips", systemImage: "play.rectangle.fill")
                Spacer()
                Label(durationText, systemImage: "clock.fill")
                Spacer()
                Label("공개", systemImage: "eye.fill")
            }
            .font(.system(size: 13, weight: .black))
            .foregroundStyle(Color.maplogMuted)

            Text(log.note)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.maplogInk)
                .lineSpacing(5)

            HStack(spacing: 8) {
                ChipView(title: "#\(log.city)", isSelected: true)
                ChipView(title: "#여행기록")
                ChipView(title: "#루트")
            }
        }
        .padding(16)
        .maplogCard()
        .padding(.top, -36)
    }

    private var clipStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "클립", subtitle: "선택한 클립은 대표 미리보기로 표시됩니다")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<log.clips, id: \.self) { index in
                        Button {
                            selectedClip = index
                            showToast("\(index + 1)번째 클립을 선택했어요")
                        } label: {
                            TravelImageView(style: clipStyle(for: index), height: 132, cornerRadius: 12, showsSymbol: false)
                                .frame(width: 96)
                                .overlay(alignment: .topLeading) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 12, weight: .black))
                                        .foregroundStyle(Color.maplogInk)
                                        .frame(width: 24, height: 24)
                                        .background(selectedClip == index ? Color.maplogLime : .white)
                                        .clipShape(Circle())
                                        .padding(8)
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(selectedClip == index ? Color.maplogLime : .clear, lineWidth: 4)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var relatedPlaceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "기록한 장소")

            NavigationLink {
                SpotDetailView(spot: spot)
            } label: {
                SpotRowCard(spot: spot)
            }
            .buttonStyle(.plain)
        }
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "함께 보기 좋은 루트")

            NavigationLink {
                RouteDetailView(trip: MockMaplogData.trips[0])
            } label: {
                TripCardView(trip: MockMaplogData.trips[0], isLarge: true)
            }
            .buttonStyle(.plain)
        }
    }

    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            Button {
                showDeleteDialog = true
            } label: {
                Label("삭제", systemImage: "trash")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.red)
                    .frame(width: 84, height: 56)
                    .background(Color.maplogCanvas)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            NavigationLink {
                LogPreviewView(draft: previewDraft)
            } label: {
                Label("미리보기 열기", systemImage: "play.circle.fill")
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

    private func detailCircleButton(systemImage: String, action: @escaping () -> Void) -> some View {
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
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("기록 공유")
                        .font(.system(size: 24, weight: .black))
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
                        .frame(width: 36, height: 36)
                        .background(Color.maplogCanvas)
                        .clipShape(Circle())
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

            HStack(spacing: 12) {
                TravelImageView(style: log.imageStyle, height: 86, cornerRadius: 12, showsSymbol: false)
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
                    VStack(spacing: 12) {
                        TravelImageView(style: avatarStyle, height: 96, cornerRadius: 48)
                            .frame(width: 96)
                            .overlay(Circle().stroke(Color.maplogLime, lineWidth: 3))
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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("소개")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.maplogMuted)
                        TextField("소개를 입력하세요", text: $bio, axis: .vertical)
                            .lineLimit(3...5)
                            .font(.system(size: 16, weight: .medium))
                            .padding(14)
                            .background(Color.maplogCanvas)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                    .padding(16)
                    .maplogCard()
                }
                .padding(20)
                .padding(.bottom, 110)
            }

            VStack(spacing: 8) {
                if showsSavedToast {
                    Text(editToastText)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background(.white)
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
        .background(Color.white)
        .maplogTabBarHidden()
        .onAppear(perform: loadProfile)
    }

    private func editField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.maplogMuted)
            TextField(title, text: text)
                .font(.system(size: 16, weight: .medium))
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Color.maplogCanvas)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
