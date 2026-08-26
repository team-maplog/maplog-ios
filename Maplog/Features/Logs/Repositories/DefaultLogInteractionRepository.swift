import Foundation

final class DefaultLogInteractionRepository: LogInteractionRepository {
    private let apiService: any LogInteractionAPIService

    init(apiService: any LogInteractionAPIService) {
        self.apiService = apiService
    }

    func setLike(
        logID: Int64,
        isLiked: Bool
    ) async throws -> LogLikeInteractionResult {
        let response = try await apiService.setLike(
            logID: logID,
            isLiked: isLiked
        )

        guard response.logID == logID else {
            throw APIError.invalidResponse
        }

        return LogLikeInteractionResult(
            logID: response.logID,
            isLiked: response.liked
        )
    }

    func setSaved(
        logID: Int64,
        isSaved: Bool
    ) async throws -> LogSaveInteractionResult {
        let response = try await apiService.setSaved(
            logID: logID,
            isSaved: isSaved
        )

        guard response.logID == logID else {
            throw APIError.invalidResponse
        }

        return LogSaveInteractionResult(
            logID: response.logID,
            isSaved: response.saved
        )
    }
}
