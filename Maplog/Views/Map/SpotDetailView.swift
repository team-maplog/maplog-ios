import SwiftUI

private enum SpotDetailSheet: Identifiable {
    case route
    case contact
    case share

    var id: String {
        switch self {
        case .route: return "route"
        case .contact: return "contact"
        case .share: return "share"
        }
    }
}

struct SpotDetailView: View {
    let spot: MaplogSpot
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @State private var selectedTab = "홈"
    @State private var activeSheet: SpotDetailSheet?
    @State private var toastMessage: String?
    @State private var isLoadingDetails = true
    @State private var hasStartedLoadingDetails = false

    private var galleryStyles: [PhotoStyle] {
        [spot.imageStyle, .city, .night, .cafe, .palace, .alley]
    }

    private var suggestedTrip: MaplogTrip {
        MockMaplogData.routeTrip(for: spot)
    }

    private var relatedMaplogPosts: [VlogPost] {
        MockMaplogData.posts.filter { post in
            post.place.id == spot.id || MockMaplogData.routeTrip(for: post).spots.contains { $0.id == spot.id }
        }
    }

    private var isSaved: Bool {
        sessionStore.hasSavedSpot(spot)
    }

    private var isInRoute: Bool {
        sessionStore.hasSavedRoute(suggestedTrip)
    }

