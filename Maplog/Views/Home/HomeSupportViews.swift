import SwiftUI

struct LocationPermissionView: View {
    let onAllow: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            LocationPermissionArtwork(size: 136, iconSize: 54)
                .padding(.bottom, 38)

            LocationPermissionCopy()

            Spacer()

            LocationPermissionActions(
                primaryTitle: "위치 권한 허용",
                onAllow: onAllow,
                onSkip: onSkip
            )
            .padding(.bottom, 26)
        }
        .padding(.horizontal, MaplogSpacing.page)
        .background(Color.maplogSurface)
    }
}

struct LocationPermissionPromptSheet: View {
    let onAllow: () -> Void
    let onSkip: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.maplogLine)
                .frame(width: 42, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 22)

            LocationPermissionArtwork(size: 104, iconSize: 42)
                .padding(.bottom, 22)

            LocationPermissionCopy()
                .padding(.bottom, 28)

            LocationPermissionActions(
                primaryTitle: "위치 권한 켜기",
                onAllow: {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        onAllow()
                    }
                },
                onSkip: {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        onSkip()
                    }
                }
            )
        }
        .padding(.horizontal, MaplogSpacing.page)
        .padding(.bottom, 18)
        .background(Color.maplogSurface)
    }
}

private struct LocationPermissionArtwork: View {
    let size: CGFloat
    let iconSize: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.maplogLime.opacity(0.22))
                .frame(width: size, height: size)
                .blur(radius: 18)
            Circle()
                .fill(Color.maplogLime.opacity(0.18))
                .frame(width: size * 0.72, height: size * 0.72)
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(Color.maplogOlive)
        }
        .frame(width: size, height: size)
    }
}

private struct LocationPermissionCopy: View {
    var body: some View {
        VStack(spacing: MaplogSpacing.small) {
            Text("내 주변 여행 로그를 찾을까요?")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.maplogInk)
                .multilineTextAlignment(.center)
            Text("현재 위치를 기준으로 가까운 행사와 Maplog 루트를 추천해드려요.")
                .font(MaplogFont.callout)
                .foregroundStyle(Color.maplogMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.horizontal, MaplogSpacing.xLarge)
    }
}

private struct LocationPermissionActions: View {
    let primaryTitle: String
    let onAllow: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Button(action: onAllow) {
                Text(primaryTitle)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())
                    .shadow(color: Color.maplogLime.opacity(0.22), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.plain)

            Button("나중에 하기", action: onSkip)
                .font(MaplogFont.callout)
                .foregroundStyle(Color.maplogMuted)
                .buttonStyle(.plain)
        }
    }
}

private enum NoticeDestination {
    case route
    case event
    case spot
    case settings
}

private struct MaplogNotice: Identifiable {
    let id: String
    let title: String
    let message: String
    let time: String
    let category: String
    let icon: String
    let style: PhotoStyle?
    let destination: NoticeDestination
    let isUnread: Bool
}

private extension FeaturedEvent {
    static let seongsuNightPopup = FeaturedEvent(
        id: "event-seongsu-night-popup",
        title: "성수 야간 팝업 페스타",
        period: "2026. 6. 19. ~ 2026. 6. 21.",
        location: "성수동",
        imageStyle: .festival
    )
}

struct NotificationsView: View {
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @State private var selectedFilter = "전체"
    @State private var toastText: String?

