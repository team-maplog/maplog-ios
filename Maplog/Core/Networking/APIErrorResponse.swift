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
    let message: String
}
