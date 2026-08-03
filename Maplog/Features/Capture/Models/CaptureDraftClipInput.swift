//
//  CaptureDraftClipInput.swift
//  Maplog
//
//  Created by 한채림 on 7/30/26.
//

//카메라 서비스의 임시 .mov
//   → CaptureDraftClipInput
//   → MediaDraftRepository가 앱 내부 폴더로 복사
//   → CaptureDraftClip 반환

import Foundation

struct CaptureDraftClipInput: Equatable, Sendable {
    let temporaryFileURL: URL // 카메라가 막 녹화를 끝낸 직후 제공하는 임시 .mov 경로
    let mediaType: CaptureMediaType
    let capturedAt: Date
    let duration: TimeInterval?
    let location: CaptureLocation?
    let timestampStyle: CaptureTimestampStyle
}
