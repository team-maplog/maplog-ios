import SwiftUI

@main
struct MaplogApp: App { // 앱의 조립 담당자
    @StateObject private var authSessionStore:  AuthSessionStore
    @StateObject private var signOutViewModel: SignOutViewModel
    private let authRepository: any AuthRepository
    private let tourismRepository: any TourismRepository // 여기서 선언
    private let cameraCaptureService: any CameraCaptureService
    private let mediaDraftRepository: any MediaDraftRepository
    private let videoThumbnailService: any VideoThumbnailService
    private let videoPlaybackService: any VideoPlaybackService
    private let videoExportService: any VideoExportService
    private let captureLocationService: any CaptureLocationService
    private let logLocationRepository: any LogLocationRepository

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

        let authRepository = DefaultAuthRepository(
            apiService: authAPIService
        )

        let tokenRefresher = DefaultAccessTokenRefresher(authRepository: authRepository, authSession: sessionStore)

        let authenticatedAPIClient = AuthenticatedAPIClient(apiClient: apiClient, authSession: sessionStore, tokenRefresher: tokenRefresher)

        let apiService = DefaultTourismAPIService(authenticatedAPIClient: authenticatedAPIClient)

        let logLocationAPIService = DefaultLogLocationAPIService(authenticatedAPIClient: authenticatedAPIClient)

        let logLocationRepository = DefaultLogLocationRepository(apiService: logLocationAPIService)

        let textOverlayRenderer = VideoTextOverlayRenderer()

        self.authRepository = authRepository

        _signOutViewModel = StateObject(wrappedValue: SignOutViewModel(authRepository: authRepository, authSessionStore: sessionStore))



//        tourismRepository
//        → apiService를 보관
        //        → apiClient를 보관
        //        실제 객체는 사라지지 않음. Repository가 그 API Service를 가지고 있기 때문
        //        MaplogApp이 원래 가지고 있기로 선언한 저장 프로퍼티를 초기화하는 코드
        self.tourismRepository = DefaultTourismRepository(apiService: apiService)

        self.cameraCaptureService = AVCameraCaptureService()

        self.mediaDraftRepository = FileMediaDraftRepository()

        self.videoThumbnailService = AVVideoThumbnailService()

        self.videoPlaybackService = AVVideoPlaybackService()

        self.videoExportService = AVVideoExportService(textOverlayRenderer: textOverlayRenderer)

        self.captureLocationService = CoreLocationCaptureLocationService()

        self.logLocationRepository = logLocationRepository
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                authRepository: authRepository,
                tourismRepository: tourismRepository, // Composition Root
                cameraCaptureService: cameraCaptureService,
                mediaDraftRepository: mediaDraftRepository,
                videoThumbnailService: videoThumbnailService,
                videoPlaybackService: videoPlaybackService,
                videoExportService: videoExportService,
                captureLocationService: captureLocationService,
                logLocationRepository: logLocationRepository
            )
            .environmentObject(authSessionStore)
            .environmentObject(signOutViewModel)
        }
    }
}
