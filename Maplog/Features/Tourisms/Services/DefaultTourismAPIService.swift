//
//  DefaultTourismAPIService.swift
//  Maplog
//
//  Created by 한채림 on 7/21/26.
//

//- URLComponents로 URL 생성
//- GET /api/v1/tourisms 요청
//- APIClient 호출
//- successFlag / SUCCESS-002 확인
//- TourismPageDTO 반환

//첫 요청
//cursor = nil
//→ ?size=10
//
//다음 페이지 요청
//cursor = "Mg"
//→ ?size=10&cursor=Mg

import Foundation

final class DefaultTourismAPIService: TourismAPIService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchTourisms(
        cursor: String?,
        size: Int
    ) async throws -> TourismPageDTO {
        guard (1...100).contains(size) else {
            throw APIError.invalidRequest(reason: "size는 1부터 100 사이여야 합니다.")
        }
        
        
        let endpoint = APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("tourisms")
        //url을 조각으로 나눠서 안전하게 수정하는 도구
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        
        var queryItems = [
            URLQueryItem(name: "size", value: String(size))
        ]
        
        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        
        urlRequest.httpMethod = "GET"
        
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let response: APIResponse<TourismPageDTO> = try await apiClient.request(urlRequest, responseType: APIResponse<TourismPageDTO>.self)
        
        guard response.successFlag else {
            throw APIError.unexpectedResponse(code: response.code, message: response.message)
        }
        
        guard response.code == "SUCCESS-002" else {
            throw APIError.unexpectedResponse(code: response.code, message: response.message)
        }
        
        guard let tourismPageDTO = response.data else {
            throw APIError.missingData
        }
        
        return tourismPageDTO
    }
}
