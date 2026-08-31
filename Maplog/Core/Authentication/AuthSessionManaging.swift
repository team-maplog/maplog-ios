//
//  AuthSessionManaging.swift
//  Maplog
//
//  Created by 한채림 on 7/28/26.
// 현재 로그인 세션을 다룰 수 있는 역할

import Foundation

@MainActor
protocol AuthSessionManaging:
        AnyObject,
        AccessTokenProviding,
        RefreshTokenProviding {

        func startSession(with token: AuthToken) throws
        func replaceTokens(with token: AuthToken) throws
        func endSession() throws
}

//currentAccessToken(): 보호 API 요청용
//currentRefreshToken(): 재발급 API 요청용
//replaceTokens(with:): 재발급 성공 후 토큰 회전
//endSession(): 복구 불가능한 인증 오류 처리
