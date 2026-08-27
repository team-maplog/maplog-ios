//
//  ClipPickerGridItemView.swift
//  Maplog
//
//  Created by 한채림 on 8/1/26.
// 썸네일 카드 View

import SwiftUI
import UIKit

struct ClipPickerGridItemView: View {
    let item: ClipPickerItemViewData
    let selectionOrder: Int?

    private let thumbnailAspectRatio: CGFloat = 3.0 / 4.0
    
    private var isSelected: Bool {
        selectionOrder != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
            GeometryReader { proxy in
                ZStack(alignment: .topTrailing) {
                    thumbnailContent(size: proxy.size)

                    LinearGradient(
                        colors: [
                            .clear,
                            .black.opacity(0.55)
                        ],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    VStack {
                        Spacer()

                        HStack {
                            Image(systemName: "video.fill")
                            Text(item.durationText)
                        }
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(MaplogSpacing.xSmall)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                    }

                    if let selectionOrder {
                        Text("\(selectionOrder)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.black)
                            .frame(width: 28, height: 28)
                            .background(
                                Color.maplogLime,
                                in: Circle()
                            )
                            .padding(MaplogSpacing.xSmall)
                    }
                }
            }
            .aspectRatio(thumbnailAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipped()
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
                .stroke(
                    isSelected ? Color.maplogLime : .clear,
                    lineWidth: 3
                )
            }
            
            Text(item.capturedAtText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
    
    @ViewBuilder
    private func thumbnailContent(size: CGSize) -> some View {
        if let thumbnailData = item.thumbnailData,
           let image = UIImage(data: thumbnailData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(
                    width: size.width,
                    height: size.height
                )
                .clipped()
        } else {
            Color.black.opacity(0.55)
                .frame(width: size.width, height: size.height)
                .overlay {
                    ProgressView()
                        .tint(.white)
                }
        }
    }
    
}
