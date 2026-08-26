import Foundation

/// 댓글 기능에서 ViewModel이 의존하는 앱 데이터 경계입니다.
/// ViewModel은 URL, HTTP method, JSON DTO를 알 필요가 없습니다.
protocol LogCommentRepository {
    func fetchComments(
        logID: Int64
    ) async throws -> [LogComment]

    func createComment(
        logID: Int64,
        draft: LogCommentDraft
    ) async throws -> LogComment

    func updateComment(
        commentID: Int64,
        content: String
    ) async throws -> LogComment

    func deleteComment(
        commentID: Int64
    ) async throws

    func setLike(
        commentID: Int64,
        isLiked: Bool
    ) async throws -> LogCommentLikeState
}
