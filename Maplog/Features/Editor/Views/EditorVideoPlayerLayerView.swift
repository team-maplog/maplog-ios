//
//  EditorVideoPlayerLayerView.swift
//  Maplog
//
//  Created by 한채림 on 8/5/26.
//

import AVFoundation
import SwiftUI
import UIKit

struct EditorVideoPlayerLayerView: UIViewRepresentable, Equatable {
    let player: AVPlayer

    static func == (
        lhs: EditorVideoPlayerLayerView,
        rhs: EditorVideoPlayerLayerView
    ) -> Bool {
        lhs.player === rhs.player
    }
    
    func makeUIView(
        context: Context
    ) -> PlayerLayerContainerView {
        let view = PlayerLayerContainerView()

        view.playerLayer.player = player

        return view
    }

    func updateUIView(
        _ uiView: PlayerLayerContainerView,
        context: Context
    ) {
        guard uiView.playerLayer.player !== player else {
            return
        }

        uiView.playerLayer.player = player
    }
}

final class PlayerLayerContainerView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
