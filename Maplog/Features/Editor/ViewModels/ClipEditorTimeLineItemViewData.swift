//
//  ClipEditorTimeLineItemViewData.swift
//  Maplog
//
//  Created by 한채림 on 8/2/26.
// 타임라인 화면용 데이터

//ClipPickerItemViewData
//→ “어떤 클립을 고를까?”
//
//ClipEditorTimelineItemViewData
//→ “선택한 클립을 어떤 순서로 편집할까?”


import Foundation

struct ClipEditorTimelineItemViewData: Identifiable, Equatable {
    let id: UUID
    var thumbnailData: Data?
    let durationText: String
}
