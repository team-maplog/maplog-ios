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

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    headerImage

                    VStack(alignment: .leading, spacing: 20) {
                        actionRow
                        if sessionStore.hasVisitChecklistSpot(spot) {
                            visitChecklistConfirmation
                        }
                        detailTabs
                        tabContent
                    }
                    .padding(.horizontal, MaplogSpacing.page)
                    .padding(.top, 42)
                    .padding(.bottom, 116)
                }
            }
            .ignoresSafeArea(edges: .top)

            bottomActionBar

            if let toastMessage {
                Text(toastMessage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 18)
                    .frame(height: 52)
                    .background(.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 8)
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
        .background(Color.white)
    }

    private var headerImage: some View {
        TravelImageView(style: spot.imageStyle, height: 360, cornerRadius: 0)
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
                .padding(.horizontal, 22)
                .padding(.top, 54)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(spot.category) · \(spot.area)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.maplogMuted)
                        .lineLimit(1)
                    HStack(alignment: .firstTextBaseline) {
                        Text(spot.name)
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                        Spacer()
                        Label(String(format: "%.1f", spot.rating), systemImage: "star.fill")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                    }
                    Text(spot.summary)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.maplogMuted)
                        .lineLimit(2)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .offset(y: 24)
            }
    }

    private var actionRow: some View {
        HStack {
            spotActionButton(title: "길찾기", systemImage: "diamond") {
                activeSheet = .route
            }
            spotActionButton(title: "전화", systemImage: "phone") {
                activeSheet = .contact
            }
            spotActionButton(title: "공유", systemImage: "square.and.arrow.up") {
                activeSheet = .share
            }
            spotActionButton(title: isSaved ? "저장됨" : "저장", systemImage: isSaved ? "bookmark.fill" : "bookmark") {
                toggleSaved()
            }
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.maplogLine).frame(height: 1)
        }
    }

    private func spotActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 21, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Color.maplogInk)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
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
        HStack(spacing: 28) {
            ForEach(["홈", "리뷰", "사진", "정보"], id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 8) {
                        Text(tab)
                            .font(.system(size: 16, weight: selectedTab == tab ? .bold : .medium))
                            .foregroundStyle(selectedTab == tab ? Color.maplogInk : Color.maplogMuted)
                        Rectangle()
                            .fill(selectedTab == tab ? Color.maplogLime : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
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
            VStack(alignment: .leading, spacing: 20) {
                spotInfo
                includedMaplogs
            }
        }
    }

    private var spotInfo: some View {
        VStack(spacing: 0) {
            detailRow(icon: "mappin.and.ellipse", title: spot.area, subtitle: "성수역 4번 출구에서 300m")
            detailRow(icon: "clock", title: "영업 중 21:00 종료", subtitle: "오늘 방문하기 좋은 시간대입니다")
            HStack {
                Label("방문자 리뷰 128", systemImage: "square.and.pencil")
                Divider().frame(height: 14)
                Label("블로그 리뷰 342", systemImage: "doc.text")
                Spacer()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.maplogMuted)
            .padding(.vertical, 18)
        }
        .overlay(alignment: .top) { Rectangle().fill(Color.maplogLine).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.maplogLine).frame(height: 1) }
    }

    private var reviewList: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "방문자 리뷰", subtitle: "최근 맵로그에서 남긴 장소 반응")

            VStack(spacing: 12) {
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

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(galleryStyles.enumerated()), id: \.offset) { index, style in
                    TravelImageView(style: style, height: index == 0 ? 216 : 156, cornerRadius: 8, showsSymbol: false)
                        .overlay(alignment: .topTrailing) {
                            if index < 2 {
                                Text(index == 0 ? "대표" : "0:32")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundStyle(index == 0 ? Color.maplogInk : .white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(index == 0 ? Color.maplogLime : .black.opacity(0.48))
                                    .clipShape(Capsule())
                                    .padding(8)
                            }
                        }
                }
            }
        }
    }

    private var businessInfo: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(title: "정보", subtitle: "\(spot.name) 방문 전에 확인할 내용")

            VStack(spacing: 0) {
                detailRow(icon: "location.fill", title: "서울 성동구 연무장길 14", subtitle: "성수역 4번 출구에서 300m")
                detailRow(icon: "clock.fill", title: "영업 중 21:00 종료", subtitle: "브레이크 타임 없이 운영")
                detailRow(icon: "phone.fill", title: "02-123-4567", subtitle: "방문 전 문의 가능한 대표 번호입니다")
                detailRow(icon: "sparkles", title: "예약 · 포장 · 반려동물 동반", subtitle: "방문 전 현장 안내를 확인해 주세요")
            }
            .overlay(alignment: .top) { Rectangle().fill(Color.maplogLine).frame(height: 1) }

            HStack(spacing: 8) {
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
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.maplogMuted)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.maplogInk)
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.maplogMuted)
            }
            Spacer()
        }
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.maplogLine).frame(height: 1) }
    }

    private var includedMaplogs: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("이 장소가 포함된 인기 맵로그")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                Spacer()
                Text("더보기")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.maplogMuted)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(relatedMaplogPosts) { post in
                        NavigationLink {
                            PopularMaplogDetailView(post: post, trip: MockMaplogData.routeTrip(for: post))
                        } label: {
                            VStack(alignment: .leading, spacing: 9) {
                                TravelImageView(style: post.imageStyle, height: 190)
                                    .frame(width: 138)
                                    .overlay(alignment: .topTrailing) {
                                        Text(post.id == "post-1" ? "0:15" : "0:32")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.black.opacity(0.45))
                                            .clipShape(Capsule())
                                            .padding(8)
                                    }
                                Text(post.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.maplogInk)
                                    .lineLimit(2)
                                    .frame(width: 138, alignment: .leading)
                                Text(post.author)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.maplogMuted)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if relatedMaplogPosts.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: "video.slash.fill")
                                .font(.system(size: 22, weight: .black))
                                .foregroundStyle(Color.maplogMuted)
                            Text("연결된 맵로그가 아직 없어요")
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(Color.maplogInk)
                            Text("주변 루트를 저장하거나 새 로그를 촬영해보세요.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.maplogMuted)
                                .lineLimit(2)
                        }
                        .frame(width: 220, alignment: .leading)
                        .padding(16)
                        .background(Color.maplogCanvas)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            Button {
                activeSheet = .route
            } label: {
                Label("길찾기", systemImage: "diamond")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.maplogMuted)
                    .frame(width: 84, height: 56)
            }
            .buttonStyle(.plain)

            Button {
                toggleRoute()
            } label: {
                Text(isInRoute ? "루트에 추가됨" : "내 루트에 추가")
                    .font(.system(size: 18, weight: .black))
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

    private func toggleSaved() {
        if isSaved {
            sessionStore.removeSavedSpot(spot)
            showToast("장소 저장을 해제했어요")
        } else {
            sessionStore.saveSpot(spot)
            showToast("저장한 장소에 추가했어요")
        }
    }

    private func toggleRoute() {
        if isInRoute {
            sessionStore.removeSavedRoute(suggestedTrip)
            showToast("루트 추가를 해제했어요")
        } else {
            sessionStore.saveRoute(suggestedTrip)
            showToast("내 루트에 추가했어요")
        }
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
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
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
                contactInfoRow(icon: "mappin.and.ellipse", title: spot.area, subtitle: "성수역 4번 출구에서 300m")
            }
            .background(Color.maplogCanvas)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

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
        .padding(24)
    }

    private func sheetHeader(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 24, weight: .black))
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
        HStack(spacing: 12) {
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
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("공유")
                        .font(.system(size: 24, weight: .black))
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
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(24)
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
                    .font(.system(size: 20, weight: .black))
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
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.38))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct SpotReviewCard: View {
    let name: String
    let meta: String
    let rating: Int
    let text: String
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
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

            HStack(spacing: 8) {
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
        .padding(16)
        .maplogCard()
    }
}
