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
    let onSceneOrientationSelect: (VideoSceneOrientation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.medium) {
            VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                Text("완성 장면 비율")
                    .font(MaplogFont.calloutStrong)

                HStack(spacing: MaplogSpacing.xSmall) {
                    ForEach(VideoSceneOrientation.allCases) { orientation in
                        sceneOrientationButton(orientation)
                    }
                }

                Text("화면 구성")
                    .font(MaplogFont.calloutStrong)
                    .padding(.top, MaplogSpacing.small)

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
                    sceneOrientation: configuration.sceneOrientation,
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

    private func sceneOrientationButton(
        _ orientation: VideoSceneOrientation
    ) -> some View {
        let isSelected = configuration.sceneOrientation == orientation

        return Button {
            onSceneOrientationSelect(orientation)
        } label: {
            HStack(spacing: MaplogSpacing.xSmall) {
                VideoSceneOrientationIcon(
                    layout: configuration.layout,
                    sceneOrientation: orientation,
                    tint: isSelected ? Color.maplogLime : Color.maplogLine
                )
                .frame(width: 28, height: 28)

                Text("\(orientation.title) · \(orientation.detail)")
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
        .accessibilityLabel("\(orientation.title) 장면 비율")
        .accessibilityValue(isSelected ? "선택됨" : "선택되지 않음")
    }

    private var selectionGuidance: String {
        let requiredCount = configuration.requiredClipCount

        let sceneDescription = configuration.sceneOrientation == .horizontal
            ? "가로 장면은 세로 릴스 중앙에 배치되고 위아래는 검정으로 저장돼요."
            : "세로 장면은 릴스 화면을 꽉 채워 저장돼요."

        guard configuration.layout != .single else { return sceneDescription }

        if selectedClipCount == requiredCount {
            let splitDescription = configuration.sceneOrientation == .horizontal
                ? "좌우로"
                : "위아래로"
            return "\(requiredCount)개 장면을 \(splitDescription) 나눠 동시에 재생해요."
        }

        return "(configuration.layout.title)은 클립 (requiredCount)개를 선택해 주세요."
    }
}

struct VideoCompositionLayoutPreview: View {
    let layout: VideoCompositionLayout
    let sceneOrientation: VideoSceneOrientation
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.maplogInk.opacity(0.9))

                ForEach(
                    Array(
                        layout.normalizedFrames(for: sceneOrientation).enumerated()
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
        .aspectRatio(sceneOrientation.aspectRatio, contentMode: .fit)
    }
}

/// 장면 비율과 분할선을 작은 아이콘으로 보여 줍니다.
/// 세로는 세로 캡슐 안에 가로선, 가로는 넓은 화면 안에 세로선이 생깁니다.
private struct VideoSceneOrientationIcon: View {
    let layout: VideoCompositionLayout
    let sceneOrientation: VideoSceneOrientation
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
                        layout.normalizedFrames(for: sceneOrientation).enumerated()
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
        let aspectRatio = sceneOrientation.aspectRatio

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
