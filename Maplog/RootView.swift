import Foundation
import SwiftUI

private enum LaunchPhase {
    case login
    case location
    case app
}

private struct MaplogLogoutActionKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

private struct MaplogTabSelectionActionKey: EnvironmentKey {
    static let defaultValue: (MaplogTab) -> Void = { _ in }
}

extension EnvironmentValues {
    var maplogLogout: () -> Void {
        get { self[MaplogLogoutActionKey.self] }
        set { self[MaplogLogoutActionKey.self] = newValue }
    }

    var maplogSelectTab: (MaplogTab) -> Void {
        get { self[MaplogTabSelectionActionKey.self] }
        set { self[MaplogTabSelectionActionKey.self] = newValue }
    }
}

enum MaplogLaunchRequest {
    static let didChangeNotification = Notification.Name("MaplogLaunchRequestDidChange")

    private static let destinationKey = "maplog.launch.destination"
    private static let capturePlaceNameKey = "maplog.launch.capturePlaceName"

    static func requestTab(_ tab: MaplogTab) {
        UserDefaults.standard.set(tab.rawValue, forKey: destinationKey)
        if tab != .capture {
            UserDefaults.standard.removeObject(forKey: capturePlaceNameKey)
        }
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func requestCapture(placeName: String? = nil) {
        UserDefaults.standard.set(MaplogTab.capture.rawValue, forKey: destinationKey)
        let trimmedPlaceName = placeName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedPlaceName.isEmpty {
            UserDefaults.standard.removeObject(forKey: capturePlaceNameKey)
        } else {
            UserDefaults.standard.set(trimmedPlaceName, forKey: capturePlaceNameKey)
        }
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func consumeRequestedTab() -> MaplogTab? {
        guard let rawValue = UserDefaults.standard.string(forKey: destinationKey) else {
            return nil
        }

        UserDefaults.standard.removeObject(forKey: destinationKey)
        return MaplogTab(rawValue: rawValue)
    }

    static func consumeRequestedCapturePlaceName() -> String? {
        guard let placeName = UserDefaults.standard.string(forKey: capturePlaceNameKey) else {
            return nil
        }

        UserDefaults.standard.removeObject(forKey: capturePlaceNameKey)
        let trimmedPlaceName = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedPlaceName.isEmpty ? nil : trimmedPlaceName
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var sessionStore = MaplogSessionStore()
    @State private var phase: LaunchPhase = .login
    @State private var requestedTab: MaplogTab?
    @State private var requestedCapturePlaceName: String?

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-MaplogSkipOnboarding") {
            _phase = State(initialValue: .app)
        }
        #endif
    }

    var body: some View {
        Group {
            switch phase {
            case .login:
                OnboardingView {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                        phase = .location
                    }
                }
            case .location:
                LocationPermissionView(
                    onAllow: {
                        sessionStore.allowLocationPermission()
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                            phase = .app
                        }
                    },
                    onSkip: {
                        sessionStore.skipLocationPermission()
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                            phase = .app
                        }
                    }
                )
            case .app:
                MainTabView(
                    requestedTab: $requestedTab,
                    requestedCapturePlaceName: $requestedCapturePlaceName
                )
            }
        }
        .tint(.maplogLime)
        .font(MaplogFont.body)
        .environment(\.maplogLogout) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                phase = .login
            }
        }
        .environmentObject(sessionStore)
        .onAppear(perform: consumeLaunchRequest)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            consumeLaunchRequest()
        }
        .onReceive(NotificationCenter.default.publisher(for: MaplogLaunchRequest.didChangeNotification)) { _ in
            consumeLaunchRequest()
        }
    }

    private func consumeLaunchRequest() {
        guard let tab = MaplogLaunchRequest.consumeRequestedTab() else {
            return
        }

        requestedCapturePlaceName = MaplogLaunchRequest.consumeRequestedCapturePlaceName()
        requestedTab = tab
    }
}

