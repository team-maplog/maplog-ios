//
//  CameraCaptureSettings.swift
//  Maplog
//
//  Created by 한채림 on 7/30/26.
//

//녹화 버튼 탭
//  → startTimer가 off면 즉시 녹화
//  → 3·5·10초면 카운트다운 후 녹화
//  → clipDuration(1·2·5초) 뒤 자동 녹화 종료
//  → 임시 클립 저장

import Foundation

enum CaptureStartTimer: Int, CaseIterable, Equatable, Sendable {
    case off = 0
    case seconds3 = 3
    case seconds5 = 5
    case seconds10 = 10
    
    var delay: TimeInterval? {
        rawValue == 0 ? nil : TimeInterval(rawValue)
    }
    
    var title: String {
        rawValue == 0 ? "끄기" : "\(rawValue)초"
    }
}

enum CaptureClipDuration: Int, CaseIterable, Equatable, Sendable {
    case seconds5 = 5
    case seconds1 = 1
    case seconds2 = 2
    
    var seconds: TimeInterval {
        TimeInterval(rawValue)
    }
    
    var title: String {
        "\(rawValue)s"
    }
}

struct CameraCaptureSettings: Equatable, Sendable {
    var startTimer: CaptureStartTimer = .off
    var clipDuration: CaptureClipDuration = .seconds1
    var isGridEnabled = false
    var timestampStyle: CaptureTimestampStyle = .dateAndPlace
    var compositionConfiguration = VideoCompositionConfiguration()
}
