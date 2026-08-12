//
//  VideoExportRequest.swift
//  Maplog
//
//  Created by 한채림 on 8/3/26.
// 어떤 결과 영상을 담을지 전달해서 service에 보냄

import Foundation

struct VideoExportRequest: Sendable {
    let clips: [CaptureDraftClip]
    let textOverlays: [ClipTextOverlay]
    let isMuted: Bool
}