enum MaplogTab: String, CaseIterable, Identifiable {
    case home
    case capture
    case map
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "홈"
        case .capture: return "촬영"
        case .map: return "지도"
        case .profile: return "마이"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .capture: return "camera.fill"
        case .map: return "map.fill"
        case .profile: return "person.fill"
        }
    }
}

struct MainTabView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding private var requestedTab: MaplogTab?
    @Binding private var requestedCapturePlaceName: String?

    @State private var selectedTab: MaplogTab
    @State private var previousTab: MaplogTab
    @State private var isTabBarHidden = false
    @State private var prefersReelTabBarStyle = false
    @State private var activeCapturePlaceName: String?

    init(
        requestedTab: Binding<MaplogTab?> = .constant(nil),
        requestedCapturePlaceName: Binding<String?> = .constant(nil)
    ) {
        _requestedTab = requestedTab
        _requestedCapturePlaceName = requestedCapturePlaceName
        _selectedTab = State(initialValue: .home)
        _previousTab = State(initialValue: .home)
    }

    private var tabSelection: Binding<MaplogTab> {
        Binding(
            get: { selectedTab },
            set: { applyRequestedTab($0) }
        )
    }

    private var usesCompactTabBar: Bool {
        selectedTab != .capture
    }

    private var usesReelTabBarStyle: Bool {
        selectedTab == .home && prefersReelTabBarStyle
    }

    private var tabBarMorphAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.4)
    }

    var body: some View {
        Group {
            switch selectedTab {
            case .home:
                NavigationStack { HomeView() }
            case .capture:
                NavigationStack {
                    CaptureView(initialPlaceName: activeCapturePlaceName) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                            selectedTab = previousTab
                        }
                    }
                    .id(activeCapturePlaceName ?? "manual-capture")
                }
            case .map:
                NavigationStack { ExploreMapView() }
            case .profile:
                NavigationStack { ProfileView() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isTabBarHidden && !usesReelTabBarStyle {
                Color.clear
                    .frame(height: usesCompactTabBar ? MaplogSize.tabBarHeight : 0)
            }
        }
        .overlay(alignment: .bottom) {
            if !isTabBarHidden {
                MaplogTabBar(
                    selectedTab: tabSelection,
                    isCompact: usesCompactTabBar,
                    isReelStyle: usesReelTabBarStyle
                )
                .padding(.horizontal, usesCompactTabBar ? (usesReelTabBarStyle ? 54 : 28) : 0)
                .padding(.bottom, usesCompactTabBar ? (usesReelTabBarStyle ? 2 : 6) : 0)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(tabBarMorphAnimation, value: usesReelTabBarStyle)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .preferredColorScheme(.light)
        .onPreferenceChange(MaplogTabBarHiddenPreferenceKey.self) { hidden in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                isTabBarHidden = hidden
            }
        }
        .onPreferenceChange(MaplogTabBarReelStylePreferenceKey.self) { prefersReelStyle in
            withAnimation(tabBarMorphAnimation) {
                prefersReelTabBarStyle = prefersReelStyle
            }
        }
        .onAppear(perform: applyPendingRequestedTab)
        .onChange(of: requestedTab) { _, newTab in
            guard let newTab else { return }

            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                applyRequestedTab(newTab, capturePlaceName: requestedCapturePlaceName)
            }
            requestedTab = nil
            requestedCapturePlaceName = nil
        }
        .environment(\.maplogSelectTab) { tab in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                applyRequestedTab(tab)
            }
        }
    }

    private func applyPendingRequestedTab() {
        guard let requestedTab else { return }

        applyRequestedTab(requestedTab, capturePlaceName: requestedCapturePlaceName)
        self.requestedTab = nil
        requestedCapturePlaceName = nil
    }

    private func applyRequestedTab(_ tab: MaplogTab) {
        applyRequestedTab(tab, capturePlaceName: nil)
    }

    private func applyRequestedTab(_ tab: MaplogTab, capturePlaceName: String?) {
        if tab == .capture {
            activeCapturePlaceName = capturePlaceName
            if selectedTab != .capture {
                previousTab = selectedTab
            }
        } else {
            previousTab = tab
        }
        selectedTab = tab
    }
}