    private let filters = ["전체", "활동", "추천", "시스템"]
    private let notices: [MaplogNotice] = [
        MaplogNotice(id: "notice-activity", title: "민지님이 내 Maplog를 저장했어요.", message: "성수동 힙플 투어 4컷 완벽 정리가 새로운 보관함에 저장되었습니다.", time: "10분 전", category: "활동", icon: "person.crop.circle.fill", style: .cafe, destination: .spot, isUnread: true),
        MaplogNotice(id: "notice-event", title: "성수동에서 오늘 열리는 야간 행사가 있어요!", message: "현재 위치 기준으로 오늘 방문하기 좋은 팝업 페스타를 발견했어요.", time: "1시간 전", category: "추천", icon: "calendar.badge.clock", style: .festival, destination: .event, isUnread: true),
        MaplogNotice(id: "notice-comment", title: "도윤님이 내 루트에 댓글을 남겼어요.", message: "\"여기 꼭 가봐야겠네요!\"라는 댓글이 달렸습니다.", time: "어제", category: "활동", icon: "message.fill", style: .ocean, destination: .route, isUnread: false),
        MaplogNotice(id: "notice-system", title: "Maplog v2.1로 업데이트 되었습니다.", message: "새로운 루트 추천 카드와 지도 저장 흐름을 확인해보세요.", time: "2일 전", category: "시스템", icon: "arrow.clockwise.circle.fill", style: nil, destination: .settings, isUnread: false)
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    notificationSummary

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(filters, id: \.self) { filter in
                                Button {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                        selectedFilter = filter
                                    }
                                } label: {
                                    ChipView(title: filter, isSelected: selectedFilter == filter)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if filteredNotices.isEmpty {
                        emptyNotifications
                    } else {
                        ForEach(filteredNotices) { notice in
                            ZStack(alignment: .topTrailing) {
                                NavigationLink {
                                    NotificationDetailView(notice: notice)
                                } label: {
                                    NoticeCard(
                                        notice: notice,
                                        isUnread: isUnread(notice)
                                    )
                                }
                                .buttonStyle(.plain)
                                .simultaneousGesture(TapGesture().onEnded {
                                    markRead(notice)
                                })

                                Button {
                                    deleteNotice(notice)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(Color.maplogMuted.opacity(0.86))
                                        .frame(width: 34, height: 34)
                                        .contentShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 10)
                                .padding(.trailing, 10)
                            }
                        }
                    }
                }
                .padding(MaplogSpacing.large)
                .padding(.bottom, 104)
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
                    .padding(.bottom, 26)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("알림")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: MaplogSpacing.small) {
                    Button {
                        markAllRead()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(filteredNotices.isEmpty ? Color.maplogMuted : Color.maplogInk)
                    }
                    .buttonStyle(.plain)
                    .disabled(filteredNotices.isEmpty)

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.maplogInk)
                    }
                }
            }
        }
        .background(Color.maplogCanvas.opacity(0.45))
    }

    private var filteredNotices: [MaplogNotice] {
        guard sessionStore.notificationSettings.pushNotificationsEnabled else {
            return []
        }

        let visible = notices.filter { notice in
            !sessionStore.deletedNoticeIDs.contains(notice.id)
                && (sessionStore.notificationSettings.serviceAnnouncementsEnabled || notice.category != "시스템")
        }
        return selectedFilter == "전체" ? visible : visible.filter { $0.category == selectedFilter }
    }

    private var unreadCount: Int {
        filteredNotices.filter { isUnread($0) }.count
    }

    private var notificationSummary: some View {
        HStack(spacing: MaplogSpacing.small) {
            Image(systemName: notificationSummaryIcon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.maplogPrimary)
                .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)

            VStack(alignment: .leading, spacing: 4) {
                Text(notificationSummaryTitle)
                    .font(MaplogFont.cardTitle)
                    .foregroundStyle(Color.maplogInk)
                Text(notificationSummarySubtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.maplogMuted)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.maplogSurface)
        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 16, x: 0, y: 6)
    }

    private var notificationSummaryIcon: String {
        if !sessionStore.notificationSettings.pushNotificationsEnabled {
            return "bell.slash.fill"
        }
        return unreadCount == 0 ? "bell.badge.slash" : "bell.badge.fill"
    }

    private var notificationSummaryTitle: String {
        if !sessionStore.notificationSettings.pushNotificationsEnabled {
            return "푸시 알림이 꺼져 있어요"
        }
        return unreadCount == 0 ? "새 알림이 없어요" : "읽지 않은 알림 \(unreadCount)개"
    }

    private var notificationSummarySubtitle: String {
        if !sessionStore.notificationSettings.pushNotificationsEnabled {
            return "설정에서 다시 켜면 여행 추천과 활동 알림을 받을 수 있어요."
        }
        if !sessionStore.notificationSettings.serviceAnnouncementsEnabled {
            return "서비스 공지 알림은 설정에서 꺼져 있어요."
        }
        return "알림을 누르면 읽음 처리되고 관련 화면으로 이동합니다."
    }

    private var emptyNotifications: some View {
        VStack(spacing: MaplogSpacing.small) {
            Image(systemName: "bell.slash")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.maplogMuted)
            Text(emptyNotificationTitle)
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(Color.maplogInk)
            Text(emptyNotificationSubtitle)
                .font(MaplogFont.callout)
                .foregroundStyle(Color.maplogMuted)
                .multilineTextAlignment(.center)
            Button {
                handleEmptyNotificationAction()
            } label: {
                Text(emptyNotificationActionTitle)
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
        .padding(.vertical, 32)
        .padding(.horizontal, MaplogSpacing.medium)
        .background(Color.maplogSurface)
        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 16, x: 0, y: 6)
    }

    private var emptyNotificationTitle: String {
        if !sessionStore.notificationSettings.pushNotificationsEnabled {
            return "푸시 알림이 꺼져 있어요"
        }
        return "표시할 알림이 없어요"
    }

    private var emptyNotificationSubtitle: String {
        if !sessionStore.notificationSettings.pushNotificationsEnabled {
            return "새 여행 추천과 활동 알림을 다시 받으려면 푸시 알림을 켜주세요."
        }
        return "필터를 바꾸거나 새 알림이 도착하면 여기에 표시됩니다."
    }

    private var emptyNotificationActionTitle: String {
        sessionStore.notificationSettings.pushNotificationsEnabled ? "전체 보기" : "푸시 알림 켜기"
    }

    private func handleEmptyNotificationAction() {
        if sessionStore.notificationSettings.pushNotificationsEnabled {
            selectedFilter = "전체"
            showToast("전체 알림으로 돌아왔어요")
        } else {
            sessionStore.setPushNotificationsEnabled(true)
            selectedFilter = "전체"
            showToast("푸시 알림을 다시 켰어요")
        }
    }

    private func isUnread(_ notice: MaplogNotice) -> Bool {
        notice.isUnread && !sessionStore.readNoticeIDs.contains(notice.id)
    }

    private func markRead(_ notice: MaplogNotice) {
        if isUnread(notice) {
            sessionStore.markNoticeRead(id: notice.id)
        }
    }

    private func markAllRead() {
        sessionStore.markAllNoticesRead(ids: notices.map(\.id))
        showToast("모든 알림을 읽음 처리했어요")
    }

    private func deleteNotice(_ notice: MaplogNotice) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            sessionStore.deleteNotice(id: notice.id)
        }
        showToast("알림을 삭제했어요")
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

private struct NoticeCard: View {
    let notice: MaplogNotice
    let isUnread: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .topLeading) {
                Circle()
                    .fill(isUnread ? Color.maplogLime.opacity(0.88) : Color.maplogLine)
                    .frame(width: 58, height: 58)
                Image(systemName: notice.icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(isUnread ? Color.maplogInk : Color.maplogMuted)

                if isUnread {
                    Circle()
                        .fill(Color.maplogLime)
                        .frame(width: 9, height: 9)
                        .offset(x: -5, y: -2)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(notice.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .lineLimit(2)
                Text(notice.message)
                    .font(MaplogFont.callout)
                    .foregroundStyle(Color.maplogMuted)
                    .lineLimit(2)
                Text(notice.time)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.maplogMuted.opacity(0.8))
            }

            Spacer(minLength: 0)

            if let style = notice.style {
                TravelImageView(style: style, height: 54, cornerRadius: 10, showsSymbol: false)
                    .frame(width: 54)
                    .padding(.trailing, 18)
            } else {
                Spacer()
                    .frame(width: 28)
            }
        }
        .padding(MaplogSpacing.medium)
        .background(Color.maplogSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 16, x: 0, y: 6)
    }
}

