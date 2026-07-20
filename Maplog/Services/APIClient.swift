//
//  APIClienttled.swift
//  Maplog
//
//  Created by 한채림 on 7/18/26.
//

import Foundation

// iOS 앱 안에서 요청이 왜 실패했는지 표현
enum APIError: Error {
    case invalidResponse
    case server(statusCode: Int, response: APIErrorResponse)
    case network(Error)
    case decoding(Error)
    case unexpectedResponse(code: String, message: String) // Http는 성공인데, successFlag가 false이거나, 회원가입인데 다른 성공 코드가 온 이상한 응답
    case missingData // 회원가입 성공이라고 했는데 data가 nil인 응답
}

    // 어떤 URLRequest를 받더라도 전송하고 결과를 해석할 수 있는 공용 엔진

final class APIClient {
    func request<Response: Decodable>(
        _ urlRequest: URLRequest,
        responseType: Response.Type
    ) async throws -> Response {
//        let (data, urlResponse) = try await URLSession.shared.data(for: urlRequest)
        
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
        
        let decoder = JSONDecoder()
        
        //성공했을 시에 data -> responseType에 맞춰 디코딩 -> return
        if (200..<300).contains(httpResponse.statusCode) {
            do {
                return try decoder.decode(responseType, from: data)
            } catch {
                throw APIError.decoding(error) // 2xx 성공 응답인데 JSON 모양이 다를 때
            }
        }
        
        let errorResponse: APIErrorResponse
        
        // 실패했을 시에 data -> APIErrorResponse로 디코딩 -> APIError.server throw (오류값 전달하고 APIClient 함수 즉시 종료
        do {
            errorResponse = try decoder.decode(APIErrorResponse.self, from: data)
        } catch {
            throw APIError.decoding(error) // 4xx/5xx 실패 응답일 때
        }
        
        throw APIError.server(statusCode: httpResponse.statusCode, response: errorResponse)
        
        
    }
}
