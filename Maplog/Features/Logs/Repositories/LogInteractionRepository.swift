import Foundation

/// 릴스와 상세 화면이 사용하는 로그 상호작용의 앱 경계입니다.
/// ViewModel은 HTTP method나 응답 DTO 대신 이 결과만 알면 됩니다.
protocol LogInteractionRepository {
    func setLike(
        logID: Int64,
        isLiked: Bool
    ) async throws -> LogLikeInteractionResult

    func setSaved(
        logID: Int64,
        isSaved: Bool
    ) async throws -> LogSaveInteractionResult
}
