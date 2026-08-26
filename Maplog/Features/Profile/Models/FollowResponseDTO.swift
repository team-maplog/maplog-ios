import Foundation

struct FollowUserPageDTO: Decodable {
    let content: [FollowUserSummaryDTO]
    let hasNext: Bool
    let nextCursor: String?
}

struct FollowUserSummaryDTO: Decodable {
    let userID: UUID
    let nickname: String
    let profileImageURL: String?

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case nickname
        case profileImageURL = "profileImageUrl"
    }
}

struct FollowStateResponseDTO: Decodable {
    let followingUserID: UUID
    let following: Bool

    enum CodingKeys: String, CodingKey {
        case followingUserID = "followingUserId"
        case following
    }
}
