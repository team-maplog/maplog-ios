//
//  ClipEditrLayout.swift
//  Maplog
//
//  Created by 한채림 on 8/4/26.
// 화면 전용 크기 값을 분리, 편집 화면에서만 쓰는 화면 크기 규칙

import SwiftUI

enum ClipEditorLayout {
    static let topControlSize: CGFloat = 44
    static let topControlsTopInset: CGFloat = 48
    
    static let previewHeightRatio: CGFloat = 0.72
    static let previewMinimumHeight: CGFloat = 360

    // 세로 영상의 비율을 유지하면서도 하단 공간을 과하게 차지하지 않는 카드 크기다.
    static let timelineCardWidth: CGFloat = 48
    static let timelineCardHeight: CGFloat = 72
    static let timelineThumbnailHeight: CGFloat = 72
    static let timelineStripHeight: CGFloat = 72

    // 재생바 아래와 완료 버튼 위에 같은 여백을 둬서, 하단 편집 영역의
    // 세로 리듬을 일정하게 유지한다.
    static let timelineSectionSpacing: CGFloat = 12
    // 카드끼리는 이전처럼 조금 더 촘촘하게 배치한다.
    static let timelineCardSpacing: CGFloat = 8
    static let timelineActionHeight: CGFloat = 36

    static let timelineControlsHeight: CGFloat =
        timelineSectionSpacing
        + timelineStripHeight
        + timelineSectionSpacing
        + timelineActionHeight
    
    static let timelineBadgeSize: CGFloat = 18
    static let timelineOverlayInset: CGFloat = 3
    
    static let playbackControlRowHeight: CGFloat = 36
    static let playbackIconSize: CGFloat = 26
    
    // 재생바는 영상과 하단 컨트롤 사이의 경계선처럼 보여야 하므로,
    // 썸 크기와 같은 높이만 차지하게 둔다.
    static let playbackScrubberHeight: CGFloat = 8
    static let playbackTrackHeight: CGFloat = 3
    static let playbackThumbSize: CGFloat = 10
    
    static let playbackControlsHeight: CGFloat = playbackControlRowHeight
    // 세로형 클립 strip과 완료 버튼이 한 화면에 함께 보이도록 계산한다.
}
