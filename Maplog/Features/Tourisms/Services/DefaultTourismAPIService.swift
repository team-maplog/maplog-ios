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
    private let accessTokenProvider: any AccessTokenProviding // Service는 AuthSessionStore라는 구체적인 클래스를 모름,
//    DefaultTourismAPIService가 아는 것
//    → access token을 제공할 수 있는 객체가 있다
//
//    DefaultTourismAPIService가 모르는 것
//    → Keychain에 어떻게 저장하는지
//    → 로그인 화면 상태가 어떤지
//    → AuthSessionStore라는 실제 클래스인지
//    그래서 AuthSessionStore가 아니라 any AccessTokenProviding을 받음

    init(apiClient: APIClient,
         accessTokenProvider: any AccessTokenProviding
    ) {
        self.apiClient = apiClient
        self.accessTokenProvider = accessTokenProvider
    }

    func fetchTourisms(
        category: TourismCategory,
        cursor: String?,
        size: Int
    ) async throws -> TourismPageDTO {
        guard (1...100).contains(size) else {
            throw APIError.invalidRequest(reason: "size는 1부터 100 사이여야 합니다.")
        }

        // await가 필요한 이유는 AccessTokenProviding이 @MainActor이고, 현재 Service는 Main Actor 밖에 있기 때문, 메인 액터가 관리하는 AuthSessionStore에게 안전하게 token을 물어봄
        let accessToken = try await accessTokenProvider.currentAccessToken()

        guard let accessToken, !accessToken.isEmpty else {
            throw APIError.missingAccessToken
        }


        let endpoint = APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("tourisms")
        //url을 조각으로 나눠서 안전하게 수정하는 도구
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)

        var queryItems = [
            URLQueryItem(name: "category", value: category.rawValue), // category.rawValue는 Swift enum을 백엔드 문자열로 바꿔줌
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

        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

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

    func fetchTourismDetail(tourismID: Int64) async throws -> TourismDetailDTO {
        guard tourismID > 0 else {
            throw APIError.invalidRequest(reason: "tourismID는 1 이상의 정수여야 합니다.")
        }

        let accessToken = try await accessTokenProvider.currentAccessToken()

        guard let accessToken, !accessToken.isEmpty else {
            throw APIError.missingAccessToken
        }

        let endpoint = APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("tourisms")
            .appendingPathComponent(String(tourismID))

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.setValue(
                "Bearer \(accessToken)",
                forHTTPHeaderField: "Authorization"
            )

        let response: APIResponse<TourismDetailDTO> = try await apiClient.request(urlRequest, responseType: APIResponse<TourismDetailDTO>.self)

        guard response.successFlag else {
            throw APIError.unexpectedResponse(code: response.code, message: response.message)
        }

        guard response.code == "SUCCESS-002" else {
                throw APIError.unexpectedResponse(
                    code: response.code,
                    message: response.message
                )
            }

        guard let tourismDetailDTO = response.data else {
            throw APIError.missingData
        }

        return tourismDetailDTO
    }
}
