//
//  VideoExportPreviewView.swift
//  Maplog
//
//  Created by 한채림 on 8/3/26.
// 완성본 미리보기 View

import AVFoundation
import AVKit
import SwiftUI

struct VideoExportPreviewView: View {
    let result: VideoExportResult
    let player: AVPlayer
    let onPreviewAppear: () -> Void
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
            NavigationStack {
                VStack(
                    alignment: .leading,
                    spacing: MaplogSpacing.section
                ) {
                    Text("영상이 완성됐어요")
                        .font(MaplogFont.screenTitle)

                    Text("클립의 순서와 소리가 자연스러운지 확인해 주세요.")
                        .font(MaplogFont.callout)
                        .foregroundStyle(.secondary)

                    VideoPlayer(player: player) // AVPlayer를 받아 실제 영상을 그리는 SwiftUI 컴포넌트
                        .aspectRatio(9.0 / 16.0, contentMode: .fit)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: MaplogRadius.large,
                                style: .continuous
                            )
                        )
                        .accessibilityLabel("완성된 영상 미리보기")

                    Spacer()

                    Button("편집으로 돌아가기") {
                        dismiss()
                    }
                    .buttonStyle(
                        MaplogButtonStyle(
                            variant: .secondary,
                            size: .large,
                            fullWidth: true
                        )
                    )
                }
                .padding(MaplogSpacing.page)
                .navigationTitle("완성본 미리보기")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("완성본 미리보기 닫기")
                    }
                }
            }
            .onAppear {
                onPreviewAppear()
            }
        }
}
