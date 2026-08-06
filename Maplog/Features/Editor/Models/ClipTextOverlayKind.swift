//
//  ClipTextOverlayKind.swift
//  Maplog
//
//  Created by 한채림 on 8/6/26.
// 일반 자막과 위치·시간 자막을 구분하는 모델

import Foundation

enum ClipTextOverlayKind: Equatable, Sendable {
    case userText
    case locationTimestamp(
        template: ClipLocationTimestampTemplate
    )
}
//    .userText
//    → “오늘의 해운대”처럼 직접 입력한 자막
//
//    .locationTimestamp(template: .inline)
//    → 촬영 정보로 자동 생성했고,
//      현재 inline 템플릿을 쓰는 위치·시간 자막
