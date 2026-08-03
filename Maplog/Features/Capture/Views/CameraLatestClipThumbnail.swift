//
//  CameraLatestClipThumbnail.swift
//  Maplog
//
//  Created by 한채림 on 8/1/26.
//

import SwiftUI
import UIKit

struct CameraLatestClipThumbnail: View {
    let thumbnailData: Data?
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            thumbnailContent
            
            Image(systemName: "film.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(.black.opacity(0.5), in: Circle())
                            .padding(5)
        }
        .frame(width: 64, height: 64)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: MaplogRadius.medium,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: MaplogRadius.medium,
                        style: .continuous
                    )
                    .stroke(.white.opacity(0.72), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.28), radius: 10, x: 0, y: 5)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("최근 촬영 클립")
    }
    
    @ViewBuilder
    private var thumbnailContent: some View {
        if let thumbnailData,
           let image = UIImage(data: thumbnailData) {
            Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
        } else {
            Color.black.opacity(0.56)
                .overlay {
                    Image(systemName: "video.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                }
        }
    }
}
