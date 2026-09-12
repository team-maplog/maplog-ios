import Foundation

/// 좋아요와 저장 endpoint를 호출하는 네트워크 경계입니다.
/// PUT은 적용, DELETE는 취소이며 둘 다 request body가 없습니다.
protocol LogInteractionAPIService {
    func setLike(
        logID: Int64,
        isLiked: Bool
    ) async throws -> LogLikeInteractionResponseDTO

    func setSaved(
        logID: Int64,
        isSaved: Bool
    ) async throws -> LogSaveInteractionResponseDTO
}
