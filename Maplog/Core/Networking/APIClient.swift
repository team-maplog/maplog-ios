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
        let networkResult: (Data, URLResponse)

        do {
            networkResult = try await URLSession.shared.data(for: urlRequest)
        } catch {
            throw APIError.network(error) // 네트워크 자체 실패
        }

        let data = networkResult.0
        let urlResponse = networkResult.1

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw APIError.invalidResponse // HTTP 응답이 아닐 때
        }

        //성공했을 시에 data -> responseType에 맞춰 디코딩 -> return
        guard (200..<300).contains(httpResponse.statusCode) else {
            do {
                let errorResponse = try JSONDecoder().decode(
                    APIErrorResponse.self,
                    from: data
                )

                throw APIError.server(
                    statusCode: httpResponse.statusCode,
                    response: errorResponse
                )
            } catch let error as APIError {
                throw error
            } catch {
                throw APIError.decoding(error)
            }
        }

        return data
    }
}
