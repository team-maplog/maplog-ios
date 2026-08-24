import Foundation

final class DefaultProfileAPIService: ProfileAPIService {
    private let authenticatedAPIClient: AuthenticatedAPIClient

    init(
        authenticatedAPIClient: AuthenticatedAPIClient
    ) {
        self.authenticatedAPIClient = authenticatedAPIClient
    }

    func fetchMyProfile() async throws -> MyProfileResponseDTO {
        let response: APIResponse<MyProfileResponseDTO> = try await request(
            url: myProfileEndpoint,
            responseType: APIResponse<MyProfileResponseDTO>.self
        )

        return try data(from: response)
    }

    func fetchMyLogs(
        cursor: String?,
        size: Int
    ) async throws -> ProfileLogPageDTO {
        guard (1...100).contains(size) else {
            throw APIError.invalidRequest(
                reason: "프로필 로그 목록 크기는 1부터 100 사이여야 합니다."
            )
        }

        let endpoint = APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("logs")
            .appendingPathComponent("me")

        var queryItems = [
            URLQueryItem(
                name: "size",
                value: String(size)
            )
        ]

        if let cursor {
            queryItems.append(
                URLQueryItem(
                    name: "cursor",
                    value: cursor
                )
            )
        }

        var components = URLComponents(
            url: endpoint,
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let response: APIResponse<ProfileLogPageDTO> = try await request(
            url: url,
            responseType: APIResponse<ProfileLogPageDTO>.self
        )

        return try data(from: response)
    }

    func updateMyProfile(
        request: UpdateMyProfileRequestDTO
    ) async throws -> MyProfileResponseDTO {
        var urlRequest = URLRequest(url: myProfileEndpoint)
        urlRequest.httpMethod = "PATCH"
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let response: APIResponse<MyProfileResponseDTO> =
            try await authenticatedAPIClient.request(
                urlRequest,
                responseType: APIResponse<MyProfileResponseDTO>.self
            )

        // Swagger는 PATCH 성공의 application code를 공개하지 않아
        // successFlag와 SUCCESS 계열 code를 함께 확인한다.
        return try data(
            from: response,
            expectedCode: nil
        )
    }

    func uploadProfileImage(
        imageData: Data
    ) async throws -> ProfileImageUploadResponseDTO {
        guard !imageData.isEmpty else {
            throw APIError.invalidRequest(
                reason: "업로드할 프로필 이미지를 찾을 수 없습니다."
            )
        }

        var components = URLComponents(
            url: filesEndpoint,
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(
                name: "purpose",
                value: "GENERIC"
            )
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let boundary = "ProfileImage-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = multipartImageBody(
            imageData: imageData,
            boundary: boundary
        )

        let response: APIResponse<ProfileImageUploadResponseDTO> =
            try await authenticatedAPIClient.request(
                request,
                responseType: APIResponse<ProfileImageUploadResponseDTO>.self
            )

        return try data(
            from: response,
            expectedCode: nil
        )
    }

    func deleteMyProfile() async throws {
        var request = URLRequest(url: myProfileEndpoint)
        request.httpMethod = "DELETE"
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let response: APIResponse<EmptyProfileResponseDTO> =
            try await authenticatedAPIClient.request(
                request,
                responseType: APIResponse<EmptyProfileResponseDTO>.self
            )

        try validateSuccess(
            response,
            expectedCode: nil
        )
    }

    func fetchImageData(
        from url: URL
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(
            "image/*",
            forHTTPHeaderField: "Accept"
        )

        return try await authenticatedAPIClient.data(
            for: request
        )
    }

    private func request<Response: Decodable>(
        url: URL,
        responseType: Response.Type
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        return try await authenticatedAPIClient.request(
            request,
            responseType: responseType
        )
    }

    private var myProfileEndpoint: URL {
        APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("users")
            .appendingPathComponent("me")
    }

    private var filesEndpoint: URL {
        APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("files")
    }

    private func data<Response>(
        from response: APIResponse<Response>,
        expectedCode: String? = "SUCCESS-002"
    ) throws -> Response {
        try validateSuccess(
            response,
            expectedCode: expectedCode
        )

        guard let data = response.data else {
            throw APIError.missingData
        }

        return data
    }

    private func validateSuccess<Response>(
        _ response: APIResponse<Response>,
        expectedCode: String?
    ) throws {
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
    }

    private func multipartImageBody(
        imageData: Data,
        boundary: String
    ) -> Data {
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(
            Data(
                "Content-Disposition: form-data; name=\"file\"; filename=\"profile.jpg\"\r\n".utf8
            )
        )
        body.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
        body.append(imageData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return body
    }
}

private struct EmptyProfileResponseDTO: Decodable {}
