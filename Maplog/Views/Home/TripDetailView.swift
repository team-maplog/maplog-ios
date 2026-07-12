import SwiftUI

struct TripDetailView: View {
    let trip: MaplogTrip
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @State private var showsShareSheet = false
    @State private var toastText: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    routeTopBar
                    RouteDetailHeroMap(spots: trip.spots, nearbySpots: trip.nearbySpots)

                    VStack(alignment: .leading, spacing: 22) {
                        routeSummary
                        routeClipSection
                        addRecordCard
                    }
                    .padding(.horizontal, MaplogSpacing.page)
                    .padding(.top, 22)
                    .padding(.bottom, 122)
                    .background(Color.maplogSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .offset(y: -28)
                }
            }

            bottomActionBar

            if let toastText {
                Text(toastText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .background(Color.maplogSurface)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
                    .padding(.bottom, 94)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .background(Color.maplogSurface)
        .maplogTabBarHidden()
        .sheet(isPresented: $showsShareSheet) {
            RouteShareSheet(trip: trip) { message in
                showToast(message)
            }
            .presentationDetents([.height(328)])
            .presentationDragIndicator(.visible)
        }
    }

    private var routeTopBar: some View {
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

            Text("루트 상세")
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(Color.maplogInk)

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
        .padding(.horizontal, MaplogSpacing.medium)
        .frame(height: 58)
        .background(Color.maplogSurface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.maplogLine).frame(height: 1)
        }
    }

    private var routeSummary: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.medium) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                    Text(trip.title)
                        .font(.system(size: 25, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                    Text(trip.subtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.maplogMuted)
                        .lineSpacing(4)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                TravelImageView(style: trip.coverStyle, height: 38, cornerRadius: 19, showsSymbol: false)
                    .frame(width: 38)
                Text("@jiwon.log")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                Spacer()
                InfoBadge(title: "\(trip.duration) · \(estimatedDistance)", systemImage: "figure.walk")
            }

            HStack(spacing: 10) {
                InfoBadge(title: trip.location, systemImage: "mappin.and.ellipse")
                InfoBadge(title: "\(trip.spots.count)개 장소", systemImage: "number.circle.fill")
                InfoBadge(title: "\(trip.spots.count * 15)초 클립", systemImage: "play.rectangle.fill")
            }
        }
    }

    private var routeClipSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "루트 클립", subtitle: "순서대로 따라가며 장소 정보를 확인하세요")

            VStack(spacing: 0) {
                ForEach(Array(trip.spots.enumerated()), id: \.element.id) { index, spot in
                    NavigationLink {
                        SpotDetailView(spot: spot)
                    } label: {
                        RouteTimelineRow(
                            index: index,
                            spot: spot,
                            isLast: index == trip.spots.count - 1
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var addRecordCard: some View {
        NavigationLink {
            ComposerView(initialSpot: trip.spots.first)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 52, height: 52)
                    .background(Color.maplogLime)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("이 루트에 기록 추가")
                        .font(MaplogFont.cardTitle)
                        .foregroundStyle(Color.maplogInk)
                    Text("첫 장소를 기준으로 새 맵로그를 작성합니다")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.maplogMuted)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.maplogMuted)
            }
            .padding(MaplogSpacing.medium)
            .maplogCard()
        }
        .buttonStyle(.plain)
    }

    private var bottomActionBar: some View {
        HStack(spacing: 10) {
            Button {
                toggleRouteSaved()
            } label: {
                Label(sessionStore.hasSavedRoute(trip) ? "저장됨" : "루트 저장", systemImage: sessionStore.hasSavedRoute(trip) ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 126, height: 56)
                    .background(Color.maplogCanvas)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            NavigationLink {
                MapSearchView(query: trip.title)
            } label: {
                Label("지도에서 따라가기", systemImage: "location.north.fill")
                    .font(MaplogFont.cardTitle)
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
        .background(Color.maplogSurface)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.maplogLine).frame(height: 1)
        }
    }

    private var estimatedDistance: String {
        trip.spots.count <= 2 ? "2.1km" : "3.4km"
    }

    private func toggleRouteSaved() {
        if sessionStore.hasSavedRoute(trip) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                _ = sessionStore.removeSavedRoute(trip)
            }
            showToast("루트 저장을 해제했어요")
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                _ = sessionStore.saveRoute(trip)
            }
            showToast("루트를 보관함에 저장했어요")
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

