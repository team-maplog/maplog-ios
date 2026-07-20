//
//  AuthService.swift
//  Maplog
//
//  Created by 한채림 on 7/18/26.
//

//1. Base URL에 회원가입 경로를 붙인다
//2. URLRequest를 만든다
//3. POST 메서드를 설정한다
//4. JSON 요청/응답 헤더를 설정한다
//5. SignupRequest를 JSON Data로 인코딩해 httpBody에 넣는다
//6. APIClient에 전송을 맡긴다
//7. 성공 응답을 반환한다


import Foundation

final class AuthService {
    private let apiClient: APIClient // AuthService가 사용할 공용 통신 엔진
    
    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }
    
    func signUp(request: SignupRequest) async throws -> SignupResponseData {
        // 회원가입 URL 만들기
        let url = APIConfiguration.baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("v1")
            .appendingPathComponent("auth")
            .appendingPathComponent("signup")
        
        // URLRequest 만들기
        var urlRequest = URLRequest(url: url)
        
        // POST 메서드 설정
        urlRequest.httpMethod = "POST"
        
        // JSON 헤더 설정
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // SignupRequest를 JSON 본문으로 넣기
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        // APIClient 호출 후 성공 응답 반환
        let response: APIResponse<SignupResponseData> =
        try await apiClient.request(urlRequest, responseType: APIResponse<SignupResponseData>.self)
        
        guard response.successFlag else {
            throw APIError.unexpectedResponse(code: response.code, message: response.message)
        }
        
        guard response.code == "SUCCESS-005" else {
            throw APIError.unexpectedResponse(code: response.code, message: response.message)
        }
        
        guard let signupData = response.data else {
            throw APIError.missingData
        }
        
        return signupData
    }
}



