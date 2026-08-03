//
//  ClipEditorTimelineStripView.swift
//  Maplog
//
//  Created by 한채림 on 8/2/26.
// 세로 목록을 가로 타임라인

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ClipEditorTimelineStripView: View {
    @State private var draggingID: UUID?
    
    let items: [ClipEditorTimelineItemViewData]
    let selectedID: UUID?
    let orderForID: (UUID) -> Int?
    let canRemove: Bool
    let onRemove: (UUID) -> Void
    let onSelect: (UUID) -> Void
    let onMove: (UUID, UUID) -> Void
    let onAdd: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: MaplogSpacing.small) {
                ForEach(items) { item in
                    if let displayOrder = orderForID(item.id) {
                        HStack(spacing: MaplogSpacing.small) {
                            ClipEditorTimelineItemView(
                                item: item,
                                displayOrder: displayOrder,
                                isSelected: item.id == selectedID,
                                onSelect: {
                                    onSelect(item.id)
                                },
                                onRemove: canRemove
                                    ? {
                                        onRemove(item.id)
                                    }
                                    : nil
                            )
                            
                            .buttonStyle(.plain)
                            .accessibilityLabel(
                                "\(displayOrder)번 클립, \(item.durationText)"
                            )
                            .accessibilityValue(
                                item.id == selectedID
                                ? "선택됨"
                                : "선택 안 됨"
                            )
                            .accessibilityHint(
                                "두 번 탭하여 미리보기로 선택"
                            )
                            .onDrag {
                                draggingID = item.id

                                return NSItemProvider( // 드래그 중인 카드가 있다는 것을 SwiftUI에 알려 주는 운반 상자
                                    object: item.id.uuidString as NSString
                                )
                            }
                            .onDrop(
                                of: [UTType.plainText],
                                delegate: ClipEditorTimelineDropDelegate(
                                    targetID: item.id,
                                    draggingID: $draggingID,
                                    onMove: onMove
                                )
                            )
                            
                            if displayOrder < items.count {
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Button(action: onAdd) {
                    addClipCard
                }
                .buttonStyle(.plain)
                .accessibilityLabel("편집할 클립 구성 변경")
            }
            .padding(.vertical, MaplogSpacing.xxSmall)
        }
        .accessibilityLabel("클립 타임라인")
        
    }
    
    private var addClipCard: some View {
        VStack(spacing: MaplogSpacing.small) {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.maplogInk)

            Text("클립 구성")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.maplogInk)
        }
        .frame(width: 104, height: 176)
        .background(
            Color.maplogSurfaceRaised,
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
                Color.maplogInk.opacity(0.22),
                style: StrokeStyle(
                    lineWidth: 1,
                    dash: [5, 4]
                )
            )
        }
    }
}