struct RouteDetailHeroMap: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let spots: [MaplogSpot]
    var nearbySpots: [MaplogSpot] = []
    var height: CGFloat = 430
    var selectedSpotID: String? = nil

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 0.90, green: 0.94, blue: 0.90)

                ForEach(0..<8, id: \.self) { index in
                    routeMapBlock(index: index, size: proxy.size)
                }

                gridLines(in: proxy.size)
                    .stroke(.white.opacity(0.72), lineWidth: 2)

                routePath(in: proxy.size)
                    .stroke(Color.maplogLime, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    .shadow(color: Color.maplogLime.opacity(0.45), radius: 8, x: 0, y: 0)

                ForEach(nearbySpots) { spot in
                    RouteNearbyMapPin(spot: spot)
                        .position(nearbyPoint(for: spot, in: proxy.size))
                        .zIndex(0)
                }

                ForEach(Array(spots.enumerated()), id: \.element.id) { index, spot in
                    let point = routePoint(for: spot, in: proxy.size)
                    let hasSelection = selectedSpotID != nil
                    let isSelected = selectedSpotID == spot.id
                    let pinSize: CGFloat = hasSelection ? (isSelected ? 68 : 50) : 58

                    ZStack(alignment: .topTrailing) {
                        MaplogSpotImageView(
                            spot: spot,
                            height: pinSize,
                            cornerRadius: pinSize / 2
                        )
                        .frame(width: pinSize)
                            .overlay(
                                Circle().stroke(
                                    isSelected ? Color.maplogLime : .white,
                                    lineWidth: isSelected ? 5 : 4
                                )
                            )
                            .shadow(
                                color: .black.opacity(isSelected ? 0.26 : 0.14),
                                radius: isSelected ? 16 : 9,
                                x: 0,
                                y: isSelected ? 8 : 4
                            )
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Color.maplogInk)
                            .frame(width: 26, height: 26)
                            .background(isSelected || !hasSelection ? Color.maplogLime : Color.white.opacity(0.92))
                            .clipShape(Circle())
                            .offset(x: 9, y: -9)
                    }
                    .opacity(hasSelection && !isSelected ? 0.66 : 1)
                    .zIndex(isSelected ? 2 : 1)
                    .position(point)
                }
            }
            .scaleEffect(selectedSpotID == nil ? 1 : 1.06)
            .offset(focusOffset(in: proxy.size))
            .animation(
                reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88),
                value: selectedSpotID
            )
        }
        .frame(height: height)
        .clipped()
    }

    private func routePoint(for spot: MaplogSpot, in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width * min(max(spot.pinX, 0.16), 0.84),
            y: size.height * min(max(spot.pinY, 0.18), 0.78)
        )
    }

    private func nearbyPoint(for spot: MaplogSpot, in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width * min(max(spot.pinX, 0.10), 0.90),
            y: size.height * min(max(spot.pinY, 0.14), 0.88)
        )
    }

    private func focusOffset(in size: CGSize) -> CGSize {
        guard
            let selectedSpotID,
            let selectedSpot = spots.first(where: { $0.id == selectedSpotID })
        else {
            return .zero
        }

        let point = routePoint(for: selectedSpot, in: size)
        let target = CGPoint(x: size.width * 0.50, y: size.height * 0.43)

        return CGSize(
            width: (target.x - point.x) * 0.72,
            height: (target.y - point.y) * 0.58
        )
    }

    private func routePath(in size: CGSize) -> Path {
        Path { path in
            guard let first = spots.first else { return }
            path.move(to: routePoint(for: first, in: size))
            for spot in spots.dropFirst() {
                path.addLine(to: routePoint(for: spot, in: size))
            }
        }
    }

    private func gridLines(in size: CGSize) -> Path {
        Path { path in
            for index in 0...5 {
                let x = size.width * CGFloat(index) / 5
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + size.width * 0.12, y: size.height))
            }
            for index in 0...7 {
                let y = size.height * CGFloat(index) / 7
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y - size.height * 0.18))
            }
        }
    }

    private func routeMapBlock(index: Int, size: CGSize) -> some View {
        let columns: [CGFloat] = [0.10, 0.36, 0.63, 0.82, 0.18, 0.52, 0.74, 0.30]
        let rows: [CGFloat] = [0.12, 0.20, 0.18, 0.35, 0.54, 0.60, 0.74, 0.80]
        let widths: [CGFloat] = [0.30, 0.20, 0.25, 0.22, 0.26, 0.18, 0.26, 0.20]
        let heights: [CGFloat] = [0.16, 0.22, 0.14, 0.18, 0.17, 0.24, 0.14, 0.18]

        return RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(index.isMultiple(of: 3) ? Color.maplogLime.opacity(0.32) : .white.opacity(0.78))
            .frame(width: size.width * widths[index], height: size.height * heights[index])
            .rotationEffect(.degrees(index.isMultiple(of: 2) ? -18 : -12))
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 8)
            .position(x: size.width * columns[index], y: size.height * rows[index])
    }
}

private struct RouteNearbyMapPin: View {
    let spot: MaplogSpot

