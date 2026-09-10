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
    let isMuted: Bool
    let canUndoTextOverlayEdit: Bool

    let onFinishTextEditing: () -> Void
    let onClose: () -> Void
    let onUndoTap: () -> Void
    let onTextTap: () -> Void
    let onLocationTap: () -> Void
    let onMuteTap: () -> Void

    var body: some View {
        HStack(spacing: MaplogSpacing.xxSmall) {
            glassButton(
                symbol: "arrow.uturn.backward",
                accessibilityLabel: "편집 실행 취소",
                isEnabled: canUndoTextOverlayEdit,
                action: onUndoTap
            )

            Spacer(minLength: 0)

            if isTextEditing {
                glassButton(
                    symbol: "checkmark",
                    accessibilityLabel: "글자 입력 완료",
                    action: onFinishTextEditing
                )
            } else {
                HStack(spacing: MaplogSpacing.xxSmall) {
                    glassButton(
                        symbol: "chevron.left",
                        accessibilityLabel: "클립 선택으로 돌아가기",
                        action: onClose
                    )

                    glassButton(
                        symbol: "textformat",
                        accessibilityLabel: "텍스트 도구",
                        isSelected: activeTool == .text,
                        action: onTextTap
                    )

                    locationButton(
                        isSelected: activeTool == .location,
                        action: onLocationTap
                    )

                    glassButton(
                        symbol: isMuted
                        ? "speaker.slash.fill"
                        : "speaker.wave.2.fill",
                        accessibilityLabel: isMuted
                        ? "음소거 해제"
                        : "음소거",
                        isSelected: isMuted,
                        action: onMuteTap
                    )
                }
            }
        }
    }

    private func glassButton(
        symbol: String,
        accessibilityLabel: String,
        isSelected: Bool = false,
        isEnabled: Bool = true,
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
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
        .accessibilityLabel(accessibilityLabel)
    }

    private func locationButton(
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MaplogPinGlyphIcon(
                size: ClipEditorLayout.topControlSize * 0.48
            )
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
        .accessibilityLabel("위치와 시간 도구")
    }
}
