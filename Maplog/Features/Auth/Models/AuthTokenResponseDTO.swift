import Foundation

/// 로그인·회원가입·토큰 재발급 응답에서 공통으로 받는 서버 DTO입니다.
struct AuthTokenResponseDTO: Decodable {
    let grantType: String
    let accessToken: String
    let refreshToken: String
}
