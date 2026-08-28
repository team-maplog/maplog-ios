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

/// 팔로우 API와 댓글·로그 작성자 응답이 공통으로 제공하는 프로필 진입용 정보입니다.
/// 상세 화면은 이 nickname을 사용해 공개 프로필 API를 별도로 조회합니다.
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
