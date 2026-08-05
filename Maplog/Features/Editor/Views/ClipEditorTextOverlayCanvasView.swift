//
//  ClipEditorTextOverlayCanvasView.swift
//  Maplog
//
//  Created by 한채림 on 8/4/26.
//

import SwiftUI

// 영상 위에 자막들을 배치
struct ClipEditorTextOverlayCanvasView: View {
    let items: [ClipTextOverlayItemViewData]
    let selectedID: UUID?

    let onSelect: (UUID) -> Void
    let onPositionChange: (
        UUID,
        ClipOverlayPosition
    ) -> Void
    let onDragChanged: (Bool) -> Void
    let onDelete: (UUID) -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(items) { item in
                    ClipEditorTextOverlayItemView(
                        item: item,
                        isSelected: item.id == selectedID,
                        canvasSize: proxy.size,
                        onSelect: {
                            onSelect(item.id)
                        },
                        onPositionChange: { position in
                            onPositionChange(
                                item.id,
                                position
                            )
                        },
                        onDragChanged: onDragChanged,
                        onDelete: {
                            onDelete(item.id)
                        }
                    )
//                    .position(
//                        x: CGFloat(item.position.x)
//                            * proxy.size.width,
//                        y: CGFloat(item.position.y)
//                            * proxy.size.height
//                    )
                }
            }
        }
        .accessibilityLabel("텍스트 편집 영역")
    }
}

// 자막 하나의 글씨·선택 테두리·드래그 처리
private struct ClipEditorTextOverlayItemView: View {
    let item: ClipTextOverlayItemViewData
    let isSelected: Bool
    let canvasSize: CGSize

    let onSelect: () -> Void
    let onPositionChange: (
        ClipOverlayPosition
    ) -> Void
    let onDragChanged: (Bool) -> Void
    let onDelete: () -> Void
    

    @GestureState private var dragTranslation = CGSize.zero
    @State private var isDragging = false

    var body: some View {
        editableText
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    deleteButton
                        .offset(x: 8, y: -8)
                }
            }
            .position(displayPosition)
    }
    
    private var displayPosition: CGPoint {
        CGPoint(
            x: CGFloat(item.position.x) * canvasSize.width
                + dragTranslation.width,
            y: CGFloat(item.position.y) * canvasSize.height
                + dragTranslation.height
        )
    }
    
    // 텍스트의 x 버튼
    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "xmark")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(
                    Color.maplogInk.opacity(0.8),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("텍스트 삭제")
    }
    
    private var editableText: some View {
        Text(item.text)
            .font(textFont)
            .foregroundStyle(textColor)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.6)
            .shadow(
                color: .black.opacity(0.6),
                radius: 3,
                x: 0,
                y: 1
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .overlay {
                if isSelected {
                    RoundedRectangle(
                        cornerRadius: MaplogRadius.small,
                        style: .continuous
                    )
                    .stroke(
                        Color.maplogLime,
                        lineWidth: 2
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
            }
            .gesture(dragGesture)
            .accessibilityLabel(item.text)
            .accessibilityHint(
                "길게 누른 뒤 드래그해서 위치를 옮길 수 있어요."
            )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .updating($dragTranslation) { value, state, transaction in
                transaction.disablesAnimations = true
                state = value.translation
            }
            .onChanged { _ in
                guard !isDragging else {
                    return
                }

                isDragging = true
                onDragChanged(true)
            }
            .onEnded { value in
                let finalPosition = movedPosition(
                    from: item.position,
                    translation: value.translation
                )

                var transaction = Transaction()
                transaction.disablesAnimations = true

                withTransaction(transaction) {
                    onPositionChange(finalPosition)

                    isDragging = false
                    onDragChanged(false)
                }
            }
    }

    private func movedPosition(
        from startPosition: ClipOverlayPosition,
        translation: CGSize
    ) -> ClipOverlayPosition {
        guard
            canvasSize.width > 0,
            canvasSize.height > 0
        else {
            return startPosition
        }

        return ClipOverlayPosition(
            x: startPosition.x
                + Double(
                    translation.width
                        / canvasSize.width
                ),
            y: startPosition.y
                + Double(
                    translation.height
                        / canvasSize.height
                )
        )
    }

    private var textFont: Font {
        let size = CGFloat(item.style.fontSize)

        switch item.style.font {
        case .standard:
            return .system(
                size: size,
                weight: fontWeight,
                design: .default
            )

        case .rounded:
            return .system(
                size: size,
                weight: fontWeight,
                design: .rounded
            )

        case .serif:
            return .system(
                size: size,
                weight: fontWeight,
                design: .serif
            )

        case .monospaced:
            return .system(
                size: size,
                weight: fontWeight,
                design: .monospaced
            )
        }
    }

    private var fontWeight: Font.Weight {
        switch item.style.weight {
        case .regular:
            return .regular
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        case .bold:
            return .bold
        }
    }

    private var textColor: Color {
        switch item.style.color {
        case .white:
            return .white
        case .black:
            return .black
        case .maplogLime:
            return .maplogLime
        case .warmYellow:
            return Color(
                red: 1,
                green: 0.82,
                blue: 0.2
            )
        case .coral:
            return Color(
                red: 1,
                green: 0.35,
                blue: 0.3
            )
        case .pink:
            return Color(
                red: 1,
                green: 0.42,
                blue: 0.65
            )
        case .lavender:
            return Color(
                red: 0.68,
                green: 0.58,
                blue: 1
            )
        case .skyBlue:
            return Color(
                red: 0.28,
                green: 0.65,
                blue: 1
            )
        case .mint:
            return Color(
                red: 0.28,
                green: 0.9,
                blue: 0.7
            )
        }
    }
}
