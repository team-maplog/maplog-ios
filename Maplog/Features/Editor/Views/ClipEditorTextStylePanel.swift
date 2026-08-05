//
//  ClipEditorTextStylePanel.swift
//  Maplog
//
//  Created by 한채림 on 8/5/26.
//

import SwiftUI

import SwiftUI

struct ClipEditorTextStylePanel: View {
    let item: ClipTextOverlayItemViewData

    let onFontSizeChange: (Double) -> Void
    let onFontSelect: (ClipTextFont) -> Void
    let onWeightSelect: (ClipTextWeight) -> Void
    let onColorSelect: (ClipTextColor) -> Void


    @State private var isExpanded = true

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: MaplogSpacing.small
        ) {
            toggleButton

            if isExpanded {

                topStyleRow

                Divider()

                colorChoices
            }
        }
        .padding(.horizontal, MaplogSpacing.small)
        .padding(.vertical, MaplogSpacing.xSmall)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(
                cornerRadius: MaplogRadius.large,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: MaplogRadius.large,
                style: .continuous
            )
            .stroke(
                .white.opacity(0.35),
                lineWidth: 1
            )
        }
        .animation(
            .easeInOut(duration: 0.2),
            value: isExpanded
        )
        .accessibilityLabel("텍스트 스타일 편집")
    }

    private var toggleButton: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: MaplogSpacing.xxSmall) {
                Image(systemName: "textformat")
                    .font(.body.weight(.bold))

                Text("텍스트 스타일")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Image(
                    systemName: isExpanded
                        ? "chevron.down"
                        : "chevron.up"
                )
                .font(.caption.weight(.bold))
            }
            .foregroundStyle(Color.maplogInk)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isExpanded
                ? "텍스트 스타일 접기"
                : "텍스트 스타일 펼치기"
        )
    }
    
    private var topStyleRow: some View {
        ScrollView(
            .horizontal,
            showsIndicators: false
        ) {
            HStack(
                alignment: .top,
                spacing: MaplogSpacing.medium
            ) {
                fontSizeControl

                Divider()
                    .frame(height: 42)

                fontChoices

                Divider()
                    .frame(height: 42)

                weightChoices
            }
        }
    }

    private var fontSizeControl: some View {
        VStack(
            alignment: .leading,
            spacing: MaplogSpacing.xxSmall
        ) {
            Text("크기")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: MaplogSpacing.xxSmall) {
                Button {
                    onFontSizeChange(-2)
                } label: {
                    Image(
                        systemName: "textformat.size.smaller"
                    )
                }

                Text("\(Int(item.style.fontSize))")
                    .font(.caption.weight(.bold))
                    .frame(minWidth: 24)

                Button {
                    onFontSizeChange(2)
                } label: {
                    Image(
                        systemName: "textformat.size.larger"
                    )
                }
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.maplogInk)
        }
    }

    private var fontChoices: some View {
        choiceGroup(title: "폰트") {
            ForEach(
                ClipTextFont.allCases,
                id: \.rawValue
            ) { font in
                choiceButton(
                    title: fontTitle(font),
                    isSelected: item.style.font == font
                ) {
                    onFontSelect(font)
                }
            }
        }
    }

    private var weightChoices: some View {
        choiceGroup(title: "굵기") {
            ForEach(
                ClipTextWeight.allCases,
                id: \.rawValue
            ) { weight in
                choiceButton(
                    title: weightTitle(weight),
                    isSelected: item.style.weight == weight
                ) {
                    onWeightSelect(weight)
                }
            }
        }
    }

    private var colorChoices: some View {
        VStack(
            alignment: .leading,
            spacing: MaplogSpacing.xxSmall
        ) {
            Text("색상")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(
                .horizontal,
                showsIndicators: false
            ) {
                HStack(spacing: MaplogSpacing.xxSmall) {
                    ForEach(
                        ClipTextColor.allCases,
                        id: \.rawValue
                    ) { color in
                        Button {
                            onColorSelect(color)
                        } label: {
                            let isSelected = item.style.color == color

                            ZStack {
                                Circle()
                                    .fill(colorValue(color))
                                    .frame(width: 22, height: 22)

                                Circle()
                                    .strokeBorder(
                                        isSelected
                                            ? Color.maplogLime
                                            : .white.opacity(0.7),
                                        lineWidth: isSelected ? 2.5 : 1
                                    )
                                    .frame(width: 28, height: 28)
                            }
                            .frame(width: 30, height: 30)
                            .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                    }
                }
            }
        }
    }

    private func choiceGroup(
        title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: MaplogSpacing.xxSmall
        ) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: MaplogSpacing.xxSmall) {
                content()
            }
        }
    }

    private func choiceButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(
                    isSelected
                        ? Color.maplogInk
                        : .primary
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    isSelected
                        ? Color.maplogLime
                        : .white.opacity(0.38),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private func fontTitle(
        _ font: ClipTextFont
    ) -> String {
        switch font {
        case .standard:
            return "고딕"
        case .rounded:
            return "둥근"
        case .serif:
            return "명조"
        case .monospaced:
            return "모노"
        }
    }

    private func weightTitle(
        _ weight: ClipTextWeight
    ) -> String {
        switch weight {
        case .regular:
            return "보통"
        case .medium:
            return "중간"
        case .semibold:
            return "굵게"
        case .bold:
            return "강조"
        }
    }

    private func colorValue(
        _ color: ClipTextColor
    ) -> Color {
        switch color {
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
