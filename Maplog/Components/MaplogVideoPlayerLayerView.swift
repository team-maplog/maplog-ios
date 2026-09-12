//
//  MaplogVideoPlayerLayerView.swift
//  Maplog
//
//  Created by 한채림 on 8/15/26.
// 공용 Player Layer 만들기

import AVFoundation
import SwiftUI
import UIKit

struct MaplogVideoPlayerLayerView: UIViewRepresentable, Equatable {
    let player: AVPlayer // HomeViewModel의 playbackService.player가 여기로 들어옴, 화면에 연결할 실제 재생기
    let videoGravity: AVLayerVideoGravity // 영상 비율 결정

    static func == (
        lhs: MaplogVideoPlayerLayerView,
        rhs: MaplogVideoPlayerLayerView
    ) -> Bool {
        // Equatable이 요구하는 “두 View가 같은가?” 비교 함수
        // lhs = 왼쪽 View, rhs = 오른쪽 View
        lhs.player === rhs.player && // ===는 값 비교가 아닌 완전히 같은 객체인지를 확인
        lhs.videoGravity == rhs.videoGravity // 영상 비율 처리 방식도 같은 지 확인
    }

    func makeUIView( // SwiftUI가 이 View를 처음 화면에 표시할 때 한 번 호출
        context: Context
    ) -> MaplogPlayerLayerContainerView {
        let view = MaplogPlayerLayerContainerView() // AVPlayerLayer를 기본 layer로 갖는 UIKit View를 생성

        view.configure(player: player, videoGravity: videoGravity)

        return view
    }

    func updateUIView( // SwiftUI 상태가 바뀌었을 때 호출, 새 view 만들지 않고, 기존 UIKit View 갱신
        _ uiView: MaplogPlayerLayerContainerView,
        context: Context
    ) {
        uiView.configure(player: player, videoGravity: videoGravity)
    }

    static func dismantleUIView(_ uiView: MaplogPlayerLayerContainerView, coordinator: ()) {
        uiView.disconnectPlayer()
    }

}

final class MaplogPlayerLayerContainerView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self // 이 View는 생성될 때부터 AVPlayerLayer를 layer로 사용, 영상 재생 전용 UIView가 됨
    }

    var playerLayer: AVPlayerLayer { // UIView의 layer를 AVPlayerLayer로 편하게 꺼내 쓰기 위한 계산 프로퍼티
        layer as! AVPlayerLayer
    }

    private(set) var configuredPlayer: AVPlayer?

    func configure(player: AVPlayer, videoGravity: AVLayerVideoGravity) {
        configuredPlayer = player
        playerLayer.videoGravity = videoGravity
        updatePlayerAttachment()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updatePlayerAttachment()
    }

    func disconnectPlayer() {
        configuredPlayer = nil
        playerLayer.player = nil
    }

    private func updatePlayerAttachment() {
        // 스택에 보관된 이전 화면이 공유 플레이어의 영상 출력을 계속 점유하지 않게 한다.
        let visiblePlayer = window == nil ? nil : configuredPlayer
        if playerLayer.player !== visiblePlayer {
            playerLayer.player = visiblePlayer
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame) // 부모 UIView의 기본 생성 작업 실행

        backgroundColor = .black // // 영상이 준비되기 전이나 여백이 생길 때 검은색으로 표시
    }

    required init?(coder: NSCoder) { // // Storyboard/XIB로 UIView를 만들 때 필요한 생성자
        fatalError("init(coder:) has not been implemented") // Storyboard 방식으로 생성되면 즉시 문제를 알려줌
    }
}
