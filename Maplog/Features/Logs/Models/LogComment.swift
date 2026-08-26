import Foundation

/// 로그 상세와 홈 릴스가 공통으로 사용하는 댓글의 앱 내부 모델입니다.
/// 서버 DTO의 키 이름·날짜 문자열은 Repository에서 이 타입으로 변환됩니다.
struct LogComment: Identifiable, Equatable, Sendable {
    let id: Int64
    let author: LogCommentAuthor
    let parentCommentID: Int64?
    let content: String
    let isDeleted: Bool
    let createdAt: Date
    let updatedAt: Date
    let likeCount: Int64
    let isLikedByViewer: Bool

    func replacingLike(
        isLikedByViewer: Bool,
        likeCount: Int64
    ) -> LogComment {
        LogComment(
            id: id,
            author: author,
            parentCommentID: parentCommentID,
            content: content,
            isDeleted: isDeleted,
            createdAt: createdAt,
            updatedAt: updatedAt,
            likeCount: likeCount,
            isLikedByViewer: isLikedByViewer
        )
    }

    func replacingContent(
        _ content: String,
        updatedAt: Date
    ) -> LogComment {
        LogComment(
            id: id,
            author: author,
            parentCommentID: parentCommentID,
            content: content,
            isDeleted: isDeleted,
            createdAt: createdAt,
            updatedAt: updatedAt,
            likeCount: likeCount,
            isLikedByViewer: isLikedByViewer
        )
    }

    func markingDeleted() -> LogComment {
        LogComment(
            id: id,
            author: author,
            parentCommentID: parentCommentID,
            content: "",
            isDeleted: true,
            createdAt: createdAt,
            updatedAt: updatedAt,
            likeCount: likeCount,
            isLikedByViewer: isLikedByViewer
        )
    }
}

struct LogCommentAuthor: Equatable, Sendable {
    let id: UUID
    let nickname: String
    let profileImageURL: URL?
}

struct LogCommentDraft: Equatable, Sendable {
    let content: String
    let parentCommentID: Int64?
}

struct LogCommentLikeState: Equatable, Sendable {
    let commentID: Int64
    let isLiked: Bool
}
