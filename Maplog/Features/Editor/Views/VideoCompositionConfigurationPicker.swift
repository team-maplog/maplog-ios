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
    let onSplitDirectionSelect: (VideoSplitDirection) -> Void

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

                if configuration.layout != .single {
                    Text("분할 방향")
                        .font(MaplogFont.calloutStrong)
                        .padding(.top, MaplogSpacing.xSmall)

                    HStack(spacing: MaplogSpacing.xSmall) {
                        ForEach(VideoSplitDirection.allCases) { direction in
                            splitDirectionButton(direction)
                        }
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
                    splitDirection: configuration.splitDirection,
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

    private func splitDirectionButton(
        _ direction: VideoSplitDirection
    ) -> some View {
        let isSelected = configuration.splitDirection == direction

        return Button {
            onSplitDirectionSelect(direction)
        } label: {
            HStack(spacing: MaplogSpacing.xSmall) {
                VideoSplitDirectionIcon(
                    layout: configuration.layout,
                    splitDirection: direction,
                    tint: isSelected ? Color.maplogLime : Color.maplogLine
                )
                .frame(width: 28, height: 28)

                Text("\(direction.title) · \(direction.detail)")
                    .font(MaplogFont.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .foregroundStyle(
                isSelected ? Color.maplogInk : Color.maplogTextSecondary
            )
            .background(
                isSelected ? Color.maplogLime : Color.maplogSurfaceRaised,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(direction.title) 방향으로 분할")
        .accessibilityValue(isSelected ? "선택됨" : "선택되지 않음")
    }

    private var selectionGuidance: String {
        let requiredCount = configuration.requiredClipCount

        guard configuration.layout != .single else {
            return "세로 릴스 화면으로 저장돼요. 가로 원본은 화면 너비에 맞춰 보여요."
        }

        if selectedClipCount == requiredCount {
            return "(requiredCount)개 장면을 \(configuration.splitDirection.detail)로 나눠 동시에 재생해요."
        }

        return "(configuration.layout.title)은 클립 (requiredCount)개를 선택해 주세요."
    }
}

struct VideoCompositionLayoutPreview: View {
    let layout: VideoCompositionLayout
    let splitDirection: VideoSplitDirection
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.maplogInk.opacity(0.9))

                ForEach(
                    Array(
                        layout.normalizedFrames(for: splitDirection).enumerated()
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

/// 분할선 방향을 작은 아이콘으로 보여 줍니다.
/// 세로 방향은 첨부한 모양처럼 세로 캡슐 안에 가로선이 생기고,
/// 가로 방향은 그 캡슐을 눕힌 모습으로 나타납니다.
private struct VideoSplitDirectionIcon: View {
    let layout: VideoCompositionLayout
    let splitDirection: VideoSplitDirection
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let availableSize = proxy.size
            let iconSize = iconSize(in: availableSize)

            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.maplogInk.opacity(0.9))

                ForEach(
                    Array(
                        layout.normalizedFrames(for: splitDirection).enumerated()
                    ),
                    id: \.offset
                ) { _, frame in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(tint.opacity(0.92))
                        .frame(
                            width: iconSize.width * frame.width - 1.5,
                            height: iconSize.height * frame.height - 1.5
                        )
                        .position(
                            x: iconSize.width * frame.midX,
                            y: iconSize.height * frame.midY
                        )
                }
            }
            .frame(width: iconSize.width, height: iconSize.height)
            .position(
                x: availableSize.width / 2,
                y: availableSize.height / 2
            )
        }
    }

    private func iconSize(in availableSize: CGSize) -> CGSize {
        let aspectRatio: CGFloat = splitDirection == .vertical
            ? 9.0 / 16.0
            : 16.0 / 9.0

        if availableSize.width / availableSize.height > aspectRatio {
            return CGSize(
                width: availableSize.height * aspectRatio,
                height: availableSize.height
            )
        }

        return CGSize(
            width: availableSize.width,
            height: availableSize.width / aspectRatio
        )
    }
}
