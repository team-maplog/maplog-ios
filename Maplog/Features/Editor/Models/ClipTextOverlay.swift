//
//  ClipTextOverlay.swift
//  Maplog
//
//  Created by 한채림 on 8/3/26.
// 클립별 자막 모델
// 위치·글꼴·색상 같은 저장할 편집 정보

import Foundation

struct ClipTextOverlay: Identifiable, Equatable, Sendable {
    let id: UUID
    let clipID: UUID
    var text: String
    var startTime: TimeInterval
    var endTime: TimeInterval

    init(
        id: UUID = UUID(),
        clipID: UUID,
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval
    ) {
        let safeStartTime = max(0, startTime)

        self.id = id
        self.clipID = clipID
        self.text = text
        self.startTime = safeStartTime
        self.endTime = max(safeStartTime, endTime)
    }
}

//ClipTextOverlay.id
//→ 자막 자체를 수정·삭제할 때 사용
//
//ClipTextOverlay.clipID
//→ 이 자막을 어느 영상 위에 그릴지 찾을 때 사용
//
//startTime / endTime
//→ 그 영상 안에서 언제 보일지 결정
