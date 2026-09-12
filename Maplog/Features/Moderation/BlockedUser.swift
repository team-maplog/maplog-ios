import Foundation

struct BlockedUser: Identifiable, Hashable {
    let id: UUID
    let nickname: String
    // 차단 목록 API는 탈퇴 상태 대신 이 고정 닉네임을 반환합니다.
    var canOpenProfile: Bool { nickname != "탈퇴한 사용자" && !nickname.isEmpty }
}

struct BlockedUserPage {
    let users: [BlockedUser]
    let page: Int
    let hasNext: Bool
}

struct BlockedUserPageDTO: Decodable {
    let content: [BlockedUserDTO]
    let page: Int
    let hasNext: Bool
}

struct BlockedUserDTO: Decodable {
    let userId: UUID
    let nickname: String
}
