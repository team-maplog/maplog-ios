//
//  AuthModels.swift
//  Maplog
//
//  Created by 한채림 on 7/18/26.
//

import Foundation

struct APIResponse<Payload: Decodable>: Decodable {
    let successFlag: Bool
    let code: String
    let message: String
    let data: Payload?
}


// 만들어진 요청 본문이기 때문에(가입 버튼 누른 순간의 입력값 묶음) 그래서 let 사용
struct SignupRequest: Encodable {
    let email: String
    let password: String
    let passwordConfirmation: String
    let nickname: String
    let termsAreed: Bool
    let privacyPolicyAgreed: Bool
}

// 회원가입 성공 data
struct SignupResponseData: Decodable {
    let userId: Int
    let email: String
    let name: String
    let token: TokenResponse
}

struct TokenResponse: Decodable {
    let grantType: String
    let accessToken: String
    let refreshToken: String
}

struct APIErrorResponse: Decodable {
    let successFlag: Bool
    let code: String
    let message: String
    let data: [FieldValidationError]?
}

struct FieldValidationError: Decodable {
    let field: String
    let message: String
}
