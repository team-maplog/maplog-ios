//
//  LogPublishDraft.swift
//  Maplog
//
//  Created by 한채림 on 8/13/26.
// viewModel이 작성한 로그를 서버에 발행할 수 있는 재료로 정리

import Foundation

struct LogPublishDraft: Sendable {
    let videoFileURL: URL // 앱 내부에 저장된 최종 .mov 위치
    let caption: String
    let representativeAddress: String // 첫 번째 클립의 주소를 대표 주소로 사용
    let thumbnailTimeMillis: Int? // 대표 장면 선택 시점. 선택하지 않았다면 nil
    let clips: [LogPublishClipDraft] // 편집된 영상의 시간 순서와 각 장소 정보
}

struct LogPublishClipDraft: Sendable {
    let location: LogPublishLocationDraft
    let startTimeMillis: Int
    let endTimeMillis: Int
}

struct LogPublishLocationDraft: Sendable {
    let name: String?
    let address: String
    let latitude: Double
    let longitude: Double
}
