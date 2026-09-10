import SwiftUI

@main
struct MaplogApp: App { // 앱의 조립 담당자
    @UIApplicationDelegateAdaptor(MaplogAppDelegate.self) private var appDelegate
    @StateObject private var authSessionStore:  AuthSessionStore
    @StateObject private var signOutViewModel: SignOutViewModel
    @StateObject private var pushNotificationCoordinator: PushNotificationCoordinator
    private let authRepository: any AuthRepository
    private let oauthRepository: any OAuthRepository
    private let webAuthenticationSession: any OAuthWebAuthenticationSession
    private let sessionLifecycle: any AuthSessionLifecycleManaging
    private let tourismRepository: any TourismRepository // 여기서 선언
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
    private let notificationRepository: any NotificationRepository
    private let mapCurrentLocationService: any MapCurrentLocationService
    private let locationPermissionService: any LocationPermissionService
    private let photoLibraryVideoImportService: any PhotoLibraryVideoImporting
    private let photoLibraryVideoSaveService: any PhotoLibraryVideoSaving


    init() {
        KakaoMapSDKConfiguration.initializeIfNeeded()

        let sessionStore = AuthSessionStore()
        _authSessionStore = StateObject(wrappedValue: sessionStore) // @StateObject property wrapper 자체를 초기화

        let apiClient = APIClient()

        let authAPIService = DefaultAuthAPIService(
            apiClient: apiClient,
            accessTokenProvider: sessionStore,
            refreshTokenProvider: sessionStore
        )

        let authRepository = DefaultAuthRepository(apiService: authAPIService)
        let oauthAPIService = DefaultOAuthAPIService(apiClient: apiClient)
        let oauthRepository = DefaultOAuthRepository(apiService: oauthAPIService)
        let webAuthenticationSession = SystemOAuthWebAuthenticationSession()
        let tokenRefresher = DefaultAccessTokenRefresher(authRepository: authRepository, authSession: sessionStore)
        let authenticatedAPIClient = AuthenticatedAPIClient(apiClient: apiClient, authSession: sessionStore, tokenRefresher: tokenRefresher)
        let apiService = DefaultTourismAPIService(authenticatedAPIClient: authenticatedAPIClient)
        let logLocationAPIService = DefaultLogLocationAPIService(authenticatedAPIClient: authenticatedAPIClient)
        let logLocationRepository = DefaultLogLocationRepository(apiService: logLocationAPIService)
        let logPublishingAPIService = DefaultLogPublishingAPIService(authenticatedAPIClient: authenticatedAPIClient)
        let logPublishingRepository = DefaultLogPublishingRepository(apiService: logPublishingAPIService)
        let logReelAPIService = DefaultLogReelAPIService(authenticatedAPIClient: authenticatedAPIClient)
        let logReelRepository = DefaultLogReelRepository(apiService: logReelAPIService)
        let logInteractionAPIService = DefaultLogInteractionAPIService(
            authenticatedAPIClient: authenticatedAPIClient
        )
        let logInteractionRepository = DefaultLogInteractionRepository(
            apiService: logInteractionAPIService
        )
        let logCommentAPIService = DefaultLogCommentAPIService(
            authenticatedAPIClient: authenticatedAPIClient
        )
        let logCommentRepository = DefaultLogCommentRepository(
            apiService: logCommentAPIService
        )
        let textOverlayRenderer = VideoTextOverlayRenderer()
        let imageDataLoader = KingfisherImageDataLoader(
            apiClient: apiClient,
            authenticatedAPIClient: authenticatedAPIClient
        )
        let logMediaAPIService = DefaultLogMediaAPIService(
            authenticatedAPIClient: authenticatedAPIClient,
            imageDataLoader: imageDataLoader
        )
        let logMediaRepository = DefaultLogMediaRepository(apiService: logMediaAPIService)
        let logRouteAPIService = DefaultLogRouteAPIService(authenticatedAPIClient: authenticatedAPIClient)
        let logRouteRepository = DefaultLogRouteRepository(apiService: logRouteAPIService)
        let logDetailAPIService = DefaultLogDetailAPIService(authenticatedAPIClient: authenticatedAPIClient)
        let logDetailRepository = DefaultLogDetailRepository(apiService: logDetailAPIService)
        let profileAPIService = DefaultProfileAPIService(
            authenticatedAPIClient: authenticatedAPIClient,
            imageDataLoader: imageDataLoader
        )
        let profileRepository = DefaultProfileRepository(apiService: profileAPIService)
        let sessionValidationAPIService = DefaultSessionValidationAPIService(
            authenticatedAPIClient: authenticatedAPIClient
        )
        let sessionValidationRepository = DefaultSessionValidationRepository(
            apiService: sessionValidationAPIService
        )
        let sessionLifecycle = DefaultAuthSessionLifecycleManager(
            authSession: sessionStore,
            sessionValidationRepository: sessionValidationRepository
        )
        let followAPIService = DefaultFollowAPIService(
            authenticatedAPIClient: authenticatedAPIClient
        )
        let followRepository = DefaultFollowRepository(
            apiService: followAPIService
        )
        let mapAPIService = DefaultMapAPIService(authenticatedAPIClient: authenticatedAPIClient)
        let mapRepository = DefaultMapRepository(apiService: mapAPIService)
        let homeSearchAPIService = DefaultHomeSearchAPIService(
            authenticatedAPIClient: authenticatedAPIClient
        )
        let homeSearchRepository = DefaultHomeSearchRepository(
            apiService: homeSearchAPIService
        )
        let notificationAPIService = DefaultNotificationAPIService(
            authenticatedAPIClient: authenticatedAPIClient
        )
        let notificationRepository = DefaultNotificationRepository(
            apiService: notificationAPIService
        )
        self.authRepository = authRepository
        self.oauthRepository = oauthRepository
        self.webAuthenticationSession = webAuthenticationSession
        self.sessionLifecycle = sessionLifecycle

        _signOutViewModel = StateObject(wrappedValue: SignOutViewModel(authRepository: authRepository, authSessionStore: sessionStore))
        _pushNotificationCoordinator = StateObject(
            wrappedValue: PushNotificationCoordinator(
                notificationRepository: notificationRepository,
                authenticationState: sessionStore,
                tokenStore: KeychainPushNotificationTokenStore(),
                onNavigate: { destination in
                    MaplogLaunchRequest.requestNotificationDestination(destination)
                }
            )
        )



//        tourismRepository
//        → apiService를 보관
        //        → apiClient를 보관
        //        실제 객체는 사라지지 않음. Repository가 그 API Service를 가지고 있기 때문
        //        MaplogApp이 원래 가지고 있기로 선언한 저장 프로퍼티를 초기화하는 코드
        self.tourismRepository = DefaultTourismRepository(
            apiService: apiService,
            posterCatalog: LocalVerifiedTourismPosterCatalog(posters: VerifiedTourismPosters.entries)
        )
        self.cameraCaptureService = AVCameraCaptureService()
        self.mediaDraftRepository = FileMediaDraftRepository()
        self.videoThumbnailService = AVVideoThumbnailService()
        self.videoPlaybackService = AVVideoPlaybackService()
        self.videoExportService = AVVideoExportService(textOverlayRenderer: textOverlayRenderer)
        self.captureLocationService = CoreLocationCaptureLocationService()
        self.logLocationRepository = logLocationRepository
        self.logPublishingRepository = logPublishingRepository
        self.logReelRepository = logReelRepository
        self.logInteractionRepository = logInteractionRepository
        self.logCommentRepository = logCommentRepository
        self.logMediaRepository = logMediaRepository
        self.homeReelPlaybackService = AVVideoPlaybackService()
        self.logRouteRepository = logRouteRepository
        self.logDetailRepository = logDetailRepository
        self.profileRepository = profileRepository
        self.followRepository = followRepository
        self.mapRepository = mapRepository
        self.homeSearchRepository = homeSearchRepository
        self.notificationRepository = notificationRepository
        self.mapCurrentLocationService = CoreLocationMapCurrentLocationService()
        self.locationPermissionService = CoreLocationPermissionService()
        self.photoLibraryVideoImportService = PhotoLibraryVideoImportService()
        self.photoLibraryVideoSaveService = PhotoLibraryVideoSaveService()
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                authRepository: authRepository,
                oauthRepository: oauthRepository,
                webAuthenticationSession: webAuthenticationSession,
                sessionLifecycle: sessionLifecycle,
                tourismRepository: tourismRepository, // Composition Root
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
                notificationRepository: notificationRepository,
                pushNotificationCoordinator: pushNotificationCoordinator,
                mapCurrentLocationService: mapCurrentLocationService,
                locationPermissionService: locationPermissionService,
                photoLibraryVideoImportService: photoLibraryVideoImportService,
                photoLibraryVideoSaveService: photoLibraryVideoSaveService

            )
            .environmentObject(authSessionStore)
            .environmentObject(signOutViewModel)
            .task {
                appDelegate.installHandlers(
                    onFCMToken: { token in
                        Task {
                            await pushNotificationCoordinator
                                .receiveFCMRegistrationToken(token)
                        }
                    },
                    onRemoteNotification: { userInfo in
                        pushNotificationCoordinator.handleRemoteNotification(
                            userInfo: userInfo
                        )
                    },
                    onForegroundNotification: {
                        pushNotificationCoordinator.handleForegroundNotification()
                    }
                )

                await pushNotificationCoordinator.refreshAuthorizationStatus()
                await pushNotificationCoordinator.syncCachedTokenIfAuthenticated()
            }
            .onChange(of: authSessionStore.isAuthenticated) { _, isAuthenticated in
                guard isAuthenticated else {
                    return
                }

                Task {
                    await pushNotificationCoordinator.syncCachedTokenIfAuthenticated()
                }
            }
            .preferredColorScheme(.light)
        }
    }
}
