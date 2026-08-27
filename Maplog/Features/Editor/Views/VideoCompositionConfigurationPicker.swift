//
//  VideoCompositionConfigurationPicker.swift
//  Maplog
//

import SwiftUI

/// 선택한 클립을 어떤 화면 비율과 분할 방식으로 완성할지 고르는 공통 UI입니다.
struct VideoCompositionConfigurationPicker: View {
    let configuration: VideoCompositionConfiguration
    let selectedClipCount: Int
    let onLayoutSelect: (VideoCompositionLayout) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.medium) {
            VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                Text("장면 구성")
                    .font(MaplogFont.calloutStrong)

                HStack(spacing: MaplogSpacing.xSmall) {
                    ForEach(VideoCompositionLayout.allCases) { layout in
                        layoutButton(layout)
                    }
                }

                Text(selectionGuidance)
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogTextSecondary)
            }
        }
    }

    private func layoutButton(
        _ layout: VideoCompositionLayout
    ) -> some View {
        let isSelected = configuration.layout == layout

        return Button {
            onLayoutSelect(layout)
        } label: {
            VStack(spacing: 6) {
                VideoCompositionLayoutPreview(
                    layout: layout,
                    tint: isSelected ? Color.maplogLime : Color.maplogLine
                )
                .frame(width: 40, height: 40)

                Text(layout.title)
                    .font(MaplogFont.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, MaplogSpacing.xSmall)
            .foregroundStyle(
                isSelected
                ? Color.maplogInk
                : Color.maplogTextSecondary
            )
            .background(
                isSelected
                ? Color.maplogLime.opacity(0.22)
                : Color.maplogSurfaceRaised,
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
                    isSelected
                    ? Color.maplogPrimary.opacity(0.7)
                    : Color.maplogLine,
                    lineWidth: 1
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(layout.title)
        .accessibilityValue(
            configuration.layout == layout ? "선택됨" : "선택되지 않음"
        )
    }

    private var selectionGuidance: String {
        let requiredCount = configuration.requiredClipCount

        guard configuration.layout != .single else {
            return "세로 릴스 화면으로 저장돼요. 가로 원본은 화면 너비에 맞춰 보여요."
        }

        if selectedClipCount == requiredCount {
            return "(requiredCount)개 장면이 동시에 재생되는 분할 영상으로 만들어요."
        }

        return "(configuration.layout.title)은 클립 (requiredCount)개를 선택해 주세요."
    }
}

struct VideoCompositionLayoutPreview: View {
    let layout: VideoCompositionLayout
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.maplogInk.opacity(0.9))

                ForEach(
                    Array(
                        layout.normalizedFrames.enumerated()
                    ),
                    id: \.offset
                ) { _, frame in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(tint.opacity(0.92))
                        .frame(
                            width: size.width * frame.width - 2,
                            height: size.height * frame.height - 2
                        )
                        .position(
                            x: size.width * frame.midX,
                            y: size.height * frame.midY
                        )
                }
            }
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
    }
}
