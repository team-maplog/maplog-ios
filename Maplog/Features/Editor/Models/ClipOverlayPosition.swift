//
//  ClipOverlayPosition.swift
//  Maplog
//
//  Created by 한채림 on 8/4/26.
//
//(0.5, 0.5) = 영상 정중앙
//(0.1, 0.9) = 왼쪽 아래

import Foundation

struct ClipOverlayPosition: Equatable, Sendable {
    var x: Double
    var y: Double

    init(
        x: Double = 0.5,
        y: Double = 0.5
    ) {
        self.x = min(max(x, 0), 1)
        self.y = min(max(y, 0), 1)
    }

    static let center = ClipOverlayPosition()
}
