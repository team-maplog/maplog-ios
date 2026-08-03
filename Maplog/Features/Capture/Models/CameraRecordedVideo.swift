//
//  CameraRecordedVideo.swift
//  Maplog
//
//  Created by 한채림 on 7/31/26.
// Service가 녹화를 끝내고 돌려주는 결과, 아직 임시 파일이므로, 다음에 ViewModel이 이를 CaptureDraftClipInput으로 바꿔 Repository에 저장함

import Foundation

struct CameraRecordedVideo: Equatable, Sendable {
    let temporaryFileURL: URL
    let duration: TimeInterval
}
