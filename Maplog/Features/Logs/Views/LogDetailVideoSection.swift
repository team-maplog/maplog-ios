import AVFoundation
import SwiftUI

/// 상세에서는 원본 세로 캔버스를 온전히 보여 주고 목록 카드의 높이와 분리합니다.
struct LogDetailVideoSection: View {
    let player: AVPlayer
    let isLoading: Bool
    let errorMessage: String?
    let playbackProgress: Double
    let isPlaying: Bool
    let onRetry: () -> Void
    let onPlaybackToggle: () -> Void
    let onSeek: (Double) -> Void

    var body: some View {
        ZStack {
            Color.black

            MaplogVideoPlayerLayerView(
                player: player,
                videoGravity: .resizeAspect
            )
            .equatable()
            .allowsHitTesting(false)

            if !isLoading,
               errorMessage == nil {
                videoTapArea

                if !isPlaying {
                    resumePlaybackButton
                }

                playbackBar
            }

            if isLoading {
                ProgressView()
                    .tint(.white)
            }

            if let errorMessage {
                playbackFailure(message: errorMessage)
            }
        }
        .aspectRatio(9 / 16, contentMode: .fit)
        .clipShape(RoundedRectangle(
            cornerRadius: MaplogRadius.xLarge,
            style: .continuous
        ))
        .overlay {
            RoundedRectangle(
                cornerRadius: MaplogRadius.xLarge,
                style: .continuous
            )
            .stroke(.black.opacity(0.06), lineWidth: 1)
        }
        .animation(.easeOut(duration: 0.18), value: isPlaying)
    }

    private var videoTapArea: some View {
        Button(action: onPlaybackToggle) {
            Color.clear
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(isPlaying ? "영상 일시정지" : "영상 재생")
    }

    private var resumePlaybackButton: some View {
        Button(action: onPlaybackToggle) {
            Image(systemName: "play.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(.black.opacity(0.54), in: Circle())
        }
        .buttonStyle(.plain)
        .transition(.scale(scale: 0.72).combined(with: .opacity))
        .accessibilityLabel("영상 재생")
    }

    private var playbackBar: some View {
        MaplogVideoPlaybackBar(
            progress: playbackProgress,
            onSeek: onSeek
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .bottom
        )
    }

    private func playbackFailure(
        message: String
    ) -> some View {
        VStack(spacing: MaplogSpacing.xSmall) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)

            Text(message)
                .font(MaplogFont.caption)
                .multilineTextAlignment(.center)

            Button("다시 시도", action: onRetry)
                .font(MaplogFont.caption)
                .foregroundStyle(Color.maplogLime)
        }
        .foregroundStyle(.white)
        .padding(MaplogSpacing.large)
        .background(.black.opacity(0.58), in: RoundedRectangle(
            cornerRadius: MaplogRadius.large,
            style: .continuous
        ))
    }
}
