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
