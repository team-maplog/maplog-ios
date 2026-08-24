import Foundation

protocol LogDetailRepository {
    func fetchDetail(
        logID: Int64
    ) async throws -> LogDetail

    func updateCaption(
        logID: Int64,
        caption: String
    ) async throws -> LogCaptionUpdateResult

    func deleteLog(
        logID: Int64
    ) async throws
}
