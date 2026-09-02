//
//  DefaultLogPublishingAPIService.swift
//  Maplog
//
//  Created by 한채림 on 8/13/26.
//

import Foundation
import UniformTypeIdentifiers

final class DefaultLogPublishingAPIService: LogPublishingAPIService {
    private let authenticatedAPIClient: AuthenticatedAPIClient

    init(
        authenticatedAPIClient: AuthenticatedAPIClient
    ) {
        self.authenticatedAPIClient = authenticatedAPIClient
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
        urlRequest.httpBody = try makeMultipartBody(
            fileURL: fileURL,
            boundary: boundary
        )

        let response: APIResponse<LogVideoUploadResponseDTO> =
            try await authenticatedAPIClient.request(
                urlRequest,
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

    private func makeMultipartBody( // 영상 데이터를 file이라는 이름의 multipart 형식으로 포장함
            fileURL: URL,
            boundary: String
        ) throws -> Data {
            let fileData = try Data(contentsOf: fileURL)
            let mimeType = mimeType(for: fileURL)

            var body = Data()

            body.append("--\(boundary)\r\n")
            body.append(
                """
                Content-Disposition: form-data; name="file"; filename="\(fileURL.lastPathComponent)"\r\n
                """
            )
            body.append("Content-Type: \(mimeType)\r\n\r\n")
            body.append(fileData)
            body.append("\r\n")
            body.append("--\(boundary)--\r\n")

            return body
        }

        private func mimeType( // .mov라면 보통 video/quicktime을 자동으로 구함
            for fileURL: URL
        ) -> String {
            guard let type = UTType(
                filenameExtension: fileURL.pathExtension
            ),
            let mimeType = type.preferredMIMEType else {
                return "application/octet-stream"
            }

            return mimeType
        }
    }

    private extension Data {
        mutating func append(
            _ string: String
        ) {
            append(Data(string.utf8))
        }
    }