private struct NotificationDetailView: View {
    let notice: MaplogNotice
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: MaplogSessionStore

    private var isRead: Bool {
        !notice.isUnread || sessionStore.readNoticeIDs.contains(notice.id)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.maplogLime)
                            .frame(width: 58, height: 58)
                        Image(systemName: notice.icon)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color.maplogInk)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(notice.category)
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Color.maplogMuted)
                        Text(notice.time)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.maplogMuted)
                    }
                    Spacer()
                    Label(isRead ? "읽음" : "새 알림", systemImage: isRead ? "checkmark.circle.fill" : "circle.fill")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(isRead ? Color.maplogMuted : Color.maplogInk)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(isRead ? Color.maplogCanvas : Color.maplogLime)
                        .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: MaplogSpacing.small) {
                    Text(notice.title)
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                    Text(notice.message)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.maplogMuted)
                        .lineSpacing(5)
                }

                if let style = notice.style {
                    TravelImageView(style: style, height: 220, showsSymbol: false)
                }

                VStack(spacing: 10) {
                    NavigationLink {
                        destinationView
                    } label: {
                        Label("관련 화면 보기", systemImage: "arrow.right.circle.fill")
                            .font(MaplogFont.cardTitle)
                            .foregroundStyle(Color.maplogInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.maplogLime)
                            .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        deleteCurrentNotice()
                    } label: {
                        Label("알림 삭제", systemImage: "trash")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.maplogCanvas)
                            .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(MaplogSpacing.large)
        }
        .navigationTitle("알림 상세")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.maplogSurface)
        .maplogTabBarHidden()
        .onAppear {
            sessionStore.markNoticeRead(id: notice.id)
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch notice.destination {
        case .route:
            RouteDetailView(trip: MockMaplogData.trips[1])
        case .event:
            FeaturedEventDetailView(event: .seongsuNightPopup)
        case .spot:
            SpotDetailView(spot: MockMaplogData.forestCafe)
        case .settings:
            SettingsView()
        }
    }

    private func deleteCurrentNotice() {
        sessionStore.deleteNotice(id: notice.id)
        dismiss()
    }
}

struct ServiceDetailView: View {
    let title: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @State private var selectedCategory = "Food"
    @State private var toastText: String?
    @State private var showsIssueSheet = false
    @State private var showsShareSheet = false

    private var profile: TourismServiceProfile {
        TourismServiceProfile.make(for: title)
    }

    private var visibleBenefits: [TourismBenefit] {
        profile.benefits.filter { selectedCategory == "All" || $0.category == selectedCategory }
    }

    private var isIssued: Bool {
        sessionStore.hasIssuedServicePass(title: profile.title)
    }

    private var issuedBinding: Binding<Bool> {
        Binding(
            get: { isIssued },
            set: { shouldIssue in
                if shouldIssue {
                    sessionStore.issueServicePass(servicePass)
                } else {
                    sessionStore.revokeServicePass(title: profile.title)
                }
            }
        )
    }

    private var servicePass: MaplogServicePass {
        MaplogServicePass(
            title: profile.title,
            issuedTitle: profile.issuedTitle,
            badge: profile.badge,
            summary: profile.summary,
            heroStyle: profile.heroStyle
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                serviceTopBar

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        serviceHero
                        issueButton
                        if isIssued {
                            issuedPassConfirmation
                        }
                        benefitSection
                        howToUseSection
                        nearbyRouteCard
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                    .padding(.bottom, 112)
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
                    .padding(.bottom, 26)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showsIssueSheet) {
            ServiceIssueSheet(profile: profile, isIssued: issuedBinding) { message in
                showToast(message)
            }
                .presentationDetents([.height(isIssued ? 424 : 360)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsShareSheet) {
            ServiceShareSheet(profile: profile, isIssued: isIssued) { message in
                showToast(message)
            }
            .presentationDetents([.height(342)])
            .presentationDragIndicator(.visible)
        }
        .background(Color.maplogCanvas.opacity(0.48))
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .maplogTabBarHidden()
        .onAppear {
            selectedCategory = profile.categories.first ?? "All"
        }
    }

    private var serviceTopBar: some View {
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
            Text(title)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.maplogInk)
                .lineLimit(1)
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
        .padding(.horizontal, 14)
        .frame(height: 64)
        .background(Color.maplogSurface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.maplogLine).frame(height: 1)
        }
    }

