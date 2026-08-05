//
//  ClipEditorPlaybackControlsView.swift
//  Maplog
//
//  Created by 한채림 on 8/4/26.
//

import SwiftUI

struct ClipEditorPlaybackControlsView: View {
    let isPlaying: Bool
    let isMuted: Bool
    let currentTimeText: String
    let totalTimeText: String
    let progress: Double

    let onPlayPauseTap: () -> Void
    let onMuteTap: () -> Void
    let onSeek: (Double) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ClipEditorPlaybackScrubberView(
                    progress: progress,
                    onSeek: onSeek
                )
            .tint(Color.maplogLime)
            .frame(height: 12)
            .padding(.horizontal, MaplogSpacing.xxSmall)
            .accessibilityLabel("영상 재생 위치")

            HStack(spacing: MaplogSpacing.xSmall) {
                compactButton(
                    symbol: isPlaying
                    ? "pause.fill"
                    : "play.fill",
                    label: isPlaying
                    ? "일시정지"
                    : "재생",
                    action: onPlayPauseTap
                )

                Text("\(currentTimeText) / \(totalTimeText)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.maplogInk)
                    .monospacedDigit()

                Spacer(minLength: 0)

                compactButton(
                    symbol: isMuted
                    ? "speaker.slash.fill"
                    : "speaker.wave.2.fill",
                    label: isMuted
                    ? "음소거 해제"
                    : "음소거",
                    action: onMuteTap
                )
            }
            .frame(
                height: ClipEditorLayout.playbackControlRowHeight
            )
            .padding(.horizontal, MaplogSpacing.page)
        }
        .background(Color.maplogSurface)
    }

    private func compactButton(
        symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.maplogInk)
                .frame(
                    width: ClipEditorLayout.playbackIconSize,
                    height: ClipEditorLayout.playbackIconSize
                )
                .background(
                    Color.maplogInk.opacity(0.06),
                    in: RoundedRectangle(
                        cornerRadius: MaplogRadius.small,
                        style: .continuous
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
