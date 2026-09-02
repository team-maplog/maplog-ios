import SwiftUI

private enum MapSheetDetent {
    case compact
    case expanded
}

struct ExploreMapView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @StateObject private var viewModel = ExploreMapViewModel()
    @State private var toastText: String?
    @State private var showsLocationPermissionPrompt = false
    @State private var sheetDetent: MapSheetDetent = .compact
    @State private var sheetDragTranslation: CGFloat = 0
    
    private var selectedTrip: MaplogTrip {
        guard let selectedSpot = viewModel.selectedSpot else {
            return MockMaplogData.trips[0]
        }
        return MockMaplogData.routeTrip(for: selectedSpot)
    }
    
    private var nearbySpots: [MaplogSpot] {
        let currentID = viewModel.selectedSpot?.id
        let filtered = viewModel.visibleSpots.filter { $0.id != currentID }
        if filtered.count >= 2 {
            return filtered
        }
        return MockMaplogData.spots.filter { $0.id != currentID }
    }

    private var visibleNearbyMapSpots: [MaplogSpot] {
        let anchor = viewModel.selectedSpot ?? MockMaplogData.forestCafe
        let nearbySpots = MockMaplogData.nearbyRecommendations(around: anchor)

        guard viewModel.selectedFilter != "전체" else {
            return nearbySpots
        }

        return nearbySpots.filter { spot in
            spot.category == viewModel.selectedFilter || spot.tags.contains(viewModel.selectedFilter)
        }
    }

    private var mapMarkerSpots: [MaplogSpot] {
        let recordedSpots = viewModel.visibleSpots
        let nearbySpots = visibleNearbyMapSpots

        guard let selectedSpot = viewModel.selectedSpot else {
            return uniqueSpots(Array(recordedSpots.prefix(5)) + Array(nearbySpots.prefix(4)))
        }

        let recordedCandidates = recordedSpots
            .filter { $0.id != selectedSpot.id }
            .prefix(4)
        let nearbyCandidates = nearbySpots
            .filter { $0.id != selectedSpot.id }
            .prefix(4)

        return uniqueSpots([selectedSpot] + Array(recordedCandidates) + Array(nearbyCandidates))
    }

    private func uniqueSpots(_ spots: [MaplogSpot]) -> [MaplogSpot] {
        var seenIDs = Set<String>()
        return spots.filter { seenIDs.insert($0.id).inserted }
    }

    var body: some View {
        GeometryReader { proxy in
            let currentSheetHeight = interactiveRouteSheetHeight(for: proxy.size.height)

            ZStack(alignment: .bottom) {
//                KakaoMapCanvas()
                PracticeKakaoMapView()
                    .ignoresSafeArea()

                ExploreMapSpotLayer(
                    spots: mapMarkerSpots,
                    selectedSpot: $viewModel.selectedSpot,
                    bottomInset: currentSheetHeight
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    mapTopBar
                    mapFilterRow
                    Spacer()
                    
                }
                
                routeSheet(for: proxy.size.height)
                    .frame(height: currentSheetHeight, alignment: .top)
            }
            .clipped()
            
            mapFloatingControls
                .padding(.bottom, currentSheetHeight + 14)
            
            if let toastText {
                Text(toastText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 48)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, currentSheetHeight + 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        // 지도는 전역 탐색 화면이므로 장소 카드 상태와 관계없이 탭바를 유지한다.
        .maplogTabBarHidden(false)
        .sheet(isPresented: $showsLocationPermissionPrompt) {
            LocationPermissionPromptSheet(
                onAllow: {
                    sessionStore.allowLocationPermission()
                    viewModel.focusCurrentLocation()
                    showToast("현재 위치 주변 장소를 불러왔어요")
                },
                onSkip: {
                    sessionStore.skipLocationPermission()
                    showToast("위치 권한 없이 추천 장소를 둘러볼게요")
                }
            )
            .presentationDetents([.height(384)])
            .presentationDragIndicator(.hidden)
        }
    }
    
    private var mapTopBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("여행 지도")
                    .font(.headline)
                Text("내 경로와 주변 장소")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            NavigationLink {
                MapSearchView(query: "성수동 카페")
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(MaplogPressFeedbackStyle())
            .accessibilityLabel("지도 검색")

            NavigationLink {
                RouteLibraryView()
            } label: {
                Image(systemName: "rectangle.stack.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(MaplogPressFeedbackStyle())
            .accessibilityLabel("저장한 경로")
        }
        .foregroundStyle(Color.maplogInk)
        .padding(MaplogSpacing.small)
        .background(.regularMaterial)
        .padding(.horizontal, MaplogSpacing.page)
        .padding(.top, 12)
    }
    
    private var mapFloatingControls: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack {
                    floatingMapButton(systemImage: sessionStore.locationPermissionStatus.isAllowed ? "location.fill" : "location.slash.fill") {
                        guard sessionStore.locationPermissionStatus.isAllowed else {
                            showsLocationPermissionPrompt = true
                            return
                        }
                        
                        viewModel.focusCurrentLocation()
                        showToast("현재 위치 주변 장소를 불러왔어요")
                    }
                }
                .padding(.trailing, 18)
            }
        }
    }
    
    private func floatingMapButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.maplogInk)
                .frame(width: 48, height: 48)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous))
        }
        .buttonStyle(MaplogPressFeedbackStyle())
    }
    
    private var mapFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.filters, id: \.self) { filter in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                            viewModel.selectFilter(filter)
                            if viewModel.selectedSpot == nil {
                                viewModel.selectedSpot = visibleNearbyMapSpots.first
                            }
                        }
                    } label: {
                        mapFilterChip(
                            title: filter,
                            isSelected: viewModel.selectedFilter == filter
                        )
                    }
                    .buttonStyle(MaplogPressFeedbackStyle())
                }
            }
            .padding(.vertical, 8)
        }
        .contentMargins(.horizontal, MaplogSpacing.page, for: .scrollContent)
    }

    private func mapFilterChip(title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(MaplogFont.calloutStrong)
            .foregroundStyle(isSelected ? Color.white : Color.maplogMuted)
            .padding(.horizontal, MaplogSpacing.medium)
            .frame(height: MaplogSize.chipHeight)
            .background(
                isSelected ? Color.maplogPrimary : .clear,
                in: Capsule()
            )
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    private func routeSheet(for screenHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            systemSheetDragIndicator(for: screenHeight)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: MaplogSpacing.large) {
                    if let selectedSpot = viewModel.selectedSpot {
                        routeSummaryHeader(for: selectedSpot)
                        routePrimaryActions(for: selectedSpot)

                        routeSheetDetails(for: selectedSpot)
                    } else {
                        mapEmptyState
                    }
                }
                .padding(.top, MaplogSpacing.xxxSmall)
                .padding(.horizontal, MaplogSpacing.page)
                .padding(.bottom, MaplogSpacing.large)
            }
            .scrollIndicators(.visible)
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 20, x: 0, y: -6)
    }

    private func systemSheetDragIndicator(for screenHeight: CGFloat) -> some View {
        Capsule()
            .fill(Color.secondary.opacity(0.32))
            .frame(width: 32, height: 4)
            .frame(maxWidth: .infinity)
            .frame(height: 20)
            .contentShape(Rectangle())
            .highPriorityGesture(routeSheetDragGesture(for: screenHeight))
            .accessibilityElement()
            .accessibilityLabel("장소 카드 높이 조절")
            .accessibilityHint("위로 끌어 상세 정보를 펼치고 아래로 끌어 접습니다")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    setRouteSheetDetent(.expanded)
                case .decrement:
                    setRouteSheetDetent(.compact)
                @unknown default:
                    break
                }
            }
    }

    private func compactRouteSheetHeight(for screenHeight: CGFloat) -> CGFloat {
        min(max(screenHeight * 0.36, 280), 304)
    }

    private func expandedRouteSheetHeight(for screenHeight: CGFloat) -> CGFloat {
        let compactHeight = compactRouteSheetHeight(for: screenHeight)
        let candidate = max(screenHeight * 0.66, compactHeight + 160)
        let maximum = max(compactHeight + 80, screenHeight * 0.78)
        return min(candidate, maximum)
    }

    private func baseRouteSheetHeight(for screenHeight: CGFloat) -> CGFloat {
        switch sheetDetent {
        case .compact:
            return compactRouteSheetHeight(for: screenHeight)
        case .expanded:
            return expandedRouteSheetHeight(for: screenHeight)
        }
    }

    private func interactiveRouteSheetHeight(for screenHeight: CGFloat) -> CGFloat {
        let compactHeight = compactRouteSheetHeight(for: screenHeight)
        let expandedHeight = expandedRouteSheetHeight(for: screenHeight)
        let draggedHeight = baseRouteSheetHeight(for: screenHeight) - sheetDragTranslation
        return min(max(draggedHeight, compactHeight), expandedHeight)
    }

    private func routeSheetDragGesture(for screenHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                sheetDragTranslation = value.translation.height
            }
            .onEnded { value in
                let compactHeight = compactRouteSheetHeight(for: screenHeight)
                let expandedHeight = expandedRouteSheetHeight(for: screenHeight)
                let projectedHeight = min(
                    max(
                        baseRouteSheetHeight(for: screenHeight) - value.predictedEndTranslation.height,
                        compactHeight
                    ),
                    expandedHeight
                )
                let midpoint = (compactHeight + expandedHeight) / 2
                setRouteSheetDetent(projectedHeight >= midpoint ? .expanded : .compact)
            }
    }

    private func setRouteSheetDetent(_ detent: MapSheetDetent) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.32, dampingFraction: 0.82)) {
            sheetDetent = detent
            sheetDragTranslation = 0
        }
    }

    private var mapEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "map")
                .font(MaplogFont.screenTitle)
                .foregroundStyle(Color.maplogMuted)
            Text("선택할 수 있는 장소가 없어요")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Color.maplogInk)
            Text("필터를 바꾸거나 검색으로 다른 장소를 찾아보세요.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.maplogMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MaplogSpacing.large)
    }

    private func toggleRouteSaved() {
        if sessionStore.hasSavedRoute(selectedTrip) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                _ = sessionStore.removeSavedRoute(selectedTrip)
            }
            showToast("경로 저장을 해제했어요")
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                _ = sessionStore.saveRoute(selectedTrip)
            }
            showToast("현재 경로를 보관함에 저장했어요")
        }
    }

    private func toggleSpotSaved(_ spot: MaplogSpot) {
        if sessionStore.hasSavedSpot(spot) {
            sessionStore.removeSavedSpot(spot)
            showToast("\(spot.name) 저장을 해제했어요")
        } else {
            sessionStore.saveSpot(spot)
            showToast("\(spot.name)을 저장했어요")
        }
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            toastText = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            withAnimation(.easeOut(duration: 0.2)) {
                if toastText == message {
                    toastText = nil
                }
            }
        }
    }

    private func routeSummaryHeader(for selectedSpot: MaplogSpot) -> some View {
        HStack(alignment: .top, spacing: MaplogSpacing.small) {
            MaplogSpotImageView(
                spot: selectedSpot,
                height: 80,
                cornerRadius: 14
            )
            .frame(width: 80)

            VStack(alignment: .leading, spacing: 5) {
                Text(selectedSpot.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.maplogTextPrimary)
                    .lineLimit(2)
                Label(selectedSpot.area, systemImage: "mappin")
                    .font(.subheadline)
                    .foregroundStyle(Color.maplogTextSecondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if selectedSpot.mapPinStyle == .recorded {
                        Label("게시물 24개", systemImage: "camera")
                        metadataSeparator
                        Label("45분", systemImage: "figure.walk")
                    } else {
                        let detail = nearbyPinDetail(for: selectedSpot)
                        Label("주변 추천", systemImage: "location.fill")
                        metadataSeparator
                        Label(detail.title, systemImage: detail.systemImage)
                    }
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.maplogTextSecondary)
            }

            Spacer(minLength: 0)

            Button {
                toggleSpotSaved(selectedSpot)
            } label: {
                Image(systemName: sessionStore.hasSavedSpot(selectedSpot) ? "bookmark.fill" : "bookmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(sessionStore.hasSavedSpot(selectedSpot) ? Color.maplogOlive : Color.maplogTextSecondary)
                    .frame(width: MaplogSize.minimumTapTarget, height: MaplogSize.minimumTapTarget)
            }

            .buttonStyle(MaplogPressFeedbackStyle())
            .accessibilityLabel(sessionStore.hasSavedSpot(selectedSpot) ? "장소 저장 해제" : "장소 저장")
        }
    }

    private var metadataSeparator: some View {
        Text("·")
            .foregroundStyle(Color.maplogSubtle)
    }

    private func nearbyPinDetail(for spot: MaplogSpot) -> (title: String, systemImage: String) {
        switch spot.mapPinStyle {
        case .cafe:
            return ("도보 6분", "figure.walk")
        case .restaurant:
            return ("도보 8분", "figure.walk")
        case .event:
            return ("이번 주말", "calendar")
        case .festival:
            return ("오늘 진행 중", "sparkles")
        case .recorded:
            return ("45분", "figure.walk")
        }
    }
    
    
    private func routePrimaryActions(for selectedSpot: MaplogSpot) -> some View {
        HStack(spacing: 24) {
            NavigationLink {
                MapSearchView(query: selectedSpot.name)
            } label: {
                Label("주변 검색", systemImage: "magnifyingglass")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.maplogTextPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: MaplogSize.minimumTapTarget)
            }
            .buttonStyle(MaplogPressFeedbackStyle())

            NavigationLink {
                SpotDetailView(spot: selectedSpot)
            } label: {
                MaplogLocationLabel(title: "장소 상세", pinSize: 15)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.maplogTextPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: MaplogSize.minimumTapTarget)
            }
            .buttonStyle(MaplogPressFeedbackStyle())
        }
    }
    
    
    private func routeSheetDetails(for selectedSpot: MaplogSpot) -> some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Text("경로 주변 명소")
                .font(.headline)
                .foregroundStyle(Color.maplogTextPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: MaplogSpacing.small) {
                    ForEach(nearbySpots) { spot in
                        NavigationLink {
                            SpotDetailView(spot: spot)
                        } label: {
                            VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                                MaplogSpotImageView(spot: spot, height: 96, cornerRadius: 14)
                                Text(spot.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.maplogTextPrimary)
                                    .lineLimit(1)
                                Text("\(spot.category) · 1.2KM")
                                    .font(.footnote)
                                    .foregroundStyle(Color.maplogTextSecondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 148, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
        }
        .padding(.top, MaplogSpacing.xxxSmall)
        .padding(.bottom, MaplogSpacing.small)
    }
    
}

private struct ExploreMapSpotLayer: View {
    let spots: [MaplogSpot]
    @Binding var selectedSpot: MaplogSpot?
    let bottomInset: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ForEach(spots) { spot in
                let isSelected = selectedSpot?.id == spot.id

                ExploreMapSpotPin(spot: spot, isSelected: isSelected) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selectedSpot = spot
                    }
                }
                .position(point(for: spot, in: proxy.size))
                .zIndex(isSelected ? 2 : 1)
            }
        }
    }

    private func point(for spot: MaplogSpot, in size: CGSize) -> CGPoint {
        let topBound: CGFloat = 166
        let bottomBound = max(topBound + 48, size.height - bottomInset - 30)

        return CGPoint(
            x: size.width * min(max(spot.pinX, 0.10), 0.90),
            y: min(max(size.height * spot.pinY, topBound), bottomBound)
        )
    }
}

