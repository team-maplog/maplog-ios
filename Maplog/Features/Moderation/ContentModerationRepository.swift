import Foundation

enum ContentReportTargetType: String, Encodable {
    case log = "LOG"
    case comment = "COMMENT"
}

protocol ContentModerationAPIService {
    func reportContent(request: ContentReportRequestDTO) async throws -> CommentReportReceiptDTO
    func blockAuthor(userID: UUID) async throws -> CommentAuthorBlockStateDTO
}

protocol ContentModerationRepository {
    func reportLog(id: Int64, reason: String) async throws
    func blockUser(id: UUID) async throws
}

final class DefaultContentModerationRepository: ContentModerationRepository {
    private let apiService: any ContentModerationAPIService

    init(apiService: any ContentModerationAPIService) {
        self.apiService = apiService
    }

    func reportLog(id: Int64, reason: String) async throws {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard id > 0, !trimmed.isEmpty, trimmed.utf16.count <= 1000 else {
            throw APIError.invalidRequest(reason: "신고 사유는 1~1,000자로 입력해 주세요.")
        }
        let receipt = try await apiService.reportContent(
            request: ContentReportRequestDTO(targetType: .log, targetId: id, reason: trimmed)
        )
        guard receipt.reportId > 0, receipt.status == "PENDING" else { throw APIError.invalidResponse }
    }

    func blockUser(id: UUID) async throws {
        let result = try await apiService.blockAuthor(userID: id)
        guard result.userId == id, result.blocked else { throw APIError.invalidResponse }
    }
}
