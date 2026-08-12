//
//  LogCoverSelectionInput.swift
//  Maplog
//
//  Created by 한채림 on 8/12/26.
// 커버 선택 전용 입력 모델

import Foundation

struct LogCoverSelectionInput: Identifiable, Equatable, Hashable, Sendable {
    let videoURL: URL // 커버 프레임을 추출할 최종 영상
    let duration: TimeInterval // 타임라인 범위 계산
    let initialSelectedTime: TimeInterval // 로그 작성 화면에서 이미 고른 커버 시점

    var id: URL {
        videoURL
    }
}
