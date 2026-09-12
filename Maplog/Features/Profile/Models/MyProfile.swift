import Foundation

struct MyProfile: Equatable, Sendable {
    let id: UUID
    let nickname: String
    let profileImageURL: URL?
    let bio: String
    let followerCount: Int64
    let followingCount: Int64
    let logCount: Int64
}

/// 다른 사용자의 공개 프로필 API가 반환하는 정보입니다.
/// 내 프로필과 달리, 현재 사용자가 이 사용자를 팔로우 중인지도 함께 담습니다.
struct PublicProfile: Equatable, Sendable {
    let id: UUID
    let nickname: String
    let profileImageURL: URL?
    let bio: String
    let followerCount: Int64
    let followingCount: Int64
    let logCount: Int64
    let isFollowedByViewer: Bool
    let createdAt: Date

    func replacingFollowState(
        isFollowedByViewer: Bool
    ) -> PublicProfile {
        let followerCountChange: Int64

        switch (self.isFollowedByViewer, isFollowedByViewer) {
        case (false, true):
            followerCountChange = 1
        case (true, false):
            followerCountChange = -1
        default:
            followerCountChange = 0
        }

        return PublicProfile(
            id: id,
            nickname: nickname,
            profileImageURL: profileImageURL,
            bio: bio,
            followerCount: max(0, followerCount + followerCountChange),
            followingCount: followingCount,
            logCount: logCount,
            isFollowedByViewer: isFollowedByViewer,
            createdAt: createdAt
        )
    }
}

struct ProfileLog: Identifiable, Equatable, Sendable {
    let id: Int64
    let thumbnailURL: URL?
    let address: String
    let videoDurationMillis: Int64
    let viewCount: Int64
    let createdAt: Date
}

struct ProfileLogPage: Equatable, Sendable {
    let logs: [ProfileLog]
    let hasNext: Bool
    let nextCursor: String?
}

struct ProfileUpdate: Sendable {
    let nickname: String
    let bio: String
    let newProfileImageData: Data?
}
