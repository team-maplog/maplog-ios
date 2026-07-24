import SwiftUI

@main
struct MaplogApp: App { // 앱의 조립 담당자
    @StateObject private var authSessionStore:  AuthSessionStore
    @StateObject private var signOutViewModel: SignOutViewModel
    private let authRepository: any AuthRepository
    private let tourismRepository: any TourismRepository // 여기서 선언

    init() {
        KakaoMapSDKConfiguration.initializeIfNeeded()

        let sessionStore = AuthSessionStore()
        _authSessionStore = StateObject(wrappedValue: sessionStore) // @StateObject property wrapper 자체를 초기화

        let apiClient = APIClient()

        let authAPIService = DefaultAuthAPIService(
            apiClient: apiClient,
            accessTokenProvider: sessionStore
        )

        let authRepository = DefaultAuthRepository(
            apiService: authAPIService
        )

        self.authRepository = authRepository

        _signOutViewModel = StateObject(wrappedValue: SignOutViewModel(authRepository: authRepository, authSessionStore: sessionStore))

        // apiService는 init 안에서만 잠깐 쓰는 지역 상수
        //        (init 안에서 Repository를 만들기 위해 잠깐 필요함
        //        init이 끝나면 apiService라는 이름은 사라짐)
        let apiService = DefaultTourismAPIService(
            apiClient: apiClient,
            accessTokenProvider: sessionStore
        )




//        tourismRepository
//        → apiService를 보관
//        → apiClient를 보관
//        실제 객체는 사라지지 않음. Repository가 그 API Service를 가지고 있기 때문
//        MaplogApp이 원래 가지고 있기로 선언한 저장 프로퍼티를 초기화하는 코드
        self.tourismRepository = DefaultTourismRepository(apiService: apiService)
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                authRepository: authRepository,
                tourismRepository: tourismRepository) // Composition Root
                .environmentObject(authSessionStore)
                .environmentObject(signOutViewModel)
        }
    }
}
