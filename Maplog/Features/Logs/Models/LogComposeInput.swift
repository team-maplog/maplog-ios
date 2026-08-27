//
//  LogComposeInput.swift
//  Maplog
//
//  Created by 한채림 on 8/9/26.
//

import Foundation

struct LogComposeInput: Identifiable, Equatable, Sendable {
    let video: VideoExportResult // 자막까지 합성된 최종 영상
    let clips: [CaptureDraftClip] // 클립별 원본 영상·시간·촬영 좌표
    let compositionConfiguration: VideoCompositionConfiguration

    var id: URL {
        video.fileURL
    }
}
