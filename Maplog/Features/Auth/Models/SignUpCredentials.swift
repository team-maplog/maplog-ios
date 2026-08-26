import Foundation

/// 회원가입 화면이 Repository에 전달하는 앱 내부 입력 모델입니다.
/// 서버 JSON 형태는 SignUpRequestDTO가 맡습니다.
struct SignUpCredentials {
    let email: String
    let password: String
    let passwordConfirmation: String
    let nickname: String
    let termsAgreed: Bool
    let privacyPolicyAgreed: Bool
}
