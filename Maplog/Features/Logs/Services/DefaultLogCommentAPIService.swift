import Foundation

final class DefaultLogCommentAPIService: LogCommentAPIService {
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

        let response: APIResponse<String> =
            try await authenticatedAPIClient.request(
                request,
                responseType: APIResponse<String>.self
            )

        _ = try validatedData(from: response)
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

        guard let data = response.data else {
            throw APIError.missingData
        }

        return data
    }
}
