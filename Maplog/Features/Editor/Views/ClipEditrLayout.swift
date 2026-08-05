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

    static let timelineCardWidth: CGFloat = 70
    static let timelineCardHeight: CGFloat = 96
    static let timelineThumbnailHeight: CGFloat = 96
    static let timelineStripHeight: CGFloat = 112

    static let timelineBadgeSize: CGFloat = 20
    static let timelineOverlayInset: CGFloat = 4
    
    static let playbackControlRowHeight: CGFloat = 32
    static let playbackIconSize: CGFloat = 26
    
    static let playbackScrubberHeight: CGFloat = 24
    static let playbackScrubberTopInset: CGFloat = 2
    static let playbackTrackHeight: CGFloat = 3
    static let playbackThumbSize: CGFloat = 10
}
