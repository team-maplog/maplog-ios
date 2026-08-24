import SwiftUI

/// 지도 영상 미리보기와 로그 상세가 같은 모양으로 쓰는 드래그 가능한 재생 위치 바입니다.
struct MaplogVideoPlaybackBar: View {
    let progress: Double
    let onSeek: (Double) -> Void

    @State private var isScrubbing = false
    @State private var scrubbingProgress = 0.0

    private let barHeight: CGFloat = 4

    var body: some View {
        let safeProgress = progress.isFinite
            ? min(max(progress, 0), 1)
            : 0
        let displayProgress = isScrubbing
            ? scrubbingProgress
            : safeProgress

        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.32))

                Capsule()
                    .fill(Color.maplogLime)
                    .frame(width: max(4, width * displayProgress))

                Circle()
                    .fill(.white)
                    .frame(width: 12, height: 12)
                    .shadow(color: .black.opacity(0.24), radius: 2)
                    .position(
                        x: min(max(width * displayProgress, 6), width - 6),
                        y: barHeight / 2
                    )
            }
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isScrubbing = true
                        scrubbingProgress = normalizedProgress(
                            for: value.location.x,
                            width: width
                        )
                    }
                    .onEnded { value in
                        let progress = normalizedProgress(
                            for: value.location.x,
                            width: width
                        )
                        isScrubbing = false
                        scrubbingProgress = progress
                        onSeek(progress)
                    }
            )
        }
        .frame(height: barHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("영상 재생 위치")
        .accessibilityValue("\(Int(displayProgress * 100))퍼센트")
    }

    private func normalizedProgress(
        for horizontalPosition: CGFloat,
        width: CGFloat
    ) -> Double {
        min(max(horizontalPosition / width, 0), 1)
    }
}
