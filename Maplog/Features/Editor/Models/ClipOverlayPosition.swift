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

// 편집 미리보기와 최종 세로 영상에서 공통으로 쓰는 텍스트 안전 영역이다.
// 홈 릴스가 화면을 꽉 채울 때 생길 수 있는 좌우 crop에도 텍스트가 남도록
// 가장자리에서 10% 안쪽을 기본 기준선으로 둔다.
enum ClipTextOverlaySafeArea {
    static let horizontalInset: Double = 0.10
    static let verticalInset: Double = 0.10
}