    private var locationGuidance: String {
        "지도에서 상세 위치를 확인하세요"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    headerImage

                    spotSummaryCard
                        .padding(.horizontal, MaplogSpacing.page)
                        .padding(.top, -MaplogSpacing.xLarge)

                    VStack(alignment: .leading, spacing: MaplogSpacing.large) {
                        actionRow
                        if sessionStore.hasVisitChecklistSpot(spot) {
                            visitChecklistConfirmation
                        }
                        if isLoadingDetails {
                            loadingDetailContent
                        } else {
                            detailTabs
                            tabContent
                        }
                    }
                    .padding(.horizontal, MaplogSpacing.page)
                    .padding(.top, MaplogSpacing.section)
                    .padding(.bottom, 132)
                }
            }
            .ignoresSafeArea(edges: .top)

            bottomActionBar

            if let toastMessage {
                Text(toastMessage)
                    .font(MaplogFont.calloutStrong)
                    .foregroundStyle(Color.maplogTextPrimary)
                    .padding(.horizontal, MaplogSpacing.medium)
                    .frame(minHeight: MaplogSize.controlHeight)
                    .background(Color.maplogSurface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.maplogBorder.opacity(0.72), lineWidth: 1))
                    .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 6)
                    .padding(.bottom, 110)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .route:
                SuggestedRouteSheet(
                    trip: suggestedTrip,
                    isAlreadySaved: isInRoute,
                    onSave: {
                        if sessionStore.saveRoute(suggestedTrip) {
                            showToast("추천 루트를 내 루트에 추가했어요")
                        } else {
                            showToast("이미 저장된 루트입니다")
                        }
                    }
                )
                    .presentationDetents([.height(330)])
                    .presentationDragIndicator(.visible)
            case .contact:
                SpotContactSheet(
                    spot: spot,
                    isInChecklist: sessionStore.hasVisitChecklistSpot(spot),
                    onToggleChecklist: {
                        toggleVisitChecklist()
                    },
                    onAction: { message in
                        showToast(message)
                    }
                )
                    .presentationDetents([.height(382)])
                    .presentationDragIndicator(.visible)
            case .share:
                SpotShareSheet(spot: spot) { message in
                    showToast(message)
                }
                    .presentationDetents([.height(320)])
                    .presentationDragIndicator(.visible)
            }
        }
        .maplogTabBarHidden()
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .background(Color.maplogCanvas.ignoresSafeArea())
        .task {
            guard !hasStartedLoadingDetails else { return }
            hasStartedLoadingDetails = true

            // Keep the opening state stable while a remote spot payload would resolve.
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.18)) {
                isLoadingDetails = false
            }
        }
    }

    private var headerImage: some View {
        MaplogSpotImageView(spot: spot, height: 326, cornerRadius: 0)
            .overlay {
                LinearGradient(
                    colors: [.black.opacity(0.22), .clear, .black.opacity(0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .overlay(alignment: .top) {
                HStack {
                    CircleOverlayButton(systemImage: "chevron.left") {
                        dismiss()
                    }
                    Spacer()
                    CircleOverlayButton(systemImage: "square.and.arrow.up") {
                        activeSheet = .share
                    }
                    CircleOverlayButton(systemImage: isSaved ? "heart.fill" : "heart") {
                        toggleSaved()
                    }
                }
                .padding(.horizontal, MaplogSpacing.page)
                .padding(.top, 54)
            }
    }

    private var spotSummaryCard: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            HStack(alignment: .firstTextBaseline, spacing: MaplogSpacing.small) {
                Text("\(spot.category) · \(spot.area)")
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogTextSecondary)
                    .lineLimit(1)

                Spacer(minLength: MaplogSpacing.small)

                Label(String(format: "%.1f", spot.rating), systemImage: "star.fill")
                    .font(MaplogFont.calloutStrong)
                    .foregroundStyle(Color.maplogTextPrimary)
                    .accessibilityLabel("평점 \(String(format: "%.1f", spot.rating))점")
            }

            Text(spot.name)
                .font(MaplogFont.largeTitle)
                .foregroundStyle(Color.maplogTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(spot.summary)
                .font(MaplogFont.callout)
                .foregroundStyle(Color.maplogTextSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(MaplogSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .maplogCard(cornerRadius: MaplogRadius.large, style: .elevated)
        .accessibilityElement(children: .combine)
    }

    private var actionRow: some View {
        HStack(spacing: 0) {
            spotActionButton(title: "길찾기", systemImage: "diamond") {
                activeSheet = .route
            }
            Divider().frame(height: MaplogSize.controlHeight)
            spotActionButton(title: "전화", systemImage: "phone") {
                activeSheet = .contact
            }
            Divider().frame(height: MaplogSize.controlHeight)
            spotActionButton(title: "공유", systemImage: "square.and.arrow.up") {
                activeSheet = .share
            }
        }
        .padding(.vertical, MaplogSpacing.xSmall)
        .maplogCard(cornerRadius: MaplogRadius.medium)
    }

    private func spotActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: MaplogSpacing.xxSmall) {
                Image(systemName: systemImage)
                    .font(.system(size: MaplogSize.iconMedium, weight: .semibold))
                Text(title)
                    .font(MaplogFont.caption)
            }
            .foregroundStyle(Color.maplogInk)
            .frame(maxWidth: .infinity)
            .frame(minHeight: MaplogSize.controlHeight)
        }
        .buttonStyle(MaplogPressFeedbackStyle())
        .accessibilityLabel(title)
    }

    private var visitChecklistConfirmation: some View {
        SavedConfirmationCard(
            title: "방문 전 확인에 저장됨",
            subtitle: "보관함에서 전화, 영업시간, 주소를 다시 확인할 수 있어요.",
            buttonTitle: "보관함에서 확인",
            systemImage: "checkmark.circle.fill"
        ) {
            SavedView()
        }
    }

    private var detailTabs: some View {
        HStack(spacing: 0) {
            ForEach(["홈", "리뷰", "사진", "정보"], id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: MaplogSpacing.xxSmall) {
                        Text(tab)
                            .font(MaplogFont.calloutStrong)
                            .foregroundStyle(selectedTab == tab ? Color.maplogInk : Color.maplogMuted)
                        Rectangle()
                            .fill(selectedTab == tab ? Color.maplogLime : .clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: MaplogSize.minimumTapTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MaplogPressFeedbackStyle(pressedScale: 0.98))
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.maplogBorder)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case "리뷰":
            reviewList
        case "사진":
            photoGrid
        case "정보":
            businessInfo
        default:
            VStack(alignment: .leading, spacing: MaplogSpacing.large) {
                spotInfo
                includedMaplogs
            }
        }
    }

    private var loadingDetailContent: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.large) {
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { _ in
                    Text("정보")
                        .font(MaplogFont.calloutStrong)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: MaplogSize.minimumTapTarget)
                }
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.maplogBorder).frame(height: 1)
            }

            VStack(alignment: .leading, spacing: MaplogSpacing.medium) {
                Text("방문 전 확인")
                detailLoadingRow
                detailLoadingRow
                Divider()
                Text("방문자 리뷰 128 · 블로그 리뷰 342")
            }
            .padding(MaplogSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .maplogCard(cornerRadius: MaplogRadius.medium)

            VStack(alignment: .leading, spacing: MaplogSpacing.small) {
                Text("이 장소가 포함된 인기 맵로그")
                RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous)
                    .frame(height: 152)
            }
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("장소 상세 정보를 불러오는 중")
    }

    private var detailLoadingRow: some View {
        HStack(spacing: MaplogSpacing.small) {
            Circle().frame(width: MaplogSize.iconMedium, height: MaplogSize.iconMedium)
            VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                Text("영업 중 21시 종료")
                Text(locationGuidance)
            }
            Spacer()
        }
        .frame(minHeight: 44)
    }

    private var spotInfo: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.medium) {
            Label("방문 전 확인", systemImage: "checklist")
                .font(MaplogFont.calloutStrong)
                .foregroundStyle(Color.maplogTextPrimary)

            detailRow(icon: "mappin.and.ellipse", title: spot.area, subtitle: locationGuidance)
            detailRow(icon: "clock", title: "영업 중 21:00 종료", subtitle: "오늘 방문하기 좋은 시간대입니다")

            HStack {
                Label("방문자 리뷰 128", systemImage: "square.and.pencil")
                Divider().frame(height: MaplogSpacing.medium)
                Label("블로그 리뷰 342", systemImage: "doc.text")
                Spacer()
            }
            .font(MaplogFont.caption)
            .foregroundStyle(Color.maplogMuted)
        }
        .padding(MaplogSpacing.medium)
        .maplogCard(cornerRadius: MaplogRadius.medium)
    }

    private var reviewList: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "방문자 리뷰", subtitle: "최근 맵로그에서 남긴 장소 반응")

            VStack(spacing: MaplogSpacing.small) {
                ForEach(Array(reviewItems.enumerated()), id: \.offset) { _, review in
                    SpotReviewCard(
                        name: review.name,
                        meta: review.meta,
                        rating: review.rating,
                        text: review.text,
                        tags: review.tags
                    )
                }
            }
        }
    }

    private var photoGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "사진", subtitle: "이 장소가 등장한 클립과 방문 사진")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: MaplogSpacing.small) {
                ForEach(Array(galleryStyles.enumerated()), id: \.offset) { index, style in
                    TravelImageView(style: style, height: index == 0 ? 216 : 156, cornerRadius: MaplogRadius.small, showsSymbol: false)
                        .overlay(alignment: .topTrailing) {
                            if index < 2 {
                                Text(index == 0 ? "대표" : "0:32")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundStyle(index == 0 ? Color.maplogInk : .white)
                                    .padding(.horizontal, MaplogSpacing.xSmall)
                                    .padding(.vertical, 5)
                                    .background(index == 0 ? Color.maplogLime : .black.opacity(0.48))
                                    .clipShape(Capsule())
                                    .padding(MaplogSpacing.xSmall)
                            }
                        }
                }
            }
        }
    }

    private var businessInfo: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.medium) {
            SectionHeader(title: "정보", subtitle: "\(spot.name) 방문 전에 확인할 내용")

            VStack(spacing: 0) {
                detailRow(icon: "location.fill", title: spot.area, subtitle: locationGuidance)
                detailRow(icon: "clock.fill", title: "영업 중 21:00 종료", subtitle: "브레이크 타임 없이 운영")
                detailRow(icon: "phone.fill", title: "02-123-4567", subtitle: "방문 전 문의 가능한 대표 번호입니다")
                detailRow(icon: "sparkles", title: "예약 · 포장 · 반려동물 동반", subtitle: "방문 전 현장 안내를 확인해 주세요")
            }
            .padding(.horizontal, MaplogSpacing.medium)
            .background(Color.maplogSurface)
            .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous)
                    .stroke(Color.maplogBorder.opacity(0.82), lineWidth: 1)
            }

            HStack(spacing: MaplogSpacing.xSmall) {
                ForEach(spot.tags, id: \.self) { tag in
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
    }

    private var reviewItems: [(name: String, meta: String, rating: Int, text: String, tags: [String])] {
        [
            ("여행자지민", "오늘 오전 방문", 5, "\(spot.category) 특유의 분위기가 좋고, 주변 동선까지 이어가기 쉬웠어요.", ["분위기", "재방문"]),
            ("seoul.walker", "어제 저장", 5, "사진 찍기 좋은 포인트가 많아서 짧은 클립으로 남기기 좋았습니다.", ["사진", "산책"]),
            ("route.collector", "이번 주 인기", 4, "주말에는 사람이 많지만 근처 명소와 묶으면 만족도가 높아요.", ["루트", "인기"])
        ]
    }

    private func detailRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: MaplogSpacing.small) {
            Image(systemName: icon)
                .font(.system(size: MaplogSize.iconMedium, weight: .semibold))
                .foregroundStyle(Color.maplogMuted)
                .frame(width: MaplogSize.iconLarge, height: MaplogSize.iconLarge)
                .padding(MaplogSpacing.xxSmall)
                .background(Color.maplogCanvas, in: Circle())
            VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                Text(title)
                    .font(MaplogFont.bodyStrong)
                    .foregroundStyle(Color.maplogInk)
                Text(subtitle)
                    .font(MaplogFont.callout)
                    .foregroundStyle(Color.maplogMuted)
            }
            Spacer()
        }
        .padding(.vertical, MaplogSpacing.xSmall)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.maplogLine).frame(height: 1) }
    }

    private var includedMaplogs: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            HStack {
                Text("이 장소가 포함된 인기 맵로그")
                    .font(MaplogFont.sectionTitle)
                    .foregroundStyle(Color.maplogInk)
                Spacer()
                if !relatedMaplogPosts.isEmpty {
                    Text("더보기")
                        .font(MaplogFont.caption)
                        .foregroundStyle(Color.maplogMuted)
                }
            }

            if relatedMaplogPosts.isEmpty {
                SpotDetailEmptyState(
                    title: "연결된 맵로그가 아직 없어요",
                    message: "이 장소를 루트에 담고 첫 번째 기록을 남겨보세요.",
                    actionTitle: isInRoute ? "내 루트에 추가됨" : "내 루트에 추가"
                ) {
                    addRouteToMine()
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: MaplogSpacing.small) {
                        ForEach(relatedMaplogPosts) { post in
                            NavigationLink {
                                PopularMaplogDetailView(post: post, trip: MockMaplogData.routeTrip(for: post))
                            } label: {
                                VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                                    TravelImageView(
                                        style: post.imageStyle,
                                        height: 176,
                                        cornerRadius: MaplogRadius.medium,
                                        showsSymbol: false
                                    )
                                    .frame(width: 164)
                                    .overlay(alignment: .topTrailing) {
                                        Text(post.id == "post-1" ? "0:15" : "0:32")
                                            .font(MaplogFont.badge)
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, MaplogSpacing.xSmall)
                                            .padding(.vertical, MaplogSpacing.xxSmall)
                                            .background(.black.opacity(0.48))
                                            .clipShape(Capsule())
                                            .padding(MaplogSpacing.xSmall)
                                    }
                                    Text(post.title)
                                        .font(MaplogFont.calloutStrong)
                                        .foregroundStyle(Color.maplogInk)
                                        .lineLimit(2)
                                        .frame(width: 164, alignment: .leading)
                                    Text(post.author)
                                        .font(MaplogFont.caption)
                                        .foregroundStyle(Color.maplogMuted)
                                }
                            }
                            .buttonStyle(MaplogPressFeedbackStyle(pressedScale: 0.98))
                        }
                    }
                }
            }
        }
    }

    private var bottomActionBar: some View {
        HStack(spacing: MaplogSpacing.small) {
            Button {
                activeSheet = .route
            } label: {
                Label("길찾기", systemImage: "diamond")
                    .font(MaplogFont.calloutStrong)
            }
            .buttonStyle(MaplogButtonStyle(variant: .secondary, size: .large))
            .accessibilityLabel("길찾기")

            Button {
                addRouteToMine()
            } label: {
                Label(
                    isInRoute ? "내 루트에 추가됨" : "내 루트에 추가",
                    systemImage: isInRoute ? "checkmark" : "plus"
                )
            }
            .buttonStyle(
                MaplogButtonStyle(
                    variant: isInRoute ? .tonal : .primary,
                    size: .large,
                    fullWidth: true
                )
            )
            .accessibilityValue(isInRoute ? "내 루트에 추가됨" : "")
        }
        .padding(.horizontal, MaplogSpacing.page)
        .padding(.top, MaplogSpacing.small)
        .padding(.bottom, MaplogSpacing.large)
        .background(Color.maplogSurface)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.maplogLine).frame(height: 1)
        }
    }

    private func toggleSaved() {
        if isSaved {
            sessionStore.removeSavedSpot(spot)
            showToast("장소 저장을 해제했어요")
        } else {
            sessionStore.saveSpot(spot)
            showToast("저장한 장소에 추가했어요")
        }
    }

    private func addRouteToMine() {
        guard !isInRoute else {
            showToast("이미 내 루트에 추가한 장소예요")
            return
        }

        _ = sessionStore.saveRoute(suggestedTrip)
        showToast("내 루트에 추가했어요")
    }

    private func toggleVisitChecklist() {
        if sessionStore.hasVisitChecklistSpot(spot) {
            sessionStore.removeVisitChecklistSpot(spot)
            showToast("방문 전 확인 목록에서 제거했어요")
        } else {
            sessionStore.addVisitChecklistSpot(spot)
            showToast("방문 전 확인 목록에 저장했어요")
        }
    }

    private func showToast(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.16)) {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }
}

