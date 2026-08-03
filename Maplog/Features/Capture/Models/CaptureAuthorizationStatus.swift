//
//  CaptureAuthorizationStatus.swift
//  Maplog
//
//  Created by 한채림 on 7/31/26.
// 카메라와 마이크 권한의 현재 상태를 앱이 이해할 수 있는 형태로 표현

import Foundation

enum CaptureAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}
