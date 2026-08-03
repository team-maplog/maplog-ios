//
//  ClipPickerItemViewData.swift
//  Maplog
//
//  Created by 한채림 on 8/1/26.
// 화면 전용 데이터

import Foundation

struct ClipPickerItemViewData: Identifiable, Equatable {
    let id: UUID
    var thumbnailData: Data?
    let capturedAtText: String
    let durationText: String
}
