//
//  MaplogCaptureButton.swift
//  Maplog
//
//  Created by 한채림 on 7/30/26.
//

import SwiftUI

struct MaplogCaptureButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var isReelStyle = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            captureSurface
                .environment(\.colorScheme, .light)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("새 로그 촬영")
        .accessibilityHint("카메라를 열어 여행 로그를 촬영합니다")
        .animation(
                reduceMotion ? nil : .smooth(duration: 0.4),
                value: isReelStyle
            )
    }
    
    @ViewBuilder
    private var captureSurface: some View {
        if #available(iOS 26, *) {
            captureIcon
                .background(.white.opacity(0.62), in: Circle())
                .glassEffect(.regular.interactive(),
                             in: .circle)
        } else {
            captureIcon
                .background(.white.opacity(0.62), in: Circle())
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.62),
                        lineWidth: 1)
                }
                .shadow(color: .black.opacity(isReelStyle ? 0.10 : 0.14),
                        radius: isReelStyle ? 10 : 12,
                        x: 0, y: isReelStyle ? 4 : 5)
        }
    }
    
    private var captureIcon: some View {
        Image(systemName: "camera.fill")
            .font(.system(size: isReelStyle ? 18 : 22, weight: .bold))
            .foregroundStyle(Color.maplogInk)
            .frame(
                width:isReelStyle ? 48 : 56,
                height: isReelStyle ? 48 : 56
            )
    }
    
}

#Preview {
    MaplogCaptureButton { }
        .padding()
        .background(Color.maplogCanvas)
}
