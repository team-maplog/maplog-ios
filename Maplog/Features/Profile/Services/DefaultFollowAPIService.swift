import Foundation

final class DefaultFollowAPIService: FollowAPIService {
    private let authenticatedAPIClient: AuthenticatedAPIClient

    init(
        authenticatedAPIClient: AuthenticatedAPIClient
    ) {
        self.authenticatedAPIClient = authenticatedAPIClient
    }

    func fetchUsers(
        kind: FollowListKind,
        cursor: String?,
        size: Int
    ) async throws -> FollowUserPageDTO {
        guard (1...100).contains(size) else {
            throw APIError.invalidRequest(
                reason: "팔로우 목록 크기는 1부터 100 사이여야 합니다."
            )
        }

        var components = URLComponents(
            url: listEndpoint(for: kind),
            resolvingAgainstBaseURL: false
        )
        var queryItems = [
            URLQueryItem(name: "size", value: String(size))
        ]

        if let cursor,
           !cursor.isEmpty {
            queryItems.append(
                URLQueryItem(name: "cursor", value: cursor)
            )
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let response: APIResponse<FollowUserPageDTO> =
            try await authenticatedAPIClient.request(
                request,
                responseType: APIResponse<FollowUserPageDTO>.self
            )

        return try data(
            from: response,
            expectedCode: "SUCCESS-002"
        )
    }

    func setFollowing(
        userID: UUID,
        isFollowing: Bool
    ) async throws -> FollowStateResponseDTO {
        var request = URLRequest(url: userEndpoint(userID: userID))
        request.httpMethod = isFollowing ? "PUT" : "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let response: APIResponse<FollowStateResponseDTO> =
            try await authenticatedAPIClient.request(
                request,
                responseType: APIResponse<FollowStateResponseDTO>.self
            )

        // Swagger에는 각 변경 요청의 application code가 명시되지 않았으므로
        // 공통 계약인 successFlag와 SUCCESS 계열 code를 함께 검증합니다.
        return try data(from: response, expectedCode: nil)
    }

    private func listEndpoint(
        for kind: FollowListKind
    ) -> URL {
        APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("follows")
            .appendingPathComponent(
                kind == .followers ? "followers" : "following"
            )
    }

    private func userEndpoint(
        userID: UUID
    ) -> URL {
        APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("follows")
            .appendingPathComponent(userID.uuidString)
    }

    private func data<Payload>(
        from response: APIResponse<Payload>,
        expectedCode: String?
    ) throws -> Payload {
        guard response.successFlag else {
            throw APIError.unexpectedResponse(
                code: response.code,
                message: response.message
            )
        }

        if let expectedCode {
            guard response.code == expectedCode else {
                throw APIError.unexpectedResponse(
                    code: response.code,
                    message: response.message
                )
            }
        } else {
            guard response.code.hasPrefix("SUCCESS-") else {
                throw APIError.unexpectedResponse(
                    code: response.code,
                    message: response.message
                )
            }
        }

        guard let data = response.data else {
            throw APIError.missingData
        }

        return data
    }
}