private struct ExploreMapSpotPin: View {
    let spot: MaplogSpot
    let isSelected: Bool
    let action: () -> Void

    private var tint: Color {
        switch spot.mapPinStyle {
        case .recorded: return .maplogInk
        case .cafe: return Color(red: 0.45, green: 0.28, blue: 0.16)
        case .restaurant: return Color(red: 0.90, green: 0.30, blue: 0.20)
        case .event: return Color(red: 0.40, green: 0.28, blue: 0.76)
        case .festival: return .maplogLime
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

    private var pinDiameter: CGFloat {
        switch spot.mapPinStyle {
        case .recorded:
            return isSelected ? 48 : 42
        case .cafe, .restaurant, .event, .festival:
            return isSelected ? 38 : 32
        }
    }

    private var selectionRing: Color {
        spot.mapPinStyle == .festival ? Color.maplogInk : Color.maplogLime
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: -7) {
                pinFace

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(tint)
                    .frame(width: isSelected ? 12 : 10, height: isSelected ? 12 : 10)
                    .rotationEffect(.degrees(45))
            }
            .frame(width: MaplogSize.minimumTapTarget, height: pinDiameter + 10, alignment: .top)
            .shadow(
                color: .black.opacity(isSelected ? 0.22 : 0.16),
                radius: isSelected ? 7 : 4,
                x: 0,
                y: isSelected ? 4 : 2
            )
            .shadow(
                color: isSelected ? selectionRing.opacity(0.24) : .clear,
                radius: 8,
                x: 0,
                y: 3
            )
        }
        .buttonStyle(MaplogPressFeedbackStyle(pressedScale: 0.96))
        .accessibilityLabel("\(spot.category) \(spot.name)")
        .accessibilityValue(isSelected ? "선택됨" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var pinFace: some View {
        switch spot.mapPinStyle {
        case .recorded:
            MaplogSpotImageView(
                spot: spot,
                height: pinDiameter,
                cornerRadius: pinDiameter / 2
            )
            .frame(width: pinDiameter)
            .clipShape(Circle())
            .overlay {
                if isSelected {
                    Circle()
                        .stroke(selectionRing, lineWidth: 3)
                        .padding(-4)
                }
            }
        case .cafe, .restaurant, .event, .festival:
            Circle()
                .fill(tint)
                .frame(width: pinDiameter, height: pinDiameter)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: isSelected ? 16 : 13, weight: .bold))
                        .foregroundStyle(spot.mapPinStyle == .festival ? Color.maplogInk : .white)
                }
                .overlay {
                    if isSelected {
                        Circle()
                            .stroke(selectionRing, lineWidth: 3)
                            .padding(-4)
                    }
                }
        }
    }
}



