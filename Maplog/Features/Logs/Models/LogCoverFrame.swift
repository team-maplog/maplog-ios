//
//  LogCoverFrame.swift
//  Maplog
//
//  Created by 한채림 on 8/12/26.
// 프레임 한 칸 표현

import Foundation

struct LogCoverFrame: Identifiable, Equatable, Sendable {
    let time: TimeInterval // 이 프레임이 영상의 몇 초 인지
    var thumbnailData: Data? // 해당 시간에서 추출한 이미지

    var id: TimeInterval {
        time
    }
}
