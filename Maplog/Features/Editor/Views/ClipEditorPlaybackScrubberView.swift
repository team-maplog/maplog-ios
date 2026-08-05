//
//  ClipEditorPlaybackScrubberView.swift
//  Maplog
//
//  Created by 한채림 on 8/4/26.
//

import SwiftUI

struct ClipEditorPlaybackScrubberView: View {
    let progress: Double
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { proxy in
            let safeProgress = min(max(progress, 0), 1)
            let trackWidth = proxy.size.width
            let thumbOffset = max(
                0,
                min(
                    trackWidth - ClipEditorLayout.playbackThumbSize,
                    trackWidth * safeProgress
                        - ClipEditorLayout.playbackThumbSize / 2
                )
            )

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.maplogInk.opacity(0.10))
                    .frame(
                        height: ClipEditorLayout.playbackTrackHeight
                    )

                Capsule()
                    .fill(Color.maplogLime)
                    .frame(
                        width: trackWidth * safeProgress,
                        height: ClipEditorLayout.playbackTrackHeight
                    )

                Circle()
                    .fill(Color.maplogLime)
                    .frame(
                        width: ClipEditorLayout.playbackThumbSize,
                        height: ClipEditorLayout.playbackThumbSize
                    )
                    .shadow(
                        color: Color.maplogInk.opacity(0.12),
                        radius: 2,
                        y: 1
                    )
                    .offset(x: thumbOffset)
            }
            .frame(height: ClipEditorLayout.playbackThumbSize)
            .padding(
                .top,
                ClipEditorLayout.playbackScrubberTopInset
            )
            .frame(
                maxHeight: .infinity,
                alignment: .top
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newProgress = min(
                            max(value.location.x / trackWidth, 0),
                            1
                        )

                        onSeek(newProgress)
                    }
            )
        }
        // 실제 바는 얇지만, 손가락으로 잡는 영역은 넉넉하게 유지
        .frame(height: ClipEditorLayout.playbackScrubberHeight)
        .accessibilityLabel("영상 재생 위치")
    }
}
