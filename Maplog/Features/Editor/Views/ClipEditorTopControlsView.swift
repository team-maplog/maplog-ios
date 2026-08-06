//
//  ClipEditorTopControlsView.swift
//  Maplog
//
//  Created by 한채림 on 8/4/26.
// 상단 도구 바

import SwiftUI

struct ClipEditorTopControlsView: View {
    let activeTool: ClipEditorActiveTool
    let isTextEditing: Bool

    let onClose: () -> Void
    let onTextTap: () -> Void
    let onLocationTap: () -> Void
    let onStickerTap: () -> Void

    var body: some View {
        HStack(spacing: MaplogSpacing.xxSmall) {
            glassButton(
                symbol: "xmark",
                accessibilityLabel: "클립 편집 닫기",
                action: onClose
            )

            if !isTextEditing {
                Spacer(minLength: 0)

                HStack(spacing: MaplogSpacing.xxSmall) {
                    passiveControl(
                        symbol: "arrow.uturn.backward"
                    )

                    glassButton(
                        symbol: "textformat",
                        accessibilityLabel: "텍스트 도구",
                        isSelected: activeTool == .text,
                        action: onTextTap
                    )

                    glassButton(
                        symbol: "mappin.and.ellipse",
                        accessibilityLabel: "위치와 시간 도구",
                        isSelected: activeTool == .location,
                        action: onLocationTap
                    )

                    glassButton(
                        symbol: "face.smiling",
                        accessibilityLabel: "스티커 도구",
                        isSelected: activeTool == .sticker,
                        action: onStickerTap
                    )

                    passiveControl(
                        symbol: "ellipsis"
                    )
                }
            }
        }
    }

    private func glassButton(
        symbol: String,
        accessibilityLabel: String,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline.weight(.semibold))
                .frame(
                    width: ClipEditorLayout.topControlSize,
                    height: ClipEditorLayout.topControlSize
                )
        }
        .foregroundStyle(
            isSelected
            ? Color.maplogInk
            : Color.white
        )
        .background(
            .ultraThinMaterial,
            in: Circle()
        )
        .background(
            isSelected
            ? Color.maplogLime
            : Color.clear,
            in: Circle()
        )
        .overlay {
            Circle()
                .stroke(
                    .white.opacity(0.5),
                    lineWidth: 1
                )
        }
        .buttonStyle(MaplogPressFeedbackStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    private func passiveControl(
        symbol: String
    ) -> some View {
        Image(systemName: symbol)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
            .frame(
                width: ClipEditorLayout.topControlSize,
                height: ClipEditorLayout.topControlSize
            )
            .background(
                .ultraThinMaterial,
                in: Circle()
            )
            .overlay {
                Circle()
                    .stroke(
                        .white.opacity(0.5),
                        lineWidth: 1
                    )
            }
            .accessibilityHidden(true)
    }
}