    private var serviceHero: some View {
        TravelImageView(style: profile.heroStyle, height: 196, showsSymbol: false)
            .overlay {
                LinearGradient(
                    colors: [.black.opacity(0.05), .black.opacity(0.68)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(profile.badge)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, MaplogSpacing.small)
                        .padding(.vertical, 7)
                        .background(Color.maplogLime)
                        .clipShape(Capsule())

                    Text(profile.headline)
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(.white)
                        .lineSpacing(2)

                    Text(profile.summary)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                }
                .padding(18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
    }

    private var issueButton: some View {
        Button {
            showsIssueSheet = true
        } label: {
            Label(isIssued ? profile.issuedTitle : profile.ctaTitle, systemImage: isIssued ? "checkmark.seal.fill" : "person.text.rectangle.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.maplogInk)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(Color.maplogLime)
                .clipShape(Capsule())
                .shadow(color: Color.maplogLime.opacity(0.35), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var issuedPassConfirmation: some View {
        SavedConfirmationCard(
            title: "여행 패스가 발급됨",
            subtitle: "보관함에서 패스 혜택과 주변 장소를 다시 확인할 수 있어요.",
            buttonTitle: "보관함에서 확인",
            systemImage: "ticket.fill"
        ) {
            SavedView()
        }
    }

    private var benefitSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                Text("혜택 받는 장소 찾기")
                    .font(MaplogFont.sectionTitle)
                    .foregroundStyle(Color.maplogInk)
                Spacer()
                Text("\(visibleBenefits.count)곳")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.maplogMuted)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(profile.categories, id: \.self) { category in
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                selectedCategory = category
                            }
                        } label: {
                            ChipView(title: profile.categoryTitle(category), isSelected: selectedCategory == category)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(spacing: 14) {
                ForEach(visibleBenefits) { benefit in
                    ZStack(alignment: .topTrailing) {
                        NavigationLink {
                            SpotDetailView(spot: benefit.spot)
                        } label: {
                            ServiceBenefitCard(
                                benefit: benefit,
                                isSaved: sessionStore.hasSavedSpot(benefit.spot)
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            toggleSave(benefit)
                        } label: {
                            Text(sessionStore.hasSavedSpot(benefit.spot) ? "저장됨" : benefit.discount)
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(Color.maplogInk)
                                .padding(.horizontal, 10)
                                .frame(height: 28)
                                .background(Color.maplogLime)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 14)
                        .padding(.trailing, 14)
                    }
                }
            }
        }
    }

    private var howToUseSection: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            SectionHeader(title: "이용 방법", subtitle: "발급부터 혜택 확인까지 한눈에 정리했어요.")

            VStack(spacing: 10) {
                ForEach(Array(profile.steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: MaplogSpacing.small) {
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                            .frame(width: 32, height: 32)
                            .background(Color.maplogLime)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.title)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.maplogInk)
                            Text(step.subtitle)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.maplogMuted)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.maplogSurface)
                    .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
                }
            }
        }
    }

    private var nearbyRouteCard: some View {
        NavigationLink {
            MapSearchView(query: profile.routeQuery)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "map.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.maplogPrimary)
                    .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)

                VStack(alignment: .leading, spacing: 5) {
                    Text("지도에서 혜택 루트 보기")
                        .font(MaplogFont.cardTitle)
                        .foregroundStyle(Color.maplogInk)
                    Text(profile.routeSummary)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.maplogMuted)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.maplogMuted)
            }
            .padding(MaplogSpacing.medium)
            .background(Color.maplogSurface)
            .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private func toggleSave(_ benefit: TourismBenefit) {
        if sessionStore.hasSavedSpot(benefit.spot) {
            sessionStore.removeSavedSpot(benefit.spot)
            showToast("혜택 장소 저장을 해제했어요")
        } else {
            sessionStore.saveSpot(benefit.spot)
            showToast("\(benefit.name)을 혜택 장소에 저장했어요")
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
}

private struct TourismStep {
    let title: String
    let subtitle: String
}

private struct TourismBenefit: Identifiable {
    let id: String
    let name: String
    let location: String
    let category: String
    let discount: String
    let tags: [String]
    let imageStyle: PhotoStyle
    let spot: MaplogSpot
}

private struct TourismServiceProfile {
    let title: String
    let badge: String
    let headline: String
    let summary: String
    let ctaTitle: String
    let issuedTitle: String
    let heroStyle: PhotoStyle
    let categories: [String]
    let benefits: [TourismBenefit]
    let steps: [TourismStep]
    let routeQuery: String
    let routeSummary: String

    func categoryTitle(_ category: String) -> String {
        switch category {
        case "Food": return "맛집"
        case "Stay": return "숙소"
        case "Experience": return "체험"
        case "Transport": return "교통"
        default: return category
        }
    }

    static func make(for title: String) -> TourismServiceProfile {
        if title.contains("반값") {
            return TourismServiceProfile(
                title: title,
                badge: "교통·숙박 지원",
                headline: "반값 혜택으로\n가볍게 떠나는 여행",
                summary: "교통, 숙박, 체험 할인 혜택을 한 번에 확인하고 내 여행 루트에 담아보세요.",
                ctaTitle: "반값 혜택 신청하기",
                issuedTitle: "반값여행 패스 발급 완료",
                heroStyle: .ocean,
                categories: ["Transport", "Stay", "Experience"],
                benefits: [
                    TourismBenefit(
                        id: "half-rail",
                        name: "부산 야경 레일패스",
                        location: "부산 해운대구",
                        category: "Transport",
                        discount: "50% 할인",
                        tags: ["교통", "야경"],
                        imageStyle: .night,
                        spot: MaplogSpot(
                            id: "benefit-half-rail",
                            name: "부산 야경 레일패스",
                            category: "교통",
                            area: "부산 해운대구",
                            summary: "해운대와 광안리 야경 코스를 연결하는 반값 교통 패스 혜택입니다.",
                            rating: 4.8,
                            imageStyle: .night,
                            tags: ["부산", "교통", "반값여행"],
                            pinX: 0.58,
                            pinY: 0.36
                        )
                    ),
                    TourismBenefit(
                        id: "half-stay",
                        name: "강릉 바다 스테이",
                        location: "강원 강릉시",
                        category: "Stay",
                        discount: "30% 쿠폰",
                        tags: ["숙박", "오션뷰"],
                        imageStyle: .ocean,
                        spot: MaplogSpot(
                            id: "benefit-half-stay",
                            name: "강릉 바다 스테이",
                            category: "숙박",
                            area: "강원 강릉시",
                            summary: "바다 산책과 함께 묶기 좋은 숙박 할인 혜택입니다.",
                            rating: 4.6,
                            imageStyle: .ocean,
                            tags: ["강릉", "숙박", "쿠폰"],
                            pinX: 0.48,
                            pinY: 0.46
                        )
                    ),
                    TourismBenefit(
                        id: "half-experience",
                        name: "전주 한옥 공방 체험",
                        location: "전북 전주시",
                        category: "Experience",
                        discount: "1+1",
                        tags: ["체험", "한옥"],
                        imageStyle: .palace,
                        spot: MaplogSpot(
                            id: "benefit-half-experience",
                            name: "전주 한옥 공방 체험",
                            category: "체험",
                            area: "전북 전주시",
                            summary: "한옥마을 산책과 함께 예약하기 좋은 공방 체험 혜택입니다.",
                            rating: 4.7,
                            imageStyle: .palace,
                            tags: ["전주", "체험", "반값여행"],
                            pinX: 0.42,
                            pinY: 0.62
                        )
                    )
                ],
                steps: [
                    TourismStep(title: "여행 지역 선택", subtitle: "관심 지역을 고르면 사용 가능한 혜택이 정렬돼요."),
                    TourismStep(title: "패스 발급", subtitle: "발급 완료 화면에서 사용 가능한 혜택을 확인해요."),
                    TourismStep(title: "지도 루트에 담기", subtitle: "혜택 장소를 저장하고 지도 검색으로 이어집니다.")
                ],
                routeQuery: "부산 야경",
                routeSummary: "교통, 숙박, 체험 혜택을 묶은 추천 루트를 확인합니다."
            )
        }

        return TourismServiceProfile(
            title: title,
            badge: "특별한 혜택",
            headline: "디지털관광주민증으로\n여행을 더 풍성하게",
            summary: "발급받고 다양한 현지 혜택을 누려보세요.",
            ctaTitle: "내 주민증 발급받기",
            issuedTitle: "내 주민증 발급 완료",
            heroStyle: .forest,
            categories: ["Food", "Stay", "Experience"],
            benefits: [
                TourismBenefit(
                    id: "resident-food",
                    name: "제주 바다향기 횟집",
                    location: "서귀포시",
                    category: "Food",
                    discount: "10% 할인",
                    tags: ["해산물", "오션뷰"],
                    imageStyle: .ocean,
                    spot: MaplogSpot(
                        id: "benefit-resident-food",
                        name: "제주 바다향기 횟집",
                        category: "맛집",
                        area: "제주 서귀포시",
                        summary: "디지털관광주민증으로 10% 할인 혜택을 받을 수 있는 바다 근처 맛집입니다.",
                        rating: 4.8,
                        imageStyle: .ocean,
                        tags: ["제주", "맛집", "할인"],
                        pinX: 0.45,
                        pinY: 0.54
                    )
                ),
                TourismBenefit(
                    id: "resident-cafe",
                    name: "감귤 테마 카페 오름",
                    location: "제주시",
                    category: "Food",
                    discount: "무료 음료",
                    tags: ["카페", "디저트"],
                    imageStyle: .cafe,
                    spot: MaplogSpot(
                        id: "benefit-resident-cafe",
                        name: "감귤 테마 카페 오름",
                        category: "카페",
                        area: "제주 제주시",
                        summary: "관광주민증 제시 시 시그니처 음료 혜택을 받을 수 있는 감귤 테마 카페입니다.",
                        rating: 4.9,
                        imageStyle: .cafe,
                        tags: ["제주", "카페", "관광주민증"],
                        pinX: 0.35,
                        pinY: 0.58
                    )
                ),
                TourismBenefit(
                    id: "resident-camping",
                    name: "별빛 글램핑장",
                    location: "애월읍",
                    category: "Stay",
                    discount: "20% 할인",
                    tags: ["숙박", "자연"],
                    imageStyle: .forest,
                    spot: MaplogSpot(
                        id: "benefit-resident-camping",
                        name: "별빛 글램핑장",
                        category: "숙박",
                        area: "제주 애월읍",
                        summary: "야간 별빛 코스와 함께 묶기 좋은 글램핑 혜택 장소입니다.",
                        rating: 4.7,
                        imageStyle: .forest,
                        tags: ["제주", "숙박", "자연"],
                        pinX: 0.50,
                        pinY: 0.40
                    )
                ),
                TourismBenefit(
                    id: "resident-experience",
                    name: "해녀 문화 체험관",
                    location: "구좌읍",
                    category: "Experience",
                    discount: "30% 할인",
                    tags: ["체험", "문화"],
                    imageStyle: .market,
                    spot: MaplogSpot(
                        id: "benefit-resident-experience",
                        name: "해녀 문화 체험관",
                        category: "체험",
                        area: "제주 구좌읍",
                        summary: "지역 문화를 가볍게 체험할 수 있는 관광주민증 혜택 장소입니다.",
                        rating: 4.6,
                        imageStyle: .market,
                        tags: ["제주", "체험", "문화"],
                        pinX: 0.60,
                        pinY: 0.45
                    )
                )
            ],
            steps: [
                TourismStep(title: "주민증 발급", subtitle: "발급 버튼을 누르면 내 관광 패스가 표시됩니다."),
                TourismStep(title: "혜택 장소 저장", subtitle: "할인 배지를 눌러 관심 장소로 담아둘 수 있어요."),
                TourismStep(title: "지도에서 방문 계획", subtitle: "저장한 혜택 장소를 지도 검색 흐름으로 이어갑니다.")
            ],
            routeQuery: "제주 카페",
            routeSummary: "관광주민증 혜택 장소를 중심으로 지도 검색을 시작합니다."
        )
    }
}

private struct ServiceBenefitCard: View {
    let benefit: TourismBenefit
    let isSaved: Bool

    var body: some View {
        HStack(spacing: 14) {
            TravelImageView(style: benefit.imageStyle, height: 86, cornerRadius: 10, showsSymbol: false)
                .frame(width: 86)

            VStack(alignment: .leading, spacing: 7) {
                Text(benefit.name)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .lineLimit(1)
                Label(benefit.location, systemImage: "mappin.and.ellipse")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.maplogMuted)
                HStack(spacing: 6) {
                    ForEach(benefit.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.maplogMuted)
                            .padding(.horizontal, MaplogSpacing.xSmall)
                            .frame(height: 24)
                            .background(Color.maplogCanvas)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }

            Spacer(minLength: 42)
        }
        .padding(MaplogSpacing.small)
        .background(Color.maplogSurface)
        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous)
                .stroke(isSaved ? Color.maplogLime : .clear, lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.04), radius: 18, x: 0, y: 8)
    }
}

