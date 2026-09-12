import Foundation

/// POST /api/v1/auth/signup 요청 JSON입니다.
struct SignUpRequestDTO: Encodable {
    let email: String
    let password: String
    let passwordConfirmation: String
    let nickname: String
    let termsAgreed: Bool
    let privacyPolicyAgreed: Bool
}
