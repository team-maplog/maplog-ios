//
//  ClipEditorPreviewView.swift
//  Maplog
//
//  Created by 한채림 on 8/2/26.
//

import AVFoundation
import AVKit
import SwiftUI

struct ClipEditorPreviewView: View {
    private let previewMaxWidth: CGFloat = 180
    
    let player: AVPlayer
    let selectedItem: ClipEditorTimelineItemViewData?
    let displayOrder: Int?
    let playbackProgress: Double
    
    var body: some View {
        VStack(spacing: MaplogSpacing.xxSmall) {
            ZStack(alignment: .bottomLeading) {
                if let selectedItem {
                    VideoPlayer(player: player)
                        .background(Color.black)
                    
                    LinearGradient(
                        colors: [
                            .clear,
                            .black.opacity(0.72)
                        ],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                    
                    VStack(
                        alignment: .leading,
                        spacing: MaplogSpacing.xxSmall
                    ) {
                        Text("\(displayOrder ?? 1)번 클립")
                            .font(MaplogFont.bodyStrong)
                        
                        Text(selectedItem.durationText)
                            .font(.caption)
                    }
                    .foregroundStyle(.white)
                    .padding(MaplogSpacing.small)
                    .allowsHitTesting(false)
                } else {
                    Color.black
                        .overlay {
                            ProgressView()
                                .tint(.white)
                        }
                }
            }
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .frame(maxWidth: previewMaxWidth)
            .frame(maxWidth: .infinity)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: MaplogRadius.medium,
                    style: .continuous
                )
            )
            
            ProgressView(value: playbackProgress)
                .progressViewStyle(.linear)
                .tint(Color.maplogLime)
                .accessibilityLabel("영상 재생 진행")
                .accessibilityValue(
                    "\(Int((playbackProgress * 100).rounded()))퍼센트"
                )
        }
        .frame(maxWidth: previewMaxWidth)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("선택한 클립 미리보기")
    }
}