private struct SpotDetailEmptyState: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    private var isCompleted: Bool {
        actionTitle.contains("추가됨")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Image(systemName: "video.slash")
                .font(.system(size: MaplogSize.iconLarge, weight: .semibold))
                .foregroundStyle(Color.maplogTextSecondary)

            Text(title)
                .font(MaplogFont.cardTitle)
                .foregroundStyle(Color.maplogTextPrimary)

            Text(message)
                .font(MaplogFont.callout)
                .foregroundStyle(Color.maplogTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: action) {
                Label(actionTitle, systemImage: isCompleted ? "checkmark" : "plus")
            }
            .buttonStyle(
                MaplogButtonStyle(
                    variant: isCompleted ? .tonal : .secondary,
                    size: .regular,
                    fullWidth: false
                )
            )
            .accessibilityValue(isCompleted ? "내 루트에 추가됨" : "")
        }
        .padding(MaplogSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .maplogCard(cornerRadius: MaplogRadius.medium)
    }
}

private struct SpotContactSheet: View {
    let spot: MaplogSpot
    let isInChecklist: Bool
    let onToggleChecklist: () -> Void
    let onAction: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private var phoneNumber: String { "02-123-4567" }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            sheetHeader(title: "장소 문의", subtitle: spot.name)

            VStack(spacing: 0) {
                contactInfoRow(icon: "phone.fill", title: phoneNumber, subtitle: "대표 번호")
                contactInfoRow(icon: "clock.fill", title: "영업 중 · 21:00 종료", subtitle: "브레이크 타임 없이 운영")
                contactInfoRow(icon: "mappin.and.ellipse", title: spot.area, subtitle: "지도에서 상세 위치를 확인하세요")
            }
            .background(Color.maplogCanvas)
            .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))

            HStack(spacing: 10) {
                SpotSheetActionButton(title: "전화", systemImage: "phone.fill") {
                    complete("\(phoneNumber)로 연결을 시작했어요")
                }
                SpotSheetActionButton(title: "주소 복사", systemImage: "doc.on.doc.fill") {
                    complete("주소를 복사했어요")
                }
                SpotSheetActionButton(title: isInChecklist ? "해제" : "저장", systemImage: isInChecklist ? "checkmark.circle.fill" : "bookmark.fill") {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onToggleChecklist()
                    }
                }
            }
        }
        .padding(MaplogSpacing.xLarge)
    }

    private func sheetHeader(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(MaplogFont.screenTitle)
                    .foregroundStyle(Color.maplogInk)
                Text(subtitle)
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
    }

    private func contactInfoRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: MaplogSpacing.small) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.maplogInk)
                .frame(width: 38, height: 38)
                .background(Color.maplogLime.opacity(0.72))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.maplogMuted)
            }

            Spacer()
        }
        .padding(14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.maplogLine.opacity(0.8))
                .frame(height: 1)
                .padding(.leading, 64)
        }
    }

    private func complete(_ message: String) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onAction(message)
        }
    }
}

