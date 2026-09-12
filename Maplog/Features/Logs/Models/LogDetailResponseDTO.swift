import Foundation

/// GET /api/v1/logs/{logId}의 data입니다.
/// 릴스 한 건과 응답 구조는 같지만, 상세 API 계약을 분명히 하기 위해 DTO는 따로 둡니다.
struct LogDetailResponseDTO: Decodable {
    let logID: Int64
    let author: LogReelAuthorDTO
    let caption: String
    let tags: [String]?
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
        case tags
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
    let caption: String?
    let tags: [String]?
    var address: String? = nil
    var clips: [UpdateLogClipLocationDTO]? = nil

    enum CodingKeys: String, CodingKey {
        case caption
        case tags
        case address
        case clips
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(caption, forKey: .caption)
        // nil은 "태그는 수정하지 않음", 빈 배열은 "태그 전체 해제"입니다.
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(clips, forKey: .clips)
    }
}

/// PATCH /api/v1/logs/{logId}의 data입니다.
struct LogBasicResponseDTO: Decodable {
    let logID: Int64
    let caption: String
    let tags: [String]?
    let address: String
    let publishedAt: String
    let viewCount: Int64
    let playbackURL: String?

    enum CodingKeys: String, CodingKey {
        case logID = "logId"
        case caption
        case tags
        case address
        case publishedAt
        case viewCount
        case playbackURL = "playbackUrl"
    }
}

/// 상세 응답의 클립 ID를 사용하며 영상·순서·시간은 PATCH에 포함하지 않습니다.
struct UpdateLogClipLocationDTO: Encodable {
    let logClipID: Int64
    let location: LogCreateLocationDTO

    enum CodingKeys: String, CodingKey {
        case logClipID = "logClipId"
        case location
    }
}
