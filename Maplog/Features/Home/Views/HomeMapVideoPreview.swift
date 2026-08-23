//
//  Untitled.swift
//  Maplog
//
//  Created by 한채림 on 8/24/26.
//

import AVFoundation
import SwiftUI

struct HomeMapVideoPreview: View {
    let player: AVPlayer?
    let isLoading: Bool
    let hasPlaybackFailed: Bool
    let playbackProgress: Double
    let isPlaying: Bool
    let onPlayToggle: () -> Void
    let onSeek: (Double) -> Void
    let onRetry: () -> Void

    @State private var isScrubbing = false
    @State private var scrubbingProgress = 0.0

    private let playbackBarHeight: CGFloat = 4

    var body: some View {
        ZStack {
            Color.black

            if let player {
                MaplogVideoPlayerLayerView(
                    player: player,
                    videoGravity: .resizeAspectFill
                )
                .equatable()
                .allowsHitTesting(false)
            }

            if isLoading {
                ProgressView()
                    .tint(.white)
            }

            if hasPlaybackFailed {
                VStack(spacing: 12) {
                    Image(systemName: "video.slash")
                        .font(.title2)
                        .foregroundStyle(.white)

                    Text("영상을 불러오지 못했어요")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Button("다시 시도", action: onRetry)
                        .buttonStyle(.borderedProminent)
                        .tint(Color.maplogLime)
                        .foregroundStyle(Color.maplogInk)
                }
            }

            if player != nil,
               !isLoading,
               !hasPlaybackFailed {
                videoTapArea

                if !isPlaying {
                    resumePlaybackButton
                }

                bottomPlaybackBar
            }
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(
            color: .black.opacity(0.35),
            radius: 24,
            y: 12
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("장소 영상 미리보기")
        .animation(
            .easeOut(duration: 0.18),
            value: isPlaying
        )
    }
    private var videoTapArea: some View {
        Button(action: onPlayToggle) {
            Color.clear
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .accessibilityLabel(
            isPlaying ? "영상 일시정지" : "영상 재생"
        )
    }

    private var resumePlaybackButton: some View {
        Button(action: onPlayToggle) {
            Image(systemName: "play.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(
                    .black.opacity(0.54),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .transition(
            .scale(scale: 0.72)
                .combined(with: .opacity)
        )
        .accessibilityLabel("영상 재생")
    }

    private var bottomPlaybackBar: some View {
        previewPlaybackBar(
            progress: playbackProgress
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .bottom
        )
    }

    private func previewPlaybackBar(
        progress: Double
    ) -> some View {
        let safeProgress = progress.isFinite
            ? min(max(progress, 0), 1)
            : 0

        let displayProgress = isScrubbing
            ? scrubbingProgress
            : safeProgress

        return GeometryReader { proxy in
            let width = max(proxy.size.width, 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.32))

                Capsule()
                    .fill(Color.maplogLime)
                    .frame(
                        width: max(4, width * displayProgress)
                    )

                Circle()
                    .fill(.white)
                    .frame(width: 12, height: 12)
                    .shadow(
                        color: .black.opacity(0.24),
                        radius: 2
                    )
                    .position(
                        x: min(
                            max(width * displayProgress, 6),
                            width - 6
                        ),
                        y: playbackBarHeight / 2
                    )
            }
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isScrubbing = true
                        scrubbingProgress = min(
                            max(value.location.x / width, 0),
                            1
                        )
                    }
                    .onEnded { value in
                        let progress = min(
                            max(value.location.x / width, 0),
                            1
                        )

                        isScrubbing = false
                        scrubbingProgress = progress
                        onSeek(progress)
                    }
            )
        }
        .frame(height: playbackBarHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("영상 재생 위치")
        .accessibilityValue(
            "\(Int(displayProgress * 100))퍼센트"
        )
    }
}
