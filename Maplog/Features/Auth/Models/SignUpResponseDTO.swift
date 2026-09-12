import Foundation

/// 회원가입 성공 응답에서 앱 세션 시작에 필요한 토큰만 읽습니다.
/// 서버가 함께 내려주는 사용자 정보는 이 화면의 책임이 아니므로 보관하지 않습니다.
struct SignUpResponseDTO: Decodable {
    let token: AuthTokenResponseDTO
}
