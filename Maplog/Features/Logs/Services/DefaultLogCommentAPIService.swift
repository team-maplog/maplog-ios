import Foundation

final class DefaultLogCommentAPIService: LogCommentAPIService {
    /// 삭제 성공 응답은 `data: null`이므로, 본문 값을 요구하지 않는 전용 payload다.
    private struct EmptyPayload: Decodable {}

    private let authenticatedAPIClient: AuthenticatedAPIClient

    init(
        authenticatedAPIClient: AuthenticatedAPIClient
    ) {
        self.authenticatedAPIClient = authenticatedAPIClient
    }

    func fetchComments(
        logID: Int64
    ) async throws -> [LogCommentResponseDTO] {
        var request = URLRequest(url: try logCommentsEndpoint(logID: logID))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let response: APIResponse<[LogCommentResponseDTO]> =
            try await authenticatedAPIClient.request(
                request,
                responseType: APIResponse<[LogCommentResponseDTO]>.self
            )

        return try validatedData(from: response)
    }

    func createComment(
        logID: Int64,
        request: CreateLogCommentRequestDTO
    ) async throws -> LogCommentResponseDTO {
        var urlRequest = URLRequest(url: try logCommentsEndpoint(logID: logID))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let response: APIResponse<LogCommentResponseDTO> =
            try await authenticatedAPIClient.request(
                urlRequest,
                responseType: APIResponse<LogCommentResponseDTO>.self
            )

        return try validatedData(from: response)
    }

    func updateComment(
        commentID: Int64,
        request: UpdateLogCommentRequestDTO
    ) async throws -> LogCommentResponseDTO {
        var urlRequest = URLRequest(
            url: try commentEndpoint(commentID: commentID)
        )
        urlRequest.httpMethod = "PATCH"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let response: APIResponse<LogCommentResponseDTO> =
            try await authenticatedAPIClient.request(
                urlRequest,
                responseType: APIResponse<LogCommentResponseDTO>.self
            )

        return try validatedData(from: response)
    }

    func deleteComment(
        commentID: Int64
    ) async throws {
        var request = URLRequest(url: try commentEndpoint(commentID: commentID))
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let response: APIResponse<EmptyPayload> =
            try await authenticatedAPIClient.request(
                request,
                responseType: APIResponse<EmptyPayload>.self
            )

        try validateSuccess(response)
    }

    func setLike(
        commentID: Int64,
        isLiked: Bool
    ) async throws -> LogCommentLikeStateResponseDTO {
        var request = URLRequest(
            url: try commentLikeEndpoint(commentID: commentID)
        )
        request.httpMethod = isLiked ? "PUT" : "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let response: APIResponse<LogCommentLikeStateResponseDTO> =
            try await authenticatedAPIClient.request(
                request,
                responseType: APIResponse<LogCommentLikeStateResponseDTO>.self
            )

        return try validatedData(from: response)
    }

    func reportContent(request: ContentReportRequestDTO) async throws -> CommentReportReceiptDTO {
        var urlRequest = URLRequest(url: APIConfiguration.baseURL.appendingPathComponent("api/v1/reports"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        let response = try await authenticatedAPIClient.request(
            urlRequest, responseType: APIResponse<CommentReportReceiptDTO>.self
        )
        guard response.successFlag, response.code == "SUCCESS-001" else {
            throw APIError.unexpectedResponse(code: response.code, message: response.message)
        }
        guard let receipt = response.data else { throw APIError.missingData }
        return receipt
    }

    func blockAuthor(userID: UUID) async throws -> CommentAuthorBlockStateDTO {
        var request = URLRequest(url: APIConfiguration.baseURL
            .appendingPathComponent("api/v1/blocks")
            .appendingPathComponent(userID.uuidString))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let response = try await authenticatedAPIClient.request(
            request, responseType: APIResponse<CommentAuthorBlockStateDTO>.self
        )
        guard response.successFlag, response.code == "SUCCESS-003" else {
            throw APIError.unexpectedResponse(code: response.code, message: response.message)
        }
        guard let result = response.data else { throw APIError.missingData }
        return result
    }

    private func logCommentsEndpoint(
        logID: Int64
    ) throws -> URL {
        guard logID > 0 else {
            throw APIError.invalidRequest(
                reason: "로그 식별자가 올바르지 않습니다."
            )
        }

        return APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("logs")
            .appendingPathComponent(String(logID))
            .appendingPathComponent("comments")
    }

    private func commentEndpoint(
        commentID: Int64
    ) throws -> URL {
        try commentBaseEndpoint(commentID: commentID)
    }

    private func commentLikeEndpoint(
        commentID: Int64
    ) throws -> URL {
        try commentBaseEndpoint(commentID: commentID)
            .appendingPathComponent("likes")
    }

    private func commentBaseEndpoint(
        commentID: Int64
    ) throws -> URL {
        guard commentID > 0 else {
            throw APIError.invalidRequest(
                reason: "댓글 식별자가 올바르지 않습니다."
            )
        }

        return APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("comments")
            .appendingPathComponent(String(commentID))
    }

    private func validatedData<Payload: Decodable>(
        from response: APIResponse<Payload>
    ) throws -> Payload {
        try validateSuccess(response)

        guard let data = response.data else {
            throw APIError.missingData
        }

        return data
    }

    /// 조회·생성처럼 본문이 필요한 요청과 달리, 삭제는 `data`가 비어도 성공으로 처리한다.
    private func validateSuccess<Payload: Decodable>(
        _ response: APIResponse<Payload>
    ) throws {
        // Swagger는 댓글 API의 HTTP 상태는 제공하지만 application code 예시는
        // "string"으로만 표시합니다. 공통 응답 규칙인 successFlag와 SUCCESS 계열
        // code를 함께 확인해 예상 밖의 성공 응답을 걸러냅니다.
        guard response.successFlag,
              response.code.hasPrefix("SUCCESS-")
        else {
            throw APIError.unexpectedResponse(
                code: response.code,
                message: response.message
            )
        }
    }
}
