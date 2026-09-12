//
//  ClipEditorInput.swift
//  Maplog
//
//  Created by 한채림 on 8/2/26.
// 편집 화면을 열 때 넘길 선택 결과

import Foundation

struct ClipEditorInput: Identifiable, Equatable, Sendable {
    let id: UUID
    let clips: [CaptureDraftClip]
    let compositionConfiguration: VideoCompositionConfiguration

    init(
        clips: [CaptureDraftClip],
        compositionConfiguration: VideoCompositionConfiguration = .init()
    ) {
        self.id = UUID()
        self.clips = clips
        self.compositionConfiguration = compositionConfiguration
    }
}

//선택 순서: [B, A]
//→ ClipEditorInput
//   └─ clips: [B의 실제 영상 정보, A의 실제 영상 정보]
