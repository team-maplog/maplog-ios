//
//  AuthSessionStore.swift
//  Maplog
//
//  Created by 한채림 on 7/18/26.
//

//→ “현재 로그인됐는가?”를 앱 전체에 알림
//→ 토큰 두 개를 함께 저장·삭제
//→ 앱 시작 시 저장된 토큰 존재 여부 확인

import Combine
import Foundation

@MainActor // ui 상태 변경을 메인 스레드에서 안전하게 함
final class AuthSessionStore: ObservableObject, AccessTokenProviding { // AuthSessionStore는 AccessTokenProviding 역할을 수행할 수 있음
    @Published private(set) var isAuthenticated = false
    
    private enum TokenKey {
        static let accessToken = "maplog.accessToken"
        static let refreshToken = "maplog.refreshToken"
    }
    
    // 회원가입 로그인 성공 시 세션 시작
    func startSession(with token: TokenResponse) throws {
        
        try KeychainService.save(token.accessToken, for: TokenKey.accessToken)
        do {
            try KeychainService.save(token.refreshToken, for: TokenKey.refreshToken)
        }catch { // access token만 저장되고 refresh token 저장에는 실패한 반쪽 세션을 정리하는 안전장치
            try? KeychainService.delete(for: TokenKey.accessToken)
            try? KeychainService.delete(for: TokenKey.refreshToken)
            
            isAuthenticated = false
            throw error
        }
        
        isAuthenticated = true
    }
    
    // 앱 실행 시 기존 세션 복구
    func restoreSession() throws {
        let refreshToken = try KeychainService.read(for: TokenKey.refreshToken)
        
        isAuthenticated = refreshToken != nil
    }
    
    // 로그아웃 토큰 무효시 세션 종료
    func endSession() throws {
        try KeychainService.delete(for: TokenKey.accessToken)
        
        try KeychainService.delete(for: TokenKey.refreshToken)
        
        isAuthenticated = false
    }
    
    // 나중에 Authorization 헤더에 쓸 access token 조회
    func currentAccessToken() throws -> String? {
        try KeychainService.read(for: TokenKey.accessToken)
    }
}

