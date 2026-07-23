//
//  AccessTokenProviding.swift
//  Maplog
//
//  Created by 한채림 on 7/23/26.
// 토큰 제공 역할

import Foundation

// @MainActor를 붙인 이유는 현재 AuthSessionStore 자체가 @MainActor 클래스이기 때문. 나중에 Swift가 메인 액터에 있는 메서드를 다른 규칙의 protocol에 연결할 수 없다는 동시성 오류를 내지 않음
@MainActor
// access token을 제공할 수 있는 객체
protocol AccessTokenProviding: AnyObject { // 이 역할을 값 타입 struct가 아니라, 현재 세션처럼 하나만 공유하는 참조 타입 class가 맡는다는 뜻
    func currentAccessToken() throws -> String?
}
