import Foundation

final class DefaultLogCommentRepository: LogCommentRepository {
    private let apiService: any LogCommentAPIService

    init(apiService: any LogCommentAPIService) {
        self.apiService = apiService
    }

    func fetchComments(
        logID: Int64
    ) async throws -> [LogComment] {
        let responses = try await apiService.fetchComments(logID: logID)
        return try responses.map(LogCommentResponseMapper.makeComment)
    }

    func createComment(
        logID: Int64,
        draft: LogCommentDraft
    ) async throws -> LogComment {
        let response = try await apiService.createComment(
            logID: logID,
            request: CreateLogCommentRequestDTO(
                content: draft.content,
                parentCommentID: draft.parentCommentID
            )
        )

        return try LogCommentResponseMapper.makeComment(from: response)
    }

    func updateComment(
        commentID: Int64,
        content: String
    ) async throws -> LogComment {
        let response = try await apiService.updateComment(
            commentID: commentID,
            request: UpdateLogCommentRequestDTO(content: content)
        )

        guard response.commentID == commentID else {
            throw APIError.invalidResponse
        }

        return try LogCommentResponseMapper.makeComment(from: response)
    }

    func deleteComment(
        commentID: Int64
    ) async throws {
        try await apiService.deleteComment(commentID: commentID)
    }

    func setLike(
        commentID: Int64,
        isLiked: Bool
    ) async throws -> LogCommentLikeState {
        let response = try await apiService.setLike(
            commentID: commentID,
            isLiked: isLiked
        )

        guard response.commentID == commentID else {
            throw APIError.invalidResponse
        }

        return LogCommentLikeState(
            commentID: response.commentID,
            isLiked: response.liked
        )
    }
}

private enum LogCommentResponseMapper {
    static func makeComment(
        from dto: LogCommentResponseDTO
    ) throws -> LogComment {
        LogComment(
            id: dto.commentID,
            author: LogCommentAuthor(
                id: dto.author.userID,
                nickname: dto.author.nickname,
                profileImageURL: makeURL(from: dto.author.profileImageURL)
            ),
            parentCommentID: normalizedParentID(dto.parentCommentID),
            content: dto.content,
            isDeleted: dto.deleted,
            createdAt: try date(from: dto.createdAt),
            updatedAt: try date(from: dto.updatedAt),
            likeCount: dto.likeCount,
            isLikedByViewer: dto.likedByViewer
        )
    }

    private static func normalizedParentID(
        _ parentCommentID: Int64?
    ) -> Int64? {
        guard let parentCommentID,
              parentCommentID > 0
        else {
            return nil
        }

        return parentCommentID
    }

    private static func makeURL(
        from value: String?
    ) -> URL? {
        guard let value = normalizedText(value) else {
            return nil
        }

        if let absoluteURL = URL(string: value),
           absoluteURL.scheme != nil {
            return absoluteURL
        }

        return URL(
            string: value,
            relativeTo: APIConfiguration.baseURL
        )?.absoluteURL
    }

    private static func normalizedText(
        _ value: String?
    ) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private static func date(
        from value: String
    ) throws -> Date {
        if let date = fractionalISO8601Formatter.date(from: value) {
            return date
        }

        if let date = ISO8601DateFormatter().date(from: value) {
            return date
        }

        if let date = localDateTimeFormatter.date(from: value) {
            return date
        }

        throw LogCommentRepositoryError.invalidDate(value: value)
    }

    private static let fractionalISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        return formatter
    }()

    private static let localDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return formatter
    }()
}

enum LogCommentRepositoryError: Error, Equatable {
    case invalidDate(value: String)
}
