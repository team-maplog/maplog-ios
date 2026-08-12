//
//  VideoThumbnailService.swift
//  Maplog
//
//  Created by 한채림 on 8/1/26.
//

import Foundation

protocol VideoThumbnailService: Sendable {
    func makeThumbnailData( // 기존처럼 영상의 첫 프레임
        for videoURL: URL
    ) async throws -> Data // Data를 반환하는 이유는 UIImage이나 SwiftUI Image처럼 화면 전용 타입을 ViewModel까지 올리지 않기 위해서

    func makeThumbnailData( // 사용자가 고른 time 초의 프레임
        for videoURL: URL,
        at time: TimeInterval
    ) async throws -> Data
}

//Service
//→ 영상 파일 URL을 받음
//→ 썸네일 이미지 데이터 반환
//
//ViewModel
//→ Data를 화면 상태로 보관
//
//View
//→ Data를 UIImage / Image로 바꿔서 그림
