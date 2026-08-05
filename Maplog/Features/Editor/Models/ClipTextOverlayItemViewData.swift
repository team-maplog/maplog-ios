//
//  ClipTextOverlayItemViewData.swift
//  Maplog
//
//  Created by 한채림 on 8/3/26.
// 자막 목록용 ViewData

import Foundation

struct ClipTextOverlayItemViewData: Identifiable, Equatable {
    let id: UUID
    let text: String
    let displayTimeText: String
    let position: ClipOverlayPosition
    let style: ClipTextStyle
}

//ClipTextOverlay
//→ clipID, text, startTime, endTime
//→ 실제 편집·내보내기용 Model
//
//ClipTextOverlayItemViewData
//→ text, "0.0초 ~ 2.0초"
//→ 화면 표시용 데이터
