//
//  HomeReelFirstFramePlayerView.swift
//  Maplog
//
//  홈 릴스가 첫 영상 프레임을 준비한 뒤에만 플레이어를 보여 주는 뷰
//

import AVFoundation
import SwiftUI

/// 썸네일 위에 영상을 올리기 전, AVPlayerLayer의 첫 프레임 준비 상태를 확인한다.
///
/// 이 뷰는 화면을 직접 전환하지 않는다. 준비가 끝났다는 사실만
/// `onFirstFrameReady`로 `HomeReelPage`에 알려 주고, 실제 표시 여부는 부모가 결정한다.
struct HomeReelFirstFramePlayerView: UIViewRepresentable, Equatable {
    let player: AVPlayer
    let onFirstFrameReady: () -> Void

    static func == (
        lhs: HomeReelFirstFramePlayerView,
        rhs: HomeReelFirstFramePlayerView
    ) -> Bool {
        lhs.player === rhs.player
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onFirstFrameReady: onFirstFrameReady)
    }

    // 릴스 화면에 진입
    func makeUIView(
        context: Context
    ) -> MaplogPlayerLayerContainerView {
        let view = MaplogPlayerLayerContainerView()

        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        context.coordinator.startObserving(view.playerLayer)

        return view
    }

    // 화면 상태 변경: 기존 UIKit 뷰 갱신
    func updateUIView(
        _ uiView: MaplogPlayerLayerContainerView,
        context: Context
    ) {
        context.coordinator.onFirstFrameReady = onFirstFrameReady

        guard uiView.playerLayer.player !== player else {
            return
        }

        uiView.playerLayer.player = player
        context.coordinator.startObserving(uiView.playerLayer)
    }

    // 릴스를 넘기거나 화면 이탈: 더 이상 필요 없는 감시 해제, static은 뷰 타입에 직접 호출하는 생명주기 함수
    static func dismantleUIView(
        _ uiView: MaplogPlayerLayerContainerView,
        coordinator: Coordinator
    ) {
        coordinator.stopObserving()
    }

    @MainActor
    final class Coordinator {
        private var readinessObservation: NSKeyValueObservation?
        private var hasReportedFirstFrame = false
        var onFirstFrameReady: () -> Void

        init(
            onFirstFrameReady: @escaping () -> Void
        ) {
            self.onFirstFrameReady = onFirstFrameReady
        }

        func startObserving(
            _ playerLayer: AVPlayerLayer
        ) {
            stopObserving()

            readinessObservation = playerLayer.observe(
                \.isReadyForDisplay,
                options: [.initial, .new]
            ) { [weak self] playerLayer, _ in
                Task { @MainActor [weak self] in
                    self?.handleDisplayReadiness(
                        isReady: playerLayer.isReadyForDisplay
                    )
                }
            }
        }

        func stopObserving() { // 첫 프레임 준비 감시를 해제
            readinessObservation?.invalidate()
            readinessObservation = nil
            hasReportedFirstFrame = false
        }

        private func handleDisplayReadiness(
            isReady: Bool
        ) {
            guard isReady,
                  !hasReportedFirstFrame
            else {
                return
            }

            hasReportedFirstFrame = true
            onFirstFrameReady()
        }
    }
}
