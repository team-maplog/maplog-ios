import SwiftUI

private enum BottomSheetState {
    case collapsed
    case medium
    case expanded
}

struct ExploreMapView: View {
    @EnvironmentObject private var sessionStore: MaplogSessionStore
    @StateObject private var viewModel = ExploreMapViewModel()
    @State private var toastText: String?
    @State private var showsLocationPermissionPrompt = false
    @State private var sheetState: BottomSheetState  = .collapsed
    @State private var sheetDragTranslation: CGFloat = 0 // 지금 손가락이 얼마나 드래그 중인지 기억
    
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
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                KakaoMapCanvas()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    mapTopBar
                    mapFilterRow
                    Spacer()
                    
                }
                
                routeSheet
                    .frame(height: interactiveSheetHeight(for: proxy.size.height), alignment: .top)
            }
            .clipped()
            
            mapFloatingControls
            
            if let toastText {
                Text(toastText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .background(.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
                    .padding(.bottom, 396)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
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
        HStack {
            NavigationLink {
                MapSearchView(query: "성수동 카페")
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .bold))
            }
            .buttonStyle(.plain)
            Spacer()
            Text("맵로그")
                .font(.system(size: 22, weight: .bold))
            Spacer()
            HStack(spacing: 18) {
                NavigationLink {
                    RouteLibraryView()
                } label: {
                    Image(systemName: "bookmark")
                        .font(.system(size: 20, weight: .bold))
                }
                .buttonStyle(.plain)
                
                NavigationLink {
                    NotificationsView()
                } label: {
                    Image(systemName: "bell")
                        .font(.system(size: 20, weight: .bold))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(Color.maplogInk)
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .background(.white.opacity(0.94))
    }
    
    private var mapFloatingControls: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 10) {
                    floatingMapButton(systemImage: sessionStore.locationPermissionStatus.isAllowed ? "location.fill" : "location.slash.fill") {
                        guard sessionStore.locationPermissionStatus.isAllowed else {
                            showsLocationPermissionPrompt = true
                            return
                        }
                        
                        viewModel.focusCurrentLocation()
                        showToast("현재 위치 주변 장소를 불러왔어요")
                    }
                    floatingMapButton(systemImage: sessionStore.hasSavedRoute(selectedTrip) ? "bookmark.fill" : "bookmark") {
                        toggleRouteSaved()
                    }
                }
                .padding(.trailing, 18)
                .padding(.bottom, 382)
            }
        }
    }
    
    private func floatingMapButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.maplogInk)
                .frame(width: 48, height: 48)
                .background(.white)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.14), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
    
    private var mapFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.filters, id: \.self) { filter in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                            viewModel.selectFilter(filter)
                        }
                    } label: {
                        ChipView(title: filter, isSelected: viewModel.selectedFilter == filter)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, MaplogSpacing.page)
            .padding(.vertical, 10)
        }
        .background(.white.opacity(0.9))
    }
    
    private var routeSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            sheetHandle
            
            if let selectedSpot = viewModel.selectedSpot {
                routeSummaryHeader(for: selectedSpot)
                routePrimaryActions(for: selectedSpot)
                
                ScrollView(.vertical, showsIndicators: false) {
                    routeSheetDetails(for: selectedSpot)
                }
            } else {
                mapEmptyState
            }
        }
        .padding(.top, 14)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: -8)
    }
    
    private var savedRouteShortcut: some View {
        NavigationLink {
            SavedView()
        } label: {
            HStack(spacing: 10) {
                Label("경로가 보관함에 저장됨", systemImage: "bookmark.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .lineLimit(1)
                
                Spacer(minLength: 8)
                
                Text("확인")
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
        .buttonStyle(.plain)
    }
    
    private var mapEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "map")
                .font(.system(size: 24, weight: .black))
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
        .padding(.vertical, 18)
        .background(Color.maplogCanvas)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    private var sheetHandle: some View {
        Capsule()
            .fill(Color.maplogLine)
            .frame(width: 52, height: 5)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        sheetDragTranslation = value.translation.height
                    }
                    .onEnded{ value in
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            if value.translation.height < -60 { // -40은 위로 드래그
                                sheetState = .expanded
                            } else if value.translation.height > 60 {
                                sheetState = .collapsed
                            }
                            
                            sheetDragTranslation = 0
                        }
                    }
            )
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
    
    private func sheetHeight(for screenHeight: CGFloat) -> CGFloat {
        switch sheetState {
        case .collapsed:
            return min(max(screenHeight * 0.34, 260), 330)
        case .medium:
            return screenHeight * 0.55
        case .expanded:
            return screenHeight * 0.82
        }
    }
    
    
    private func routeSummaryHeader(for selectedSpot: MaplogSpot) -> some View {
        HStack(alignment: .top, spacing: 14) {
            TravelImageView(style: selectedSpot.imageStyle, height: 92)
                .frame(width: 92)
            VStack(alignment: .leading, spacing: 7) {
                Text(selectedSpot.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.maplogInk)
                Label(selectedSpot.area, systemImage: "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.maplogMuted)
                HStack {
                    InfoBadge(title: "게시물 24개", systemImage: "camera")
                    InfoBadge(title: "45분", systemImage: "figure.walk")
                }
            }
            
            Spacer()
            
            Button {
                toggleSpotSaved(selectedSpot)
            } label: {
                Image(systemName: sessionStore.hasSavedSpot(selectedSpot) ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(sessionStore.hasSavedSpot(selectedSpot) ? Color.maplogInk : Color.maplogMuted)
                    .frame(width: 44, height: 44)
                    .background(sessionStore.hasSavedSpot(selectedSpot) ? Color.maplogLime : Color.maplogCanvas)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
    
    
    private func routePrimaryActions(for selectedSpot: MaplogSpot) -> some View {
        HStack(spacing: 10) {
            NavigationLink {
                MapSearchView(query: selectedSpot.name)
            } label: {
                Label("주변 검색", systemImage: "magnifyingglass")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Color.maplogCanvas)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            
            NavigationLink {
                SpotDetailView(spot: selectedSpot)
            } label: {
                Label("장소 상세", systemImage: "mappin.circle.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Color.maplogCanvas)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
    
    
    private func routeSheetDetails(for selectedSpot: MaplogSpot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if sessionStore.hasSavedRoute(selectedTrip) {
                savedRouteShortcut
            }
            Text("경로 주변 명소")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.maplogMuted)
            
            HStack(spacing: 12) {
                ForEach(nearbySpots.prefix(2)) { spot in
                    NavigationLink {
                        SpotDetailView(spot: spot)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            TravelImageView(style: spot.imageStyle, height: 104)
                            Text(spot.name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.maplogInk)
                                .lineLimit(1)
                            Text("\(spot.category) · 1.2KM")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.maplogMuted)
                                .lineLimit(1)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .maplogCard()
                    }
                    .buttonStyle(.plain)
                }
            }
            
            NavigationLink {
                RouteDetailView(trip: selectedTrip)
            } label: {
                Label("이 경로 따라가기", systemImage: "play.circle.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Color.maplogLime)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
        .padding(.bottom, 100)
    }
    
    private func interactiveSheetHeight(for screenHeight: CGFloat) -> CGFloat {
        let baseHeight = sheetHeight(for: screenHeight)
        let draggedHeight = baseHeight - sheetDragTranslation
        
        let minHeight = min(max(screenHeight * 0.34, 260), 330)
        let maxHeight = screenHeight * 0.82
        
        return min(max(draggedHeight, minHeight), maxHeight)
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
                            TravelImageView(style: spot.imageStyle, height: 54, cornerRadius: 27)
                                .frame(width: 54)
                                .overlay(Circle().stroke(selectedSpot?.id == spot.id ? Color.maplogLime : .white, lineWidth: 5))
                            if selectedSpot?.id == spot.id {
                                Text("\(index + 1)")
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundStyle(Color.maplogInk)
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
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white)
                        .clipShape(Capsule())
                    Spacer()
                }
                .padding(12)
            }
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