struct MockMapCanvas: View {
    let spots: [MaplogSpot]
    @Binding var selectedSpot: MaplogSpot?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 0.86, green: 0.92, blue: 0.88)

                gridLines(in: proxy.size)
                    .stroke(.white.opacity(0.92), lineWidth: 3)

                Path { path in
                    let width = proxy.size.width
                    let height = proxy.size.height
                    path.move(to: CGPoint(x: width * 0.20, y: height * 0.40))
                    path.addCurve(to: CGPoint(x: width * 0.77, y: height * 0.34), control1: CGPoint(x: width * 0.40, y: height * 0.25), control2: CGPoint(x: width * 0.65, y: height * 0.58))
                    path.addCurve(to: CGPoint(x: width * 0.56, y: height * 0.18), control1: CGPoint(x: width * 0.85, y: height * 0.20), control2: CGPoint(x: width * 0.70, y: height * 0.16))
                }
                .stroke(Color.maplogLime, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [8, 8]))

                ForEach(Array(spots.enumerated()), id: \.element.id) { index, spot in
                    Button {
                        selectedSpot = spot
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            MaplogSpotImageView(spot: spot, height: 54, cornerRadius: 27)
                                .frame(width: 54)
                                .overlay(Circle().stroke(selectedSpot?.id == spot.id ? Color.maplogLime : .white, lineWidth: 5))
                            if selectedSpot?.id == spot.id {
                                Text("\(index + 1)")
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundStyle(Color.maplogOnPrimary)
                                    .frame(width: 23, height: 23)
                                    .background(Color.maplogLime)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .position(x: proxy.size.width * spot.pinX, y: proxy.size.height * spot.pinY)
                }
            }
        }
    }

    private func gridLines(in size: CGSize) -> Path {
        Path { path in
            for index in 0...7 {
                let x = size.width * CGFloat(index) / 7
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for index in 0...10 {
                let y = size.height * CGFloat(index) / 10
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
    }
}

struct MiniMapCard: View {
    let spots: [MaplogSpot]

    var body: some View {
        ZStack {
            MockMapCanvas(spots: spots, selectedSpot: .constant(spots.first))
                .allowsHitTesting(false)
            VStack {
                Spacer()
                HStack {
                    Text("나의 여행 지도")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, MaplogSpacing.small)
                        .padding(.vertical, 8)
                        .background(Color.maplogSurface)
                        .clipShape(Capsule())
                    Spacer()
                }
                .padding(MaplogSpacing.small)
            }
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: MaplogRadius.small, style: .continuous))
    }
}
