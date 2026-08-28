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

    // 모든 클립을 세로 카드 안에 배치한다.
    // 가로 영상은 이 높이를 넘지 않고, 남는 부분은 검정 여백으로 보인다.
    private let thumbnailHeight: CGFloat = 152
    
    private var isSelected: Bool {
        selectionOrder != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
            ZStack(alignment: .topTrailing) {
                Color.black

                thumbnailContent

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
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: thumbnailHeight)
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
        .contentShape(Rectangle())
        .animation(.snappy(duration: 0.2), value: selectionOrder)
    }
    
    @ViewBuilder
    private var thumbnailContent: some View {
        if let thumbnailData = item.thumbnailData,
           let image = UIImage(data: thumbnailData) {
            GeometryReader { proxy in
                if image.size.width > image.size.height {
                    // 가로 영상은 카드의 세로 중앙을 기준으로 전체가 보이게 한다.
                    // `scaledToFit()`이 비율을 보존하고, 바깥 고정 프레임이
                    // 남는 위·아래 영역을 검정 배경으로 유지한다.
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: proxy.size.width,
                            height: proxy.size.height,
                            alignment: .center
                        )
                } else {
                    // 세로 영상은 카드 영역을 채우되, 중심을 기준으로 잘라낸다.
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: proxy.size.width,
                            height: proxy.size.height,
                            alignment: .center
                        )
                        .clipped()
                }
            }
        } else {
            Color.black
                .overlay {
                    ProgressView()
                        .tint(.white)
                }
        }
    }
    
}
