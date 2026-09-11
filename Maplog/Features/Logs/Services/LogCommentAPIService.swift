import Foundation

/// Swagger의 댓글 endpoint를 호출하는 네트워크 경계입니다.
protocol LogCommentAPIService {
    func reportComment(request: CommentReportRequestDTO) async throws -> CommentReportReceiptDTO
    func blockAuthor(userID: UUID) async throws -> CommentAuthorBlockStateDTO

    func fetchComments(
        logID: Int64
    ) async throws -> [LogCommentResponseDTO]

    func createComment(
        logID: Int64,
        request: CreateLogCommentRequestDTO
    ) async throws -> LogCommentResponseDTO

    func updateComment(
        commentID: Int64,
        request: UpdateLogCommentRequestDTO
    ) async throws -> LogCommentResponseDTO

    func deleteComment(
        commentID: Int64
    ) async throws

    func setLike(
        commentID: Int64,
        isLiked: Bool
    ) async throws -> LogCommentLikeStateResponseDTO
}
