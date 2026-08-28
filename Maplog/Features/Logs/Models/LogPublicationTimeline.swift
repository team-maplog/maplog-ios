//
//  LogPublicationTimeline.swift
//  Maplog
//
//  로그 생성 API에 보낼, 겹치지 않는 클립 시간 구간을 만든다.

import Foundation

struct LogPublicationTimeRange: Equatable, Sendable {
    let startTime: TimeInterval
    let endTime: TimeInterval
}

/// 분할 영상은 여러 클립이 영상 안에서 동시에 보이지만, 서버의 지도 경로는
/// 클립 순서대로 진행되는 시간 구간을 요구합니다. 이 모델은 원본 클립 길이의
/// 비율을 유지하면서 최종 영상 전체를 빈틈없이 나눕니다.
enum LogPublicationTimeline {
    static func makeTimeRanges(
        sourceDurations: [TimeInterval],
        finalVideoDuration: TimeInterval
    ) -> [LogPublicationTimeRange]? {
        guard
            !sourceDurations.isEmpty,
            sourceDurations.allSatisfy({ $0.isFinite && $0 > 0 }),
            finalVideoDuration.isFinite,
            finalVideoDuration > 0
        else {
            return nil
        }

        let finalDurationMillis = Int(
            (finalVideoDuration * 1_000).rounded(.down)
        )

        guard finalDurationMillis >= sourceDurations.count else {
            return nil
        }

        var remainingDurationMillis = finalDurationMillis
        var remainingWeight = sourceDurations.reduce(0, +)
        var nextStartMillis = 0
        var ranges: [LogPublicationTimeRange] = []

        for (index, duration) in sourceDurations.enumerated() {
            let remainingClipCount = sourceDurations.count - index
            let durationMillis: Int

            if remainingClipCount == 1 {
                durationMillis = remainingDurationMillis
            } else {
                let proportionalDuration = Int(
                    (
                        Double(remainingDurationMillis)
                            * (duration / remainingWeight)
                    ).rounded()
                )
                let maximumDuration = remainingDurationMillis
                    - (remainingClipCount - 1)

                durationMillis = min(
                    max(proportionalDuration, 1),
                    maximumDuration
                )
            }

            let endTimeMillis = nextStartMillis + durationMillis
            ranges.append(
                LogPublicationTimeRange(
                    startTime: TimeInterval(nextStartMillis) / 1_000,
                    endTime: TimeInterval(endTimeMillis) / 1_000
                )
            )

            nextStartMillis = endTimeMillis
            remainingDurationMillis -= durationMillis
            remainingWeight -= duration
        }

        return ranges
    }
}
