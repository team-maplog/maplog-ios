//
//  SignInCredentials.swift
//  Maplog
//
//  Created by 한채림 on 7/24/26.
// 화면에서 입력받은 로그인 정보를 Repository에 전달하기 위한 앱 내부 모델

//SignInRequestDTO와 비슷해 보여도 역할이 달라.
//SignInCredentials: ViewModel ↔ Repository 사이에서 사용
//SignInRequestDTO: Repository ↔ API Service 사이에서 사용

import Foundation

struct SignInCredentials {
    let email: String
    let password: String
}
