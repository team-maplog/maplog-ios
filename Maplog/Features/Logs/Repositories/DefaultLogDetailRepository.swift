import Foundation

final class DefaultLogDetailRepository: LogDetailRepository {
    private let apiService: any LogDetailAPIService

    init(
        apiService: any LogDetailAPIService
    ) {
        self.apiService = apiService
    }

    func fetchDetail(
        logID: Int64
    ) async throws -> LogDetail {
        let detailDTO = try await apiService.fetchLogDetail(logID: logID)
        return try LogResponseMapper.makeLogDetail(from: detailDTO)
    }

    func updateLog(
        logID: Int64,
        draft: LogUpdateDraft
    ) async throws -> LogUpdateResult {
        let responseDTO = try await apiService.updateLog(
            logID: logID,
            request: UpdateLogRequestDTO(
                caption: draft.caption,
                tags: draft.tags?.map(\.rawValue)
            )
        )

        return LogUpdateResult(
            caption: responseDTO.caption,
            tags: responseDTO.tags.map { LogTag.makeTags(from: $0) }
                ?? draft.tags
                ?? []
        )
    }

    func deleteLog(
        logID: Int64
    ) async throws {
        try await apiService.deleteLog(logID: logID)
    }
}
