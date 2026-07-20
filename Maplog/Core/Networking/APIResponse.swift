//
//  APIResponse.swift
//  Maplog
//
//  Created by 한채림 on 7/21/26.
//

import Foundation
//- 모든 성공/일반 응답의 바깥 형식

struct APIResponse<Payload: Decodable>: Decodable {
    let successFlag: Bool
    let code: String
    let message: String
    let data: Payload?
}
