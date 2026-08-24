import Foundation

protocol LogDetailAPIService {
    func fetchLogDetail(
        logID: Int64
    ) async throws -> LogDetailResponseDTO

    func updateLogCaption(
        logID: Int64,
        request: UpdateLogRequestDTO
    ) async throws -> LogBasicResponseDTO

    func deleteLog(
        logID: Int64
    ) async throws
}
