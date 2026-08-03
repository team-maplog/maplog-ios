//
//  CaptureDraftClip.swift
//  Maplog
//
//  Created by 한채림 on 7/30/26.
// 임시 저장 클립 모델

import Foundation

struct CaptureDraftClip: Identifiable, Equatable, Sendable {
    let id: UUID
    let mediaType: CaptureMediaType
    let fileURL: URL // 앱이 관리하는 영구 초안 파일 경로
    let capturedAt: Date
    let duration: TimeInterval?
    let location: CaptureLocation?
    let timestampStyle: CaptureTimestampStyle
}

enum CaptureMediaType: String, Equatable, Sendable {
    case video
    case photo
}
