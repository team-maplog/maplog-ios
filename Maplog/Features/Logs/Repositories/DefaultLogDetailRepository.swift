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

    func updateCaption(
        logID: Int64,
        caption: String
    ) async throws -> LogCaptionUpdateResult {
        let responseDTO = try await apiService.updateLogCaption(
            logID: logID,
            request: UpdateLogRequestDTO(caption: caption)
        )

        return LogCaptionUpdateResult(caption: responseDTO.caption)
    }

    func deleteLog(
        logID: Int64
    ) async throws {
        try await apiService.deleteLog(logID: logID)
    }
}
