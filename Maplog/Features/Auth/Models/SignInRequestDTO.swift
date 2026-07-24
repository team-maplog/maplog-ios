//
//  SignInRequestDTO.swift
//  Maplog
//
//  Created by 한채림 on 7/24/26.
//
//로그인 버튼
//→ SignInViewModel
//→ AuthRepository
//→ AuthAPIService
//→ APIClient
//→ 로그인 성공
//→ AuthSessionStore에 토큰 저장
//→ isAuthenticated = true
//→ RootView가 자동으로 다음 화면으로 이동


import Foundation

struct SignInRequestDTO: Encodable {
    let email: String
    let password: String
}
