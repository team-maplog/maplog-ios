//
//  LogComposeClipLocationDraft.swift
//  Maplog
//
//  Created by 한채림 on 8/9/26.
// 클립별 장소의 기본 데이터
// CaptureDraftClip에 실제 촬영 시 저장된 location을 기본값으로 사용

import Foundation

struct LogComposeClipLocationDraft: Identifiable, Equatable, Hashable, Sendable {
    let clipID: UUID
    let videoURL: URL
    let startTime: TimeInterval // 합쳐진 최종 영상 기준의 시간 범위
    let endTime: TimeInterval // 합쳐진 최종 영상 기준의 시간 범위
    var location: LogLocationDraft? // 사용자가 지도에서 새 위치를 고르면 나중에 바뀔 값

    var id: UUID {
        clipID
    }
}
