//
//  VideoExportRequest.swift
//  Maplog
//
//  Created by 한채림 on 8/3/26.
//

import Foundation

struct VideoExportRequest: Sendable {
    let clips: [CaptureDraftClip]
    let textOverlays: [ClipTextOverlay]
}