struct SpotShareSheet: View {
    let spot: MaplogSpot
    let onAction: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.large) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("공유")
                        .font(MaplogFont.screenTitle)
                        .foregroundStyle(Color.maplogInk)
                    Text(spot.name)
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
                SpotSheetActionButton(title: "링크", systemImage: "link") {
                    complete("장소 링크를 복사했어요")
                }
                SpotSheetActionButton(title: "친구", systemImage: "person.2.fill") {
                    complete("친구에게 장소를 보냈어요")
                }
                SpotSheetActionButton(title: "카드", systemImage: "square.and.arrow.down") {
                    complete("장소 카드를 저장했어요")
                }
            }

            Button {
                complete("내 지도에 장소를 고정했어요")
            } label: {
                Label("내 지도에 고정", systemImage: "pin.fill")
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

    private func complete(_ message: String) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onAction(message)
        }
    }
}

private struct SpotSheetActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(MaplogFont.sectionTitle)
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 54, height: 54)
                    .background(Color.maplogCanvas)
                    .clipShape(Circle())

                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.maplogMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct CircleOverlayButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: MaplogSize.iconMedium, weight: .semibold))
                .foregroundStyle(Color.maplogInk)
                .frame(width: 44, height: 44)
                .background(Color.maplogSurface.opacity(0.9), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.32), lineWidth: 1))
        }
        .buttonStyle(MaplogPressFeedbackStyle(pressedScale: 0.94))
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch systemImage {
        case "chevron.left": return "뒤로 가기"
        case "square.and.arrow.up": return "공유"
        case "heart", "heart.fill": return "장소 저장"
        default: return "장소 동작"
        }
    }
}

private struct SpotReviewCard: View {
    let name: String
    let meta: String
    let rating: Int
    let text: String
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            HStack(alignment: .top, spacing: MaplogSpacing.small) {
                Circle()
                    .fill(Color.maplogCanvas)
                    .frame(width: 42, height: 42)
                    .overlay {
                        Text(String(name.prefix(1)))
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                    Text(meta)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.maplogMuted)
                }

                Spacer()

                Label("\(rating).0", systemImage: "star.fill")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.maplogLime.opacity(0.55))
                    .clipShape(Capsule())
            }

            Text(text)
                .font(.system(size: 15, weight: .medium))
                .lineSpacing(4)
                .foregroundStyle(Color.maplogInk)

            HStack(spacing: MaplogSpacing.xSmall) {
                ForEach(tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.maplogMuted)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.maplogCanvas)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(MaplogSpacing.medium)
        .maplogCard()
    }
}
