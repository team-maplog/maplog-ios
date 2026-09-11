import Foundation

struct CommentReportRequestDTO: Encodable {
    let targetType = "COMMENT"
    let targetId: Int64
    let reason: String
}

struct CommentReportReceiptDTO: Decodable {
    let reportId: Int64
    let status: String
    let createdAt: String
}

struct CommentAuthorBlockStateDTO: Decodable {
    let userId: UUID
    let blocked: Bool
}

/// GET, POST, PATCH 댓글 API가 공통으로 반환하는 서버 DTO입니다.
struct LogCommentResponseDTO: Decodable {
    let commentID: Int64
    let author: LogCommentAuthorDTO
    let parentCommentID: Int64?
    /// 삭제 댓글은 서버가 본문을 숨기기 위해 `null`을 반환할 수 있습니다.
    let content: String?
    let deleted: Bool
    let createdAt: String
    let updatedAt: String
    let likeCount: Int64
    let likedByViewer: Bool

    enum CodingKeys: String, CodingKey {
        case commentID = "commentId"
        case author
        case parentCommentID = "parentCommentId"
        case content
        case deleted
        case createdAt
        case updatedAt
        case likeCount
        case likedByViewer
    }
}

struct LogCommentAuthorDTO: Decodable {
    let userID: UUID
    let nickname: String
    let profileImageURL: String?

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case nickname
        case profileImageURL = "profileImageUrl"
    }
}

struct CreateLogCommentRequestDTO: Encodable {
    let content: String
    let parentCommentID: Int64?

    enum CodingKeys: String, CodingKey {
        case content
        case parentCommentID = "parentCommentId"
    }
}

struct UpdateLogCommentRequestDTO: Encodable {
    let content: String
}

struct LogCommentLikeStateResponseDTO: Decodable {
    let commentID: Int64
    let liked: Bool

    enum CodingKeys: String, CodingKey {
        case commentID = "commentId"
        case liked
    }
}
