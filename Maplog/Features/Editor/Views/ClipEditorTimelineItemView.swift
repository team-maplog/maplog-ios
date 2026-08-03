//
//  ClipEditorTimelineItemView.swift
//  Maplog
//
//  Created by 한채림 on 8/2/26.
// 타임라인 클립 카드 View

import SwiftUI
import UIKit

struct ClipEditorTimelineItemView: View {
    let item: ClipEditorTimelineItemViewData
    let displayOrder: Int
    let isSelected: Bool
    let onSelect: () -> Void // 카드를 탭하면 onSelect만 호출. view는 viewModel을 직접 모름
    let onRemove: (() -> Void)?
    
    //    let canMoveEarlier: Bool
    //    let canMoveLater: Bool
    //    let canRemove: Bool
    //
    //    // 카드 View는 ViewModel을 직접 알면 안 됨, 앞으로 이동해줘라는 행동만 closure로 전달받음
    //    let onMoveEarlier: () -> Void
    //    let onMoveLater: () -> Void
    //    let onRemove: () -> Void
    
    var body: some View {
            ZStack(alignment: .topTrailing) {
                Button(action: onSelect) {
                    cardContent
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "\(displayOrder)번 클립, \(item.durationText)"
                )
                .accessibilityValue(
                    isSelected ? "선택됨" : "선택 안 됨"
                )
                .accessibilityHint(
                    "길게 눌러 다른 카드 위치로 끌어 순서를 바꿀 수 있어요"
                )
                
                if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(
                                Color.maplogInk.opacity(0.72),
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .accessibilityLabel("\(displayOrder)번 클립 편집에서 제외")
                }
            }
        }
        private var cardContent: some View {
            VStack(
                alignment: .leading,
                spacing: MaplogSpacing.xxSmall
            ) {
                ZStack(alignment: .topLeading) {
                    thumbnail
                    
                    Text("\(displayOrder)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: 26, height: 26)
                        .background(
                            Color.maplogLime,
                            in: Circle()
                        )
                        .padding(6)
                }
                
                Text("\(displayOrder)번 클립")
                    .font(MaplogFont.bodyStrong)
                    .lineLimit(1)
                
                Text(item.durationText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 104, alignment: .leading)
            .padding(4)
            .background(
                isSelected
                ? Color.maplogLime.opacity(0.16)
                : Color.clear,
                in: RoundedRectangle(
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
                    isSelected ? Color.maplogLime : Color.clear,
                    lineWidth: 2
                )
            }
        }
    
    
    @ViewBuilder
    private var thumbnail: some View {
        Group {
            if
                let thumbnailData = item.thumbnailData,
                let image = UIImage(data: thumbnailData)
            {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.secondary.opacity(0.15)
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .frame(width: 104, height: 132)
        .clipShape(
            RoundedRectangle(
                cornerRadius: MaplogRadius.small,
                style: .continuous
            )
        )
        .overlay(alignment: .bottomTrailing) {
            Text(item.durationText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(6)
        }
    }
}

