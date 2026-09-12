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
    ) -> MaplogPlayerLayerContainerView {
        let view = MaplogPlayerLayerContainerView()

        view.configure(player: player, videoGravity: .resizeAspect)

        return view
    }

    func updateUIView(
        _ uiView: MaplogPlayerLayerContainerView,
        context: Context
    ) {
        uiView.configure(player: player, videoGravity: .resizeAspect)
    }

    static func dismantleUIView(_ uiView: MaplogPlayerLayerContainerView, coordinator: ()) {
        uiView.disconnectPlayer()
    }
}
