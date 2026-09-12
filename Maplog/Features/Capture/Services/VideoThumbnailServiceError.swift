//
//  VideoThumbnailServiceError.swift
//  Maplog
//
//  Created by 한채림 on 8/1/26.
// 썸네일용 오류 타입, 썸네일 생성이 실패하면 검은 기본 아이콘을 보여주고, 저장한 영상은 그대로 유지

import Foundation

enum VideoThumbnailServiceError: Error {
    case imageEncodingFailed
}
