//
//  Untitled.swift
//  Maplog
//
//  Created by 한채림 on 8/3/26.
//

import Foundation

enum VideoExportServiceError: Error {
    case noSourceVideos
    case sourceVideoUnavailable
    case unableToCreateCompositionTrack
    case unableToCreateExportSession
}
