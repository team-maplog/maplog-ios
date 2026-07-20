//
//  APIError.swift
//  Maplog
//
//  Created by 한채림 on 7/21/26.
//

// iOS 앱 안에서 요청이 왜 실패했는지 표현
// - 네트워크 계층과 API 계약에서 발생하는 공용 오류

enum APIError: Error {
    case invalidResponse
    case server(statusCode: Int, response: APIErrorResponse)
    case network(Error)
    case decoding(Error)
    case unexpectedResponse(code: String, message: String) // Http는 성공인데, successFlag가 false이거나, 회원가입인데 다른 성공 코드가 온 이상한 응답
    case missingData // 회원가입 성공이라고 했는데 data가 nil인 응답
}
