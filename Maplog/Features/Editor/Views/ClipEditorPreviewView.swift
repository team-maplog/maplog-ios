//
//  ClipEditorPreviewView.swift
//  Maplog
//
//  Created by 한채림 on 8/2/26.
//

import AVFoundation
import SwiftUI

// 영상과 자막 캔버스를 겹쳐서 표시
struct ClipEditorPreviewView: View {
    
    
    let player: AVPlayer
    let selectedItem: ClipEditorTimelineItemViewData?

    let textOverlayItems: [ClipTextOverlayItemViewData]
    let selectedTextOverlayID: UUID?

    let onTextOverlayTap: (UUID) -> Void
    let onTextOverlayPositionChange: (
        UUID,
        ClipOverlayPosition
    ) -> Void
    let onOverlayDraggingChanged: (Bool) -> Void
    let onTextOverlayDelete: (UUID) -> Void
    let textInputRequestID: UUID?
    let onTextInputRequestHandled: (UUID) -> Void
    let onTextOverlayTextChange: (UUID, String) -> Void
    let onTextOverlayTextEditingFinished: (UUID) -> Void
    let onPreviewBackgroundTap: () -> Void
    
    var body: some View {
        VStack(spacing: MaplogSpacing.xxSmall) {
            ZStack(alignment: .bottomLeading) {
                if selectedItem != nil {
                    EditorVideoPlayerLayerView(player: player)
                        .equatable()
                        .background(Color.black)
                        .allowsHitTesting(false) // 영상 View가 터치를 가로채지 않으므로, 영상 위 텍스트의 탭·드래그만 정상적으로 받게됨
                    
                    LinearGradient(
                        colors: [
                            .clear,
                            .black.opacity(0.72)
                        ],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                    
                    ClipEditorUIKitTextOverlayCanvasView(
                        items: textOverlayItems,
                        selectedID: selectedTextOverlayID,
                        onSelect: onTextOverlayTap,
                        onPositionChange: onTextOverlayPositionChange,
                        onDragChanged: onOverlayDraggingChanged,
                        onDelete: onTextOverlayDelete,
                        textInputRequestID: textInputRequestID,
                        onTextInputRequestHandled: onTextInputRequestHandled,
                        onTextChange: onTextOverlayTextChange,
                        onTextEditingFinished: onTextOverlayTextEditingFinished,
                        onBackgroundTap: onPreviewBackgroundTap
                    )
                    
                } else {
                    Color.black
                        .overlay {
                            ProgressView()
                                .tint(.white)
                        }
                }
            }
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: MaplogRadius.medium,
                    style: .continuous
                )
            )
            
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("선택한 클립 미리보기")
    }
}
