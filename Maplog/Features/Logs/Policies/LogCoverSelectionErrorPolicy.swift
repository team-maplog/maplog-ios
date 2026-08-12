//
//  LogCoverSelectionErrorPolicy.swift
//  Maplog
//
//  Created by 한채림 on 8/12/26.
// 커버 선택 전용 오류 정책, AVFoundation에서 난 기술 오류를 화면 문구로 바꾸는 역할

import Foundation

enum LogCoverSelectionErrorPolicy {
    static func presentation(
        for error: Error
    ) -> ErrorPresentation {
        ErrorPresentation(
            message: "영상 프레임을 불러오지 못했어요. 다시 시도해 주세요.",
            recoveryAction: .retry
        )
    }
}
