import Foundation

struct BlockedUser: Identifiable, Equatable {
    let id: UUID
    let nickname: String
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