private struct ServiceIssueSheet: View {
    let profile: TourismServiceProfile
    @Binding var isIssued: Bool
    let onAction: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(profile.title)
                    .font(MaplogFont.screenTitle)
                    .foregroundStyle(Color.maplogInk)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 14) {
                Text(isIssued ? "발급 완료" : "패스 미리보기")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())
                Text(profile.headline.replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text("MAPLOG PASS · 2026")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.maplogOlive, Color.maplogInk],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button {
                if isIssued {
                    dismiss()
                } else {
                    isIssued = true
                    complete("여행 패스를 발급했어요")
                }
            } label: {
                Label(isIssued ? "패스 확인 완료" : "발급 완료하기", systemImage: isIssued ? "checkmark" : "checkmark.seal.fill")
                    .font(MaplogFont.cardTitle)
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.maplogLime)
                    .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
            }
            .buttonStyle(.plain)

            if isIssued {
                Button {
                    isIssued = false
                    complete("여행 패스를 해제했어요")
                } label: {
                    Text("패스 해제")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.maplogMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.maplogCanvas)
                        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(MaplogSpacing.xLarge)
    }

    private func complete(_ message: String) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onAction(message)
        }
    }
}

private struct ServiceShareSheet: View {
    let profile: TourismServiceProfile
    let isIssued: Bool
    let onAction: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("서비스 공유")
                        .font(MaplogFont.screenTitle)
                        .foregroundStyle(Color.maplogInk)
                    Text(profile.title)
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
                    complete("서비스 링크를 복사했어요")
                }
                shareOption(title: "친구", systemImage: "person.2.fill") {
                    complete("친구에게 서비스를 보냈어요")
                }
                shareOption(title: isIssued ? "패스" : "혜택", systemImage: isIssued ? "checkmark.seal.fill" : "ticket.fill") {
                    complete(isIssued ? "내 패스 카드를 저장했어요" : "혜택 카드를 저장했어요")
                }
            }

            HStack(spacing: MaplogSpacing.small) {
                TravelImageView(style: profile.heroStyle, height: 76, cornerRadius: 14, showsSymbol: false)
                    .frame(width: 92)

                VStack(alignment: .leading, spacing: 6) {
                    Text(isIssued ? profile.issuedTitle : profile.badge)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background(Color.maplogLime)
                        .clipShape(Capsule())
                    Text(profile.headline.replacingOccurrences(of: "\n", with: " "))
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .lineLimit(2)
                    Text("\(profile.benefits.count)개 혜택 · \(profile.routeSummary)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.maplogMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(MaplogSpacing.small)
            .background(Color.maplogCanvas.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(MaplogSpacing.xLarge)
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

struct FeaturedEventDetailView: View {
    let event: FeaturedEvent
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @State private var showActionToast = false
    @State private var toastText = ""
    @State private var showsRouteSuggestion = false
    @State private var showsShareSheet = false

    private var venueName: String {
        event.location == "서울" ? "광화문광장" : "\(event.location) 행사장"
    }

    private var eventVenueSpot: MaplogSpot {
        MaplogSpot(
            id: "event-venue-\(event.id)",
            name: venueName,
            category: "축제",
            area: event.location,
            summary: "\(event.title)의 중심 행사장입니다. 입구와 포토존을 기준으로 루트를 시작하기 좋아요.",
            rating: 4.8,
            imageStyle: event.imageStyle,
            tags: ["행사", "포토존", "추천루트"],
            pinX: 0.48,
            pinY: 0.36
        )
    }

    private var eventNearbySpot: MaplogSpot {
        MaplogSpot(
            id: "event-nearby-\(event.id)",
            name: event.location == "서울" ? "광화문 카페거리" : "\(event.location) 로컬 맛집거리",
            category: "맛집",
            area: event.location,
            summary: "행사 전후로 쉬어가기 좋은 주변 장소입니다. 짧은 산책과 식사를 함께 묶기 좋습니다.",
            rating: 4.6,
            imageStyle: .cafe,
            tags: ["맛집", "휴식", "산책"],
            pinX: 0.62,
            pinY: 0.66
        )
    }

    private var eventRouteTrip: MaplogTrip {
        MaplogTrip(
            id: "event-route-\(event.id)",
            title: "\(event.title) 추천 루트",
            subtitle: "\(venueName)에서 주변 명소까지 이어지는 당일 코스",
            location: event.location,
            duration: "약 1시간",
            coverStyle: event.imageStyle,
            spots: [eventVenueSpot, eventNearbySpot],
            nearbySpots: eventRouteNearbySpots
        )
    }

    private var eventRouteNearbySpots: [MaplogSpot] {
        let isJinju = event.location == "진주"
        let festivalName = isJinju ? "진주성 야외무대" : "\(event.location) 야외무대"
        let diningName = isJinju ? "남강 로컬 다이닝" : "\(event.location) 로컬 다이닝"
        let walkName = isJinju ? "남강 산책길" : "\(event.location) 산책길"

        return [
            MaplogSpot(
                id: "event-nearby-festival-\(event.id)",
                name: festivalName,
                category: "축제",
                area: event.location,
                summary: "행사장과 함께 즐기기 좋은 공연과 체험 공간입니다.",
                rating: 4.7,
                imageStyle: .festival,
                tags: ["공연", "체험"],
                pinX: 0.30,
                pinY: 0.58
            ),
            MaplogSpot(
                id: "event-nearby-dining-\(event.id)",
                name: diningName,
                category: "맛집",
                area: event.location,
                summary: "행사 전후로 식사하기 좋은 가까운 로컬 맛집입니다.",
                rating: 4.6,
                imageStyle: .market,
                tags: ["식사", "로컬"],
                pinX: 0.76,
                pinY: 0.52
            ),
            MaplogSpot(
                id: "event-nearby-walk-\(event.id)",
                name: walkName,
                category: "산책",
                area: event.location,
                summary: "행사 후 잠시 걸으며 쉬어가기 좋은 물가 산책 구간입니다.",
                rating: 4.8,
                imageStyle: .forest,
                tags: ["산책", "휴식"],
                pinX: 0.54,
                pinY: 0.80
            )
        ]
    }

    private var isRouteSaved: Bool {
        sessionStore.hasSavedRoute(eventRouteTrip)
    }

    private var isSaved: Bool {
        sessionStore.hasSavedEvent(event)
    }

    private var eventIntroTitle: String {
        if event.title.contains("정원") {
            return "도심 정원을 걷는 주말 코스"
        }
        if event.title.contains("영화") {
            return "바다와 함께 보는 특별 상영"
        }
        if event.title.contains("단오") {
            return "전통과 공연이 이어지는 축제"
        }
        return "지금 방문하기 좋은 지역 행사"
    }

    private var eventIntroBody: String {
        "\(venueName)을 중심으로 열리는 \(event.title)입니다. 현장 분위기와 주변 장소를 함께 둘러볼 수 있도록 Maplog 추천 루트와 가까운 명소를 함께 구성했습니다."
    }

    private var eventAddress: String {
        event.location == "서울" ? "서울 종로구 세종대로 172" : "\(event.location) 중심가 일대"
    }

    private var heroAssetName: String {
        event.heroAssetName ?? event.thumbnailAssetName ?? event.imageStyle.assetName
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    eventHero
                    introCard
                    if isSaved {
                        NavigationLink {
                            SavedView()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "bookmark.fill")
                                Text("관심 행사에 저장됨")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.maplogOlive)
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(MaplogPressFeedbackStyle())
                        .padding(.horizontal, MaplogSpacing.page)
                    }
                    infoGrid
                    locationCard
                }
                .padding(.bottom, 24)
            }

            if showActionToast {
                Text(toastText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 48)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: MaplogSpacing.small) {
                Button {
                    showsRouteSuggestion = true
                } label: {
                    Label("길찾기", systemImage: "location.north.line.fill")
                        .font(.headline)
                        .foregroundStyle(Color.maplogOlive)
                        .frame(minWidth: 112, minHeight: 54)
                }
                .buttonStyle(MaplogPressFeedbackStyle())

                NavigationLink {
                    RouteDetailView(trip: eventRouteTrip)
                } label: {
                    Label("지도 보기", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.headline)
                        .foregroundStyle(Color.maplogInk)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 54)
                        .background(Color.maplogLime)
                        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous))
                }
                .buttonStyle(MaplogPressFeedbackStyle())
            }
            .padding(.horizontal, MaplogSpacing.page)
            .padding(.vertical, 12)
            .background(.bar)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color(uiColor: .separator).opacity(0.25))
                    .frame(height: 1)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .maplogTabBarHidden()
        .sheet(isPresented: $showsRouteSuggestion) {
            SuggestedRouteSheet(
                trip: eventRouteTrip,
                isAlreadySaved: isRouteSaved,
                onSave: {
                    if sessionStore.saveRoute(eventRouteTrip) {
                        showToast("행사 루트를 보관함에 저장했어요")
                    } else {
                        showToast("이미 저장된 행사 루트입니다")
                    }
                }
            )
            .presentationDetents([.height(330)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsShareSheet) {
            RouteShareSheet(trip: eventRouteTrip) { message in
                showToast(message)
            }
            .presentationDetents([.height(328)])
            .presentationDragIndicator(.visible)
        }
    }

    private var eventHero: some View {
        Image(heroAssetName)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 390)
            .clipped()
            .overlay {
                LinearGradient(
                    colors: [.black.opacity(0.10), .clear, .black.opacity(0.76)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .top) {
                HStack {
                    EventCircleButton(systemImage: "chevron.left") {
                        dismiss()
                    }
                    Spacer()
                    EventCircleButton(systemImage: "square.and.arrow.up") {
                        showsShareSheet = true
                    }
                    EventCircleButton(systemImage: isSaved ? "bookmark.fill" : "bookmark") {
                        toggleEventSaved()
                    }
                }
                .padding(.horizontal, MaplogSpacing.page)
                .padding(.top, 54)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("오늘 진행 중", systemImage: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.maplogLime)
                    Text(event.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(event.period, systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(2)
                }
                .padding(MaplogSpacing.page)
            }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(eventIntroTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            Text(eventIntroBody)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
            Text("#미디어아트  ·  #야간관광  ·  #데이트코스")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.maplogOlive)
        }
        .padding(.horizontal, MaplogSpacing.page)
    }

    private var infoGrid: some View {
        VStack(alignment: .leading, spacing: 18) {
            EventInfoRow(icon: "clock", title: "운영 시간", primary: "18:00 - 22:00", secondary: "매시 정각 10분 쇼 진행")
            EventInfoRow(icon: "mappin", title: "장소", primary: venueName, secondary: "주요 입구 인근 · 주차 혼잡 예상")
        }
        .padding(.horizontal, MaplogSpacing.page)
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("위치 안내")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    showsRouteSuggestion = true
                } label: {
                    Label("길찾기", systemImage: "arrow.triangle.turn.up.right.diamond")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.maplogOlive)
                        .frame(minHeight: 44)
                }
                .buttonStyle(MaplogPressFeedbackStyle())
            }
            MiniMapCard(spots: [MockMaplogData.seoulTower])
            Text(eventAddress)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, MaplogSpacing.page)
    }

    private func showToast(_ text: String) {
        toastText = text
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            showActionToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            withAnimation(.easeOut(duration: 0.2)) {
                if toastText == text {
                    showActionToast = false
                }
            }
        }
    }

    private func toggleEventSaved() {
        if isSaved {
            sessionStore.removeSavedEvent(event)
            showToast("행사 저장을 해제했어요")
        } else {
            sessionStore.saveEvent(event)
            showToast("관심 행사에 저장했어요")
        }
    }
}

