//
//  DefaultLogPublishingAPIService.swift
//  Maplog
//
//  Created by 한채림 on 8/13/26.
//

import Foundation

final class DefaultLogPublishingAPIService: LogPublishingAPIService {
    private let authenticatedAPIClient: AuthenticatedAPIClient
    private let uploadFileBuilder: any LogVideoUploadFileBuilding

    init(
        authenticatedAPIClient: AuthenticatedAPIClient,
        uploadFileBuilder: any LogVideoUploadFileBuilding
    ) {
        self.authenticatedAPIClient = authenticatedAPIClient
        self.uploadFileBuilder = uploadFileBuilder
    }

    func uploadLogVideo( // .mov 파일을 multipart 형식으로 서버에 전달하고 fileId를 받음
        fileURL: URL
    ) async throws -> LogVideoUploadResponseDTO {
        guard FileManager.default.fileExists(
            atPath: fileURL.path
        ) else {
            throw APIError.invalidRequest(
                reason: "업로드할 영상 파일을 찾을 수 없습니다."
            )
        }

        let endpoint = APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("files")

        var components = URLComponents(
            url: endpoint,
            resolvingAgainstBaseURL: false
        )

        components?.queryItems = [
            URLQueryItem(
                name: "purpose",
                value: "LOG_VIDEO"
            )
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )
        urlRequest.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        let bodyURL = try await uploadFileBuilder.makeMultipartFile(from: fileURL, boundary: boundary)
        // 인증 재시도가 끝날 때까지 같은 본문 파일을 유지한다.
        defer { try? FileManager.default.removeItem(at: bodyURL) }
        try Task.checkCancellation()

        let response: APIResponse<LogVideoUploadResponseDTO> =
            try await authenticatedAPIClient.upload(
                urlRequest,
                fromFile: bodyURL,
                responseType: APIResponse<LogVideoUploadResponseDTO>.self
            )

        guard response.successFlag else {
            throw APIError.unexpectedResponse(
                code: response.code,
                message: response.message
            )
        }

        guard let uploadDTO = response.data else {
            throw APIError.missingData
        }

        return uploadDTO
    }

    func createLog( // fileId와 로그 메타데이터를 JSON으로 전송함
        request: LogCreateRequestDTO,
        idempotencyKey: String
    ) async throws -> LogCreateResponseDTO {
        let endpoint = APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("logs")

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        // 같은 발행 시도의 자동·사용자 재시도에는 반드시 같은 UUID를 사용합니다.
        urlRequest.setValue(
            idempotencyKey,
            forHTTPHeaderField: "Idempotency-Key"
        )
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let response: APIResponse<LogCreateResponseDTO> =
            try await authenticatedAPIClient.request(
                urlRequest,
                responseType: APIResponse<LogCreateResponseDTO>.self
            )

        guard response.successFlag else {
            throw APIError.unexpectedResponse(
                code: response.code,
                message: response.message
            )
        }

        // SUCCESS-008은 같은 Idempotency-Key의 이전 성공 결과를 다시 준 응답입니다.
        guard ["SUCCESS-001", "SUCCESS-008"].contains(response.code) else {
            throw APIError.unexpectedResponse(
                code: response.code,
                message: response.message
            )
        }

        guard let logDTO = response.data else {
            throw APIError.missingData
        }

        return logDTO
    }

}
