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
