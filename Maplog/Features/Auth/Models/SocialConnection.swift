import Foundation

/// 소셜 계정 관리에는 로그인 화면 제공자 목록과 별개로 서버의 연결 목록을 사용한다.
struct SocialConnection: Identifiable, Equatable {
    let provider: String
    let isConnected: Bool
    let createdAt: String?
    let updatedAt: String?
    var id: String { provider }

    var displayName: String {
        switch provider {
        case "google": return "Google"
        case "kakao": return "카카오"
        case "naver": return "네이버"
        case "apple": return "Apple"
        default: return provider
        }
    }
}