private struct MaplogTabBarHiddenPreferenceKey: PreferenceKey {
    static var defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

private struct MaplogTabBarReelStylePreferenceKey: PreferenceKey {
    static var defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    func maplogTabBarHidden(_ hidden: Bool = true) -> some View {
        preference(key: MaplogTabBarHiddenPreferenceKey.self, value: hidden)
    }

    func maplogReelTabBarStyle(_ active: Bool = true) -> some View {
        preference(key: MaplogTabBarReelStylePreferenceKey.self, value: active)
    }
}

struct MaplogTabBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selectedTab: MaplogTab
    var isCompact = false
    var isReelStyle = false

    @ViewBuilder
    var body: some View {
        if isCompact {
            compactTabBar
        } else {
            standardTabBar
        }
    }

    private var standardTabBar: some View {
        HStack(spacing: 0) {
            ForEach(MaplogTab.allCases) { tab in
                Button {
                    select(tab, response: 0.35, dampingFraction: 0.86)
                } label: {
                    MaplogTabBarItem(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        tint: itemColor(for: tab)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, MaplogSpacing.xSmall)
        .padding(.top, 7)
        .padding(.bottom, 5)
        .frame(maxWidth: .infinity)
        .frame(height: MaplogSize.tabBarHeight)
        .background {
            Rectangle()
                .fill(.white.opacity(0.98))
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.maplogLine.opacity(0.82))
                        .frame(height: 1)
                }
        }
    }

    private var compactTabBar: some View {
        HStack(spacing: 4) {
            ForEach(MaplogTab.allCases) { tab in
                Button {
                    select(tab, response: 0.32, dampingFraction: 0.88)
                } label: {
                    Image(systemName: tab.icon)
                        .font(.system(size: isReelStyle ? 18 : 19, weight: .semibold))
                        .foregroundStyle(isReelStyle ? Color.maplogInk : Color.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: MaplogSize.minimumTapTarget)
                        .background {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(Color.maplogPrimary.opacity(0.24))
                                    .padding(.horizontal, 2)
                                    .padding(.vertical, 4)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, isReelStyle ? MaplogSpacing.xxSmall : MaplogSpacing.xSmall)
        .frame(maxWidth: isReelStyle ? 286 : 330)
        .frame(height: isReelStyle ? 48 : 54)
        .background {
            Capsule()
                .fill(
                    isReelStyle
                        ? AnyShapeStyle(Color.maplogSurface.opacity(0.94))
                        : AnyShapeStyle(Color.maplogSurface.opacity(0.96))
                )
        }
        .clipShape(Capsule())
        .shadow(
            color: .black.opacity(isReelStyle ? 0.10 : 0.12),
            radius: isReelStyle ? 10 : 12,
            x: 0,
            y: isReelStyle ? 4 : 5
        )
        .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: isReelStyle)
    }

    private func itemColor(for tab: MaplogTab) -> Color {
        selectedTab == tab ? .maplogLime : .maplogMuted
    }

    private func select(_ tab: MaplogTab, response: Double, dampingFraction: Double) {
        if reduceMotion {
            selectedTab = tab
        } else {
            withAnimation(.spring(response: response, dampingFraction: dampingFraction)) {
                selectedTab = tab
            }
        }
    }
}

private struct MaplogTabBarItem: View {
    let tab: MaplogTab
    let isSelected: Bool
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous)
                        .fill(tab == .capture ? Color.maplogLime : Color.maplogLime.opacity(0.16))
                        .frame(width: 42, height: 30)
                }

                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tab == .capture && isSelected ? Color.maplogInk : tint)
            }
            .frame(height: 32)

            Text(tab.title)
                .font(MaplogFont.tabLabel)
                .foregroundStyle(isSelected ? (tab == .capture ? Color.maplogInk : tint) : Color.maplogMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}
