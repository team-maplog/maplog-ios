import Foundation

/// GET /api/v1/users/me의 data 중 세션 검증에 필요한 최소 필드만 받음
struct SessionValidationResponseDTO: Decodable {
    let userID: UUID

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
    }
}
