//
//  VideoExportResult.swift
//  Maplog
//
//  Created by 한채림 on 8/3/26.
//

import Foundation

struct VideoExportResult: Identifiable, Equatable, Sendable {
    let fileURL: URL // 합쳐진 새 영상 파일 위치
    let duration: TimeInterval // 합쳐진 전체 길이
    
    var id: URL {
            fileURL
        }
}