    private var tint: Color {
        switch spot.mapPinStyle {
        case .recorded: return Color.maplogInk
        case .cafe: return Color(red: 0.45, green: 0.28, blue: 0.16)
        case .restaurant: return Color(red: 0.90, green: 0.30, blue: 0.20)
        case .event: return Color(red: 0.40, green: 0.28, blue: 0.76)
        case .festival: return Color.maplogLime
        }
    }

    private var symbol: String {
        switch spot.mapPinStyle {
        case .recorded: return "play.fill"
        case .cafe: return "cup.and.saucer.fill"
        case .restaurant: return "fork.knife"
        case .event: return "calendar"
        case .festival: return "party.popper.fill"
        }
    }

    private var foreground: Color {
        spot.mapPinStyle == .festival ? Color.maplogInk : .white
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            MapPinPointer()
                .fill(tint)
                .frame(width: 14, height: 10)
                .offset(y: -1)

            pinFace
                .offset(y: -6)
        }
        .frame(width: 38, height: 42)
        .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("주변 \(spot.category) \(spot.name)")
    }

    private var pinFace: some View {
        Circle()
            .fill(tint)
            .frame(width: 30, height: 30)
            .overlay(pinSymbol)
            .overlay(Circle().stroke(.white.opacity(0.92), lineWidth: 2))
    }

    private var pinSymbol: some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(foreground)
    }
}

private struct MapPinPointer: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

struct RouteShareSheet: View {
    let trip: MaplogTrip
    let onAction: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.large) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("루트 공유")
                        .font(MaplogFont.screenTitle)
                        .foregroundStyle(Color.maplogInk)
                    Text(trip.title)
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
                routeShareOption(title: "링크", systemImage: "link") {
                    complete("루트 링크를 복사했어요")
                }
                routeShareOption(title: "친구", systemImage: "person.2.fill") {
                    complete("친구에게 루트를 보냈어요")
                }
                routeShareOption(title: "카드", systemImage: "square.and.arrow.down") {
                    complete("루트 카드를 저장했어요")
                }
            }

            HStack(spacing: 10) {
                Button {
                    complete("내 지도에 루트를 고정했어요")
                } label: {
                    Label("내 지도에 고정", systemImage: "pin.fill")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.maplogLime)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    complete("일정 초안에 루트를 담았어요")
                } label: {
                    Label("일정 담기", systemImage: "calendar.badge.plus")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.maplogCanvas)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(MaplogSpacing.xLarge)
    }

    private func routeShareOption(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
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

    private func complete(_ message: String) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onAction(message)
        }
    }
}

struct RouteTimelineRow: View {
    let index: Int
    let spot: MaplogSpot
    let isLast: Bool
    var isActive = false

    var body: some View {
        HStack(alignment: .top, spacing: MaplogSpacing.small) {
            VStack(spacing: MaplogSpacing.xSmall) {
                Text(timeText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isHighlighted ? Color.maplogInk : Color.maplogMuted)

                Circle()
                    .fill(isHighlighted ? Color.maplogLime : Color.white)
                    .overlay(Circle().stroke(isHighlighted ? Color.maplogLime : Color.maplogMuted.opacity(0.5), lineWidth: 2))
                    .frame(width: 13, height: 13)

                if !isLast {
                    Rectangle()
                        .fill(Color.maplogLine)
                        .frame(width: 2, height: 74)
                }
            }
            .frame(width: 50)

            HStack(spacing: MaplogSpacing.small) {
                TravelImageView(style: spot.imageStyle, height: 74, cornerRadius: MaplogRadius.small, showsSymbol: false)
                    .frame(width: 92)

                VStack(alignment: .leading, spacing: 6) {
                    Text(spot.name)
                        .font(MaplogFont.cardTitle)
                        .foregroundStyle(Color.maplogInk)
                        .lineLimit(1)
                    Text(spot.summary)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.maplogMuted)
                        .lineLimit(2)
                    Text(spot.category)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.maplogOlive)
                }

                Spacer()
            }
            .padding(MaplogSpacing.small)
            .background(Color.maplogSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isActive ? Color.maplogLime : Color.maplogLine, lineWidth: isActive ? 2 : 1)
            }
            .shadow(color: (isActive ? Color.maplogLime : .black).opacity(isActive ? 0.16 : 0.04), radius: isActive ? 16 : 12, x: 0, y: 6)
            .padding(.bottom, isLast ? 0 : 14)
        }
    }

    private var isHighlighted: Bool {
        index == 0 || isActive
    }

    private var timeText: String {
        let seconds = index * 15
        return "0:\(String(format: "%02d", seconds))"
    }
}

struct InfoBadge: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.maplogInk)
            .padding(.horizontal, MaplogSpacing.small)
            .padding(.vertical, 9)
            .background(Color.maplogCanvas)
            .clipShape(Capsule())
    }
}
