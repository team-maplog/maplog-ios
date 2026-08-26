import Foundation

protocol FollowAPIService {
    func fetchUsers(
        kind: FollowListKind,
        cursor: String?,
        size: Int
    ) async throws -> FollowUserPageDTO

    func setFollowing(
        userID: UUID,
        isFollowing: Bool
    ) async throws -> FollowStateResponseDTO
}
