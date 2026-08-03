//
//  VideoPlaybackServiceError.swift
//  Maplog
//
//  Created by 한채림 on 8/4/26.
// 재생 오류 타입

import Foundation

enum VideoPlaybackServiceError: Error {
    case noSourceVideos
    case sourceVideoUnavailable
    case unableToCreateCompositionTrack
}
