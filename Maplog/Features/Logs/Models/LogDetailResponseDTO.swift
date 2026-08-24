import Foundation

/// GET /api/v1/logs/{logId}의 data입니다.
/// 릴스 한 건과 응답 구조는 같지만, 상세 API 계약을 분명히 하기 위해 DTO는 따로 둡니다.
struct LogDetailResponseDTO: Decodable {
    let logID: Int64
    let author: LogReelAuthorDTO
    let caption: String
    let address: String
    let thumbnailURL: String?
    let playbackURL: String?
    let publishedAt: String
    let viewCount: Int64
    let clips: [LogReelClipDTO]
    let likeCount: Int64
    let commentCount: Int64
    let likedByViewer: Bool
    let savedByViewer: Bool

    enum CodingKeys: String, CodingKey {
        case logID = "logId"
        case author
        case caption
        case address
        case thumbnailURL = "thumbnailUrl"
        case playbackURL = "playbackUrl"
        case publishedAt
        case viewCount
        case clips
        case likeCount
        case commentCount
        case likedByViewer
        case savedByViewer
    }
}

/// PATCH /api/v1/logs/{logId}의 request body입니다.
struct UpdateLogRequestDTO: Encodable {
    let caption: String
}

/// PATCH /api/v1/logs/{logId}의 data입니다.
struct LogBasicResponseDTO: Decodable {
    let logID: Int64
    let caption: String
    let address: String
    let publishedAt: String
    let viewCount: Int64
    let playbackURL: String?

    enum CodingKeys: String, CodingKey {
        case logID = "logId"
        case caption
        case address
        case publishedAt
        case viewCount
        case playbackURL = "playbackUrl"
    }
}
