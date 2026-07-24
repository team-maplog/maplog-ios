//
//  APIErrorResponse.swift
//  Maplog
//
//  Created by 한채림 on 7/21/26.
//

import Foundation

struct APIErrorResponse: Decodable {
    let successFlag: Bool
    let code: String
    let message: String
    let data: [FieldValidationError]?
}

struct FieldValidationError: Decodable {
    let field: String
    let rejectedValue: String? // 서버가 COMMON-014 입력 검증 오류에서 줄 수 있는 값
    let message: String
}
