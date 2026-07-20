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
#if DEBUG
                print("❌ API decoding failed")
                print("status:", httpResponse.statusCode)
                print("url:", urlRequest.url?.absoluteString ?? "unknown")
                print("error:", error)
#endif
                
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
