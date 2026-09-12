import Foundation

protocol FollowRepository {
    func fetchUsers(
        kind: FollowListKind,
        cursor: String?,
        size: Int
    ) async throws -> FollowUserPage

    /// 서버에 단일 사용자 팔로우 상태 조회 API가 없어서, 내 팔로잉 목록을
    /// 커서 끝까지 확인해 상태를 계산합니다. cursor 값은 서버의 opaque 값 그대로만 사용합니다.
    func isFollowing(
        userID: UUID
    ) async throws -> Bool

    func setFollowing(
        userID: UUID,
        isFollowing: Bool
    ) async throws -> FollowState
}
