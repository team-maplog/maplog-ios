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
    @EnvironmentObject private var authSessionStore: AuthSessionStore // 로그인 여부와 JWT 토큰을 관리해. MaplogApp에서 만들어서 주입한 객체

    @StateObject private var sessionStore = MaplogSessionStore() // 기존 앱의 위치 권한, 저장한 로그·장소 같은 앱 내부 상태를 관리해. RootView가 직접 생성·소유

    @State private var hasFinishedInitialAuthCheck = false // keychain 조회 기억 상태
    @State private var phase: LaunchPhase = .login
    @State private var requestedTab: MaplogTab?
    @State private var requestedCapturePlaceName: String?


   // init이 끝난 뒤에도 body에서 쓸 값을 보관
    private let authRepository: any AuthRepository
    private let tourismRepository: any TourismRepository
    private let cameraCaptureService: any CameraCaptureService
    private let mediaDraftRepository: any MediaDraftRepository
    private let videoThumbnailService: any VideoThumbnailService
    private let videoPlaybackService: any VideoPlaybackService
    private let videoExportService: any VideoExportService
    private let captureLocationService: any CaptureLocationService
    private let logLocationRepository: any LogLocationRepository
    private let logPublishingRepository: any LogPublishingRepository
    private let logReelRepository: any LogReelRepository
    private let logInteractionRepository: any LogInteractionRepository
    private let logCommentRepository: any LogCommentRepository
    private let logMediaRepository: any LogMediaRepository
    private let homeReelPlaybackService: any VideoPlaybackService
    private let logRouteRepository: any LogRouteRepository
    private let logDetailRepository: any LogDetailRepository
    private let profileRepository: any ProfileRepository
    private let followRepository: any FollowRepository
    private let mapRepository: any MapRepository
    private let homeSearchRepository: any HomeSearchRepository
    private let mapCurrentLocationService: any MapCurrentLocationService
    private let locationPermissionService: any LocationPermissionService
    @State private var isRequestingLocationPermission = false

    init(
        authRepository: any AuthRepository,
        tourismRepository: any TourismRepository,
        cameraCaptureService: any CameraCaptureService,
        mediaDraftRepository: any MediaDraftRepository,
        videoThumbnailService: any VideoThumbnailService,
        videoPlaybackService: any VideoPlaybackService,
        videoExportService: any VideoExportService,
        captureLocationService: any CaptureLocationService,
        logLocationRepository: any LogLocationRepository,
        logPublishingRepository: any LogPublishingRepository,
        logReelRepository: any LogReelRepository,
        logInteractionRepository: any LogInteractionRepository,
        logCommentRepository: any LogCommentRepository,
        logMediaRepository: any LogMediaRepository,
        homeReelPlaybackService: any VideoPlaybackService,
        logRouteRepository: any LogRouteRepository,
        logDetailRepository: any LogDetailRepository,
        profileRepository: any ProfileRepository,
        followRepository: any FollowRepository,
        mapRepository: any MapRepository,
        homeSearchRepository: any HomeSearchRepository,
        mapCurrentLocationService: any MapCurrentLocationService,
        locationPermissionService: any LocationPermissionService,
    ) {
        self.authRepository = authRepository
        self.tourismRepository = tourismRepository
        self.cameraCaptureService = cameraCaptureService
        self.mediaDraftRepository = mediaDraftRepository
        self.videoThumbnailService = videoThumbnailService
        self.videoPlaybackService = videoPlaybackService
        self.videoExportService = videoExportService
        self.captureLocationService = captureLocationService
        self.logLocationRepository = logLocationRepository
        self.logPublishingRepository = logPublishingRepository
        self.logReelRepository = logReelRepository
        self.logInteractionRepository = logInteractionRepository
        self.logCommentRepository = logCommentRepository
        self.logMediaRepository = logMediaRepository
        self.homeReelPlaybackService = homeReelPlaybackService
        self.logRouteRepository = logRouteRepository
        self.logDetailRepository = logDetailRepository
        self.profileRepository = profileRepository
        self.followRepository = followRepository
        self.mapRepository = mapRepository
        self.homeSearchRepository = homeSearchRepository
        self.mapCurrentLocationService = mapCurrentLocationService
        self.locationPermissionService = locationPermissionService
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
                OnboardingView(authRepository: authRepository)
                {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                        phase = .location
                    }
                }
            case .location:
                LocationPermissionView(
                    onAllow: requestLocationPermission,
                    onSkip: skipLocationPermission,
                    isRequesting: isRequestingLocationPermission
                )
            case .app:
                MainTabView( // RootView는 protocol만 받아서 MainTabView 생성 부분에 전달, DefaultTourismRepository를 모름. 오직 TourismRepository 역할만 앎
                    tourismRepository: tourismRepository,
                    cameraCaptureService: cameraCaptureService,
                    mediaDraftRepository: mediaDraftRepository,
                    videoThumbnailService: videoThumbnailService,
                    videoPlaybackService: videoPlaybackService,
                    videoExportService: videoExportService,
                    captureLocationService: captureLocationService,
                    logLocationRepository: logLocationRepository,
                    logPublishingRepository: logPublishingRepository,
                    logReelRepository: logReelRepository,
                    logInteractionRepository: logInteractionRepository,
                    logCommentRepository: logCommentRepository,
                    logMediaRepository: logMediaRepository,
                    homeReelPlaybackService: homeReelPlaybackService,
                    logRouteRepository: logRouteRepository,
                    logDetailRepository: logDetailRepository,
                    profileRepository: profileRepository,
                    followRepository: followRepository,
                    mapRepository: mapRepository,
                    homeSearchRepository: homeSearchRepository,
                    mapCurrentLocationService: mapCurrentLocationService,
                    requestedTab: $requestedTab,
                    requestedCapturePlaceName: $requestedCapturePlaceName
                )
            }
        }
        .tint(.maplogLime)
        .font(MaplogFont.body)
        .environment(\.maplogLogout) { // endSession이 토큰을 삭제하고 isAuthenticated = false로 만들면, .onChange가 자동으로 로그인 화면으로 이동시킴
            try? authSessionStore.endSession()
        }
        .environmentObject(sessionStore)
        .onAppear(perform: consumeLaunchRequest)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            consumeLaunchRequest()
        }
        .onReceive(NotificationCenter.default.publisher(for: MaplogLaunchRequest.didChangeNotification)) { _ in
            consumeLaunchRequest()
        } // 앱 시작 시 세션 복구
        .task {
            guard !hasFinishedInitialAuthCheck else {
                return
            }

            do {
                try authSessionStore.restoreSession() // refresh token 존재 확인, isAuthenticated 변경
            } catch {

            }

            hasFinishedInitialAuthCheck = true

            if authSessionStore.isAuthenticated {
                phase = .app // ture, 기존 로그인 세션 있으므로 app
            } else {
                phase = .login // false, 로그인 정보 없으므로 login
            }
        } // 회원가입 성공 로그아웃 변화 감지
        .onChange(of: authSessionStore.isAuthenticated) { _, isAuthenticated in
            guard hasFinishedInitialAuthCheck else {
                return
            }

            withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                if isAuthenticated {
                    phase = .location
                } else {
                    phase = .login
                }
            }
        }
    }

    private func requestLocationPermission() {
        guard !isRequestingLocationPermission else {
            return
        }

        isRequestingLocationPermission = true

        Task {
            let result = await locationPermissionService
                .requestWhenInUseAuthorization()

            isRequestingLocationPermission = false

            guard !Task.isCancelled else {
                return
            }

            switch result {
            case .authorized:
                sessionStore.allowLocationPermission()

            case .denied, .servicesDisabled, .unavailable:
                sessionStore.skipLocationPermission()
            }

            moveToApp()
        }
    }

    private func skipLocationPermission() {
        sessionStore.skipLocationPermission()
        moveToApp()
    }

    private func moveToApp() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
            phase = .app
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
