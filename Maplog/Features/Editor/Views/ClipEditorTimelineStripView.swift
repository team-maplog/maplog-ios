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
                        .onDrag {
                            draggingID = item.id

                            return NSItemProvider(
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
        .frame(height: ClipEditorLayout.timelineStripHeight)
        .accessibilityLabel("클립 타임라인")
        
    }
    
    private var addClipCard: some View {
        VStack(spacing: MaplogSpacing.xxSmall) {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.maplogInk)

            Text("클립 추가")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.maplogInk)
        }
        .frame(
            width: ClipEditorLayout.timelineCardWidth,
            height: ClipEditorLayout.timelineCardHeight
        )
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
