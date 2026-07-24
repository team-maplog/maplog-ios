//
//  AuthToken.swift
//  Maplog
//
//  Created by 한채림 on 7/24/26.
// 서버 DTO가 아니라 앱 내부의 Domain Model

import Foundation

struct AuthToken: Equatable {
    let accessToken: String
    let refreshToken: String
}
