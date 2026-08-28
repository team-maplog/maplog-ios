//
//  CameraCompositionConfigurationSheet.swift
//  Maplog
//

import SwiftUI

/// 촬영 화면에서 분할과 장면 비율을 바로 바꾸는 인라인 선택기입니다.
/// 별도의 적용 단계 없이 한 항목을 누르는 즉시 카메라 프리뷰에도 반영합니다.
struct CameraCompositionQuickPicker: View {
    let configuration: VideoCompositionConfiguration
    let onConfigurationChange: (VideoCompositionConfiguration) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            HStack(spacing: MaplogSpacing.xSmall) {
                Image("MaplogCollageGlyph")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)

                Text("촬영 구성")
                    .font(MaplogFont.calloutStrong)

                Spacer(minLength: 0)

                Text("누르는 즉시 적용")
                    .font(MaplogFont.badge)
                    .foregroundStyle(.white.opacity(0.68))
            }
            .foregroundStyle(.white)

            HStack(spacing: MaplogSpacing.xSmall) {
                ForEach(VideoSceneOrientation.allCases) { orientation in
                    orientationButton(orientation)
                }
            }

            HStack(spacing: MaplogSpacing.xSmall) {
                ForEach(VideoCompositionLayout.allCases) { layout in
                    layoutButton(layout)
                }
            }
        }
        .padding(MaplogSpacing.medium)
        .background(.black.opacity(0.72), in: RoundedRectangle(
            cornerRadius: MaplogRadius.large,
            style: .continuous
        ))
        .overlay {
            RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
    }

    private func orientationButton(
        _ orientation: VideoSceneOrientation
    ) -> some View {
        let isSelected = configuration.sceneOrientation == orientation

        return Button {
            onConfigurationChange(
                VideoCompositionConfiguration(
                    layout: configuration.layout,
                    sceneOrientation: orientation
                )
            )
        } label: {
            HStack(spacing: MaplogSpacing.xSmall) {
                CameraCompositionOrientationGlyph(
                    orientation: orientation,
                    tint: isSelected ? Color.maplogInk : .white
                )
                .frame(width: 20, height: 20)

                Text("\(orientation.title) · \(orientation.detail)")
                    .font(MaplogFont.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(isSelected ? Color.maplogInk : .white)
            .background(
                isSelected ? Color.maplogLime : .white.opacity(0.14),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(orientation.title) 장면 비율")
        .accessibilityValue(isSelected ? "선택됨" : "선택되지 않음")
    }

    private func layoutButton(
        _ layout: VideoCompositionLayout
    ) -> some View {
        let isSelected = configuration.layout == layout
        let title = layout == .single ? "1컷" : layout.title

        return Button {
            onConfigurationChange(
                VideoCompositionConfiguration(
                    layout: layout,
                    sceneOrientation: configuration.sceneOrientation
                )
            )
        } label: {
            VStack(spacing: MaplogSpacing.xxxSmall) {
                VideoCompositionLayoutPreview(
                    layout: layout,
                    sceneOrientation: configuration.sceneOrientation,
                    tint: isSelected ? Color.maplogLime : .white.opacity(0.48)
                )
                .frame(width: 30, height: 30)

                Text(title)
                    .font(MaplogFont.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 68)
            .foregroundStyle(isSelected ? Color.maplogLime : .white)
            .background(
                isSelected ? Color.maplogLime.opacity(0.18) : .white.opacity(0.08),
                in: RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: MaplogRadius.medium, style: .continuous)
                    .stroke(
                        isSelected ? Color.maplogLime : .white.opacity(0.16),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "선택됨" : "선택되지 않음")
    }
}

private struct CameraCompositionOrientationGlyph: View {
    let orientation: VideoSceneOrientation
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .stroke(tint, lineWidth: 1.7)
            .frame(
                width: orientation == .vertical ? 11 : 20,
                height: orientation == .vertical ? 20 : 11
            )
            .frame(width: 20, height: 20)
            .accessibilityHidden(true)
    }
}
