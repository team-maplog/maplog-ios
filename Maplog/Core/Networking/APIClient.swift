//
//  APIClienttled.swift
//  Maplog
//
//  Created by 한채림 on 7/18/26.
//

import Foundation
// 어떤 URLRequest를 받더라도 전송하고 결과를 해석할 수 있는 공용 엔진
//- URLSession 요청
//- HTTP 상태 확인
//- 성공/실패 JSON 디코딩


final class APIClient {
    func request<Response: Decodable>(
        _ urlRequest: URLRequest,
        responseType: Response.Type
    ) async throws -> Response {

        let data = try await data(for: urlRequest)

        do {
            return try JSONDecoder().decode(
                responseType,
                from: data
            )
        } catch {
#if DEBUG
            print("❌ API decoding failed")
            print("url:", urlRequest.url?.absoluteString ?? "unknown")
            print("error:", error)
#endif

            throw APIError.decoding(error)
        }
    }

    func data(for urlRequest: URLRequest) async throws -> Data {
        let data: Data
        let urlResponse: URLResponse

        do {
            (data, urlResponse) = try await URLSession.shared.data(
                for: urlRequest
            )
        } catch {
            throw APIError.network(error)
        }

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw makeServerError(
                statusCode: httpResponse.statusCode,
                data: data
            )
        }

        return data
    }

    func download(for urlRequest: URLRequest) async throws -> URL {
        let temporaryURL: URL
        let urlResponse: URLResponse

        do {
            (temporaryURL, urlResponse) = try await URLSession.shared.download(
                for: urlRequest
            )
        } catch {
            throw APIError.network(error)
        }

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            guard let errorData = try? Data(contentsOf: temporaryURL) else {
                throw APIError.invalidResponse
            }

            throw makeServerError(
                statusCode: httpResponse.statusCode,
                data: errorData
            )
        }

        return temporaryURL
    }

    private func makeServerError(
        statusCode: Int,
        data: Data
    ) -> APIError {
        do {
            let errorResponse = try JSONDecoder().decode(
                APIErrorResponse.self,
                from: data
            )

            return .server(
                statusCode: statusCode,
                response: errorResponse
            )
        } catch {
            return .decoding(error)
        }
    }
}
