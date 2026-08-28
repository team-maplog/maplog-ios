import Foundation

protocol LogDetailRepository {
    func fetchDetail(
        logID: Int64
    ) async throws -> LogDetail

    func updateLog(
        logID: Int64,
        draft: LogUpdateDraft
    ) async throws -> LogUpdateResult

    func deleteLog(
        logID: Int64
    ) async throws
}
