import Foundation

struct MyProfileResponseDTO: Decodable {
    let userID: UUID
    let nickname: String
    let profileImageURL: String?
    let bio: String?
    let followerCount: Int64
    let followingCount: Int64
    let logCount: Int64

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case nickname
        case profileImageURL = "profileImageUrl"
        case bio
        case followerCount
        case followingCount
        case logCount
    }
}

/// GET /api/v1/users/@{nickname}의 data입니다.
struct PublicProfileResponseDTO: Decodable {
    let userID: UUID
    let nickname: String
    let profileImageURL: String?
    let bio: String?
    let followerCount: Int64
    let followingCount: Int64
    let logCount: Int64
    let followedByViewer: Bool
    let createdAt: String?
    var blockedByViewer: Bool = false

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case nickname
        case profileImageURL = "profileImageUrl"
        case bio
        case followerCount
        case followingCount
        case logCount
        case followedByViewer
        case createdAt
        case blockedByViewer
    }
}

extension PublicProfileResponseDTO {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        userID = try values.decode(UUID.self, forKey: .userID)
        nickname = try values.decode(String.self, forKey: .nickname)
        profileImageURL = try values.decodeIfPresent(String.self, forKey: .profileImageURL)
        bio = try values.decodeIfPresent(String.self, forKey: .bio)
        followerCount = try values.decode(Int64.self, forKey: .followerCount)
        followingCount = try values.decode(Int64.self, forKey: .followingCount)
        logCount = try values.decode(Int64.self, forKey: .logCount)
        followedByViewer = try values.decode(Bool.self, forKey: .followedByViewer)
        createdAt = try values.decodeIfPresent(String.self, forKey: .createdAt)
        blockedByViewer = try values.decodeIfPresent(Bool.self, forKey: .blockedByViewer) ?? false
    }
}

struct ProfileLogPageDTO: Decodable {
    let content: [ProfileLogResponseDTO]
    let hasNext: Bool
    let nextCursor: String?
}

struct ProfileLogResponseDTO: Decodable {
    let logID: Int64
    let thumbnailURL: String?
    let address: String
    let videoDurationMillis: Int64
    let viewCount: Int64
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case logID = "logId"
        case thumbnailURL = "thumbnailUrl"
        case address
        case videoDurationMillis
        case viewCount
        case createdAt
    }
}

struct UpdateMyProfileRequestDTO: Encodable {
    let nickname: String
    let profileImageFileID: Int64?
    let bio: String

    enum CodingKeys: String, CodingKey {
        case nickname
        case profileImageFileID = "profileImageFileId"
        case bio
    }
}

struct ProfileImageUploadResponseDTO: Decodable {
    let fileID: Int64

    enum CodingKeys: String, CodingKey {
        case fileID = "fileId"
    }
}
