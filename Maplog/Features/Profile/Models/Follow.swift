import Foundation

enum FollowListKind: CaseIterable, Hashable, Sendable {
    case followers
    case following

    var title: String {
        switch self {
        case .followers:
            return "팔로워"
        case .following:
            return "팔로잉"
        }
    }
}

/// 팔로우 API와 댓글·로그 작성자 응답이 공통으로 제공하는 공개 사용자 정보입니다.
/// 현재 서버에는 공개 사용자 상세 조회 API가 없으므로, 이 정보가 공개 프로필 화면의 데이터 경계가 됩니다.
struct FollowUser: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let nickname: String
    let profileImageURL: URL?
}

struct FollowUserPage: Equatable, Sendable {
    let users: [FollowUser]
    let hasNext: Bool
    let nextCursor: String?
}

struct FollowState: Equatable, Sendable {
    let userID: UUID
    let isFollowing: Bool
}