private struct EventCircleButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .shadow(color: .black.opacity(0.32), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(MaplogPressFeedbackStyle())
    }
}

private struct EventInfoRow: View {
    let icon: String
    let title: String
    let primary: String
    let secondary: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.maplogOlive)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(primary)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(secondary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FestivalListView: View {
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @State private var selectedFilter = "전체"
    @State private var toastText: String?
    private let filters = ["전체", "진행 중", "이번 주말", "거리순"]

    private var visibleEvents: [FeaturedEvent] {
        switch selectedFilter {
        case "이번 주말":
            return Array(MockMaplogData.events.prefix(2))
        case "거리순":
            return MockMaplogData.events.sorted { $0.location < $1.location }
        default:
            return MockMaplogData.events
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: MaplogSpacing.section) {
                    filterRow

                    festivalListHeader

                    ForEach(visibleEvents) { event in
                        ZStack(alignment: .topTrailing) {
                            NavigationLink {
                                FeaturedEventDetailView(event: event)
                            } label: {
                                FestivalCard(
                                    event: event,
                                    isSaved: sessionStore.hasSavedEvent(event)
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                toggleSave(event)
                            } label: {
                                Image(systemName: sessionStore.hasSavedEvent(event) ? "heart.fill" : "heart")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(sessionStore.hasSavedEvent(event) ? AnyShapeStyle(Color.maplogOlive) : AnyShapeStyle(.primary))
                                    .frame(width: 34, height: 34)
                                    .background(.regularMaterial)
                                    .clipShape(Circle())
                                    .overlay {
                                        Circle()
                                            .stroke(.white.opacity(0.25), lineWidth: 1)
                                    }
                            }
                            .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
                            .buttonStyle(.plain)
                            .padding(MaplogSpacing.small)
                            .accessibilityLabel(sessionStore.hasSavedEvent(event) ? "\(event.title) 관심 행사 저장 해제" : "\(event.title) 관심 행사 저장")
                        }
                    }
                }
                .padding(.horizontal, MaplogSpacing.page)
                .padding(.top, 18)
                .padding(.bottom, 110)
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
                    .padding(.bottom, 26)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("축제")
        .navigationBarTitleDisplayMode(.inline)
        .maplogTabBarHidden()
        .background(Color(uiColor: .systemBackground))
    }

    private var festivalListHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("전국 축제 · 공연")
                    .font(MaplogFont.screenTitle)
                    .foregroundStyle(Color.maplogInk)
                Text("지금 떠나기 좋은 행사를 골라보세요")
                    .font(MaplogFont.callout)
                    .foregroundStyle(Color.maplogMuted)
            }

            Spacer()

            Text("\(visibleEvents.count)개")
                .font(MaplogFont.calloutStrong)
                .foregroundStyle(Color.maplogOlive)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Color.maplogLime.opacity(0.32))
                .clipShape(Capsule())
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(filters, id: \.self) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        HStack(spacing: 4) {
                            Text(filter)
                            if filter == "거리순" {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                            }
                        }
                        .font(MaplogFont.calloutStrong)
                        .foregroundStyle(selectedFilter == filter ? AnyShapeStyle(Color.maplogInk) : AnyShapeStyle(.secondary))
                        .padding(.horizontal, 14)
                        .frame(height: MaplogSize.chipHeight)
                        .background(selectedFilter == filter ? Color.maplogLime : Color(uiColor: .secondarySystemBackground))
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(
                                    selectedFilter == filter ? Color.clear : Color(uiColor: .separator).opacity(0.25),
                                    lineWidth: 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func toggleSave(_ event: FeaturedEvent) {
        if sessionStore.hasSavedEvent(event) {
            sessionStore.removeSavedEvent(event)
            showToast("행사 저장을 해제했어요")
        } else {
            sessionStore.saveEvent(event)
            showToast("관심 행사에 저장했어요")
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
}

private struct FestivalCard: View {
    let event: FeaturedEvent
    let isSaved: Bool

    private var imageName: String {
        event.thumbnailAssetName ?? event.imageStyle.assetName
    }

    private var venueName: String {
        event.location == "서울" ? "광화문광장" : "\(event.location) 행사장"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 276)
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.06), .clear, .black.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

            Text(event.title.contains("서울") ? "D-2" : "진행 중")
                .font(MaplogFont.badge)
                .foregroundStyle(Color.maplogInk)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Color.maplogLime)
                .clipShape(Capsule())
                .padding(MaplogSpacing.medium)

            VStack(alignment: .leading, spacing: 8) {
                Spacer()

                Text(event.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                VStack(alignment: .leading, spacing: 4) {
                    Label(event.period, systemImage: "calendar")
                    Label(venueName, systemImage: "mappin.and.ellipse")
                }
                .font(MaplogFont.caption)
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
            }
            .padding(MaplogSpacing.large)
        }
        .frame(maxWidth: .infinity, minHeight: 276)
        .maplogCard(cornerRadius: MaplogRadius.hero, style: .photo)
        .accessibilityValue(isSaved ? "저장됨" : "저장 안 됨")
    }
}
