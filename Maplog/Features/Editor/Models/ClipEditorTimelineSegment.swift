//
//  ClipEditorTimelineSegment.swift
//  Maplog
//
//  Created by 한채림 on 8/4/26.
// 현재 어느 클립의 몇 초인가로 변환하는 순수 모델, 오버레이가 클립 기준으로 정확히 나타남
// 편집 중 시간 계산을 담당하는 순수 계산 모델

import Foundation

struct ClipEditorTimelineSegment: Equatable, Sendable {
    let clipID: UUID
    let startTime: TimeInterval
    let endTime: TimeInterval

    var duration: TimeInterval {
        endTime - startTime
    }

    func localTime(
        for globalTime: TimeInterval
    ) -> TimeInterval {
        min(
            max(globalTime - startTime, 0),
            duration
        )
    }
}

struct ClipEditorTimeline: Equatable, Sendable {
    let segments: [ClipEditorTimelineSegment]

    init(
        clips: [CaptureDraftClip],
        compositionConfiguration: VideoCompositionConfiguration = .init()
    ) {
        if compositionConfiguration.layout != .single {
            let visibleClips = Array(
                clips.prefix(compositionConfiguration.requiredClipCount)
            )
            let durations = visibleClips.compactMap { clip -> TimeInterval? in
                guard
                    clip.mediaType == .video,
                    let duration = clip.duration,
                    duration > 0
                else {
                    return nil
                }

                return duration
            }

            guard
                durations.count == compositionConfiguration.requiredClipCount,
                let sharedDuration = durations.min()
            else {
                self.segments = []
                return
            }

            self.segments = visibleClips.map { clip in
                ClipEditorTimelineSegment(
                    clipID: clip.id,
                    startTime: 0,
                    endTime: sharedDuration
                )
            }
            return
        }

        var nextStartTime: TimeInterval = 0
        var madeSegments: [ClipEditorTimelineSegment] = []

        for clip in clips {
            guard
                clip.mediaType == .video,
                let duration = clip.duration,
                duration > 0
            else {
                continue
            }

            let segment = ClipEditorTimelineSegment(
                clipID: clip.id,
                startTime: nextStartTime,
                endTime: nextStartTime + duration
            )

            madeSegments.append(segment)
            nextStartTime += duration
        }

        self.segments = madeSegments
    }

    var totalDuration: TimeInterval {
        segments.last?.endTime ?? 0
    }

    func segment(
        at globalTime: TimeInterval
    ) -> ClipEditorTimelineSegment? {
        guard !segments.isEmpty else {
            return nil
        }

        let safeTime = min(
            max(globalTime, 0),
            totalDuration
        )

        return segments.first {
            safeTime >= $0.startTime
            && safeTime < $0.endTime
        } ?? segments.last
    }
}
