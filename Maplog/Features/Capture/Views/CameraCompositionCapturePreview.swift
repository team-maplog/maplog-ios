//
//  CameraCompositionCapturePreview.swift
//  Maplog
//

import AVFoundation
import SwiftUI

/// 분할 촬영에서는 완성 영상의 "한 칸"과 같은 비율로 카메라를 보여 줍니다.
/// 원본 파일은 보존하지만, 사용자가 보는 구도는 export의 중앙 크롭 영역과 같습니다.
struct CameraCompositionCapturePreview: View {
    let session: AVCaptureSession
    let configuration: VideoCompositionConfiguration
    let activeSlotIndex: Int

    var body: some View {
        GeometryReader { proxy in
            let progressHeight: CGFloat = 66
            let previewArea = CGSize(
                width: proxy.size.width,
                height: max(0, proxy.size.height - progressHeight)
            )
            let previewSize = fittedSize(
                for: configuration.captureFrameAspectRatio(
                    for: activeSlotIndex
                ),
                in: previewArea
            )

            VStack(spacing: MaplogSpacing.small) {
                Spacer(minLength: 0)

                CameraPreviewView(session: session)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: MaplogRadius.hero,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: MaplogRadius.hero,
                            style: .continuous
                        )
                        .stroke(Color.maplogLime, lineWidth: 2)
                    }
                    .frame(
                        width: previewSize.width,
                        height: previewSize.height
                    )
                    .accessibilityLabel(
                        "\(configuration.captureFrameRatioTitle) 촬영 프레임"
                    )

                CameraCompositionCaptureProgress(
                    configuration: configuration,
                    activeSlotIndex: activeSlotIndex
                )

                Spacer(minLength: 0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("분할 영상 촬영 미리보기")
        .animation(
            .spring(response: 0.32, dampingFraction: 0.82),
            value: activeSlotIndex
        )
    }

    private func fittedSize(
        for aspectRatio: CGFloat,
        in availableSize: CGSize
    ) -> CGSize {
        guard aspectRatio > 0 else {
            return .zero
        }

        let availableAspectRatio = availableSize.width / availableSize.height

        if aspectRatio > availableAspectRatio {
            return CGSize(
                width: availableSize.width,
                height: availableSize.width / aspectRatio
            )
        }

        return CGSize(
            width: availableSize.height * aspectRatio,
            height: availableSize.height
        )
    }
}

private struct CameraCompositionCaptureProgress: View {
    let configuration: VideoCompositionConfiguration
    let activeSlotIndex: Int

    var body: some View {
        HStack(spacing: MaplogSpacing.small) {
            CameraCompositionSlotMap(
                configuration: configuration,
                activeSlotIndex: activeSlotIndex
            )
            .frame(width: 34, height: 52)

            VStack(alignment: .leading, spacing: MaplogSpacing.xxxSmall) {
                Text("한 칸 촬영 프레임")
                    .font(MaplogFont.caption)
                    .foregroundStyle(.white.opacity(0.68))

                Text(configuration.captureFrameRatioTitle)
                    .font(MaplogFont.calloutStrong)
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)

            Text("\(activeSlotIndex + 1) / \(configuration.requiredClipCount)")
                .font(MaplogFont.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.maplogOnPrimary)
                .padding(.horizontal, MaplogSpacing.small)
                .padding(.vertical, MaplogSpacing.xxSmall)
                .background(Color.maplogLime, in: Capsule())
        }
        .padding(.horizontal, MaplogSpacing.small)
        .padding(.vertical, MaplogSpacing.xxSmall)
        .background(.black.opacity(0.44), in: Capsule())
    }
}

private struct CameraCompositionSlotMap: View {
    let configuration: VideoCompositionConfiguration
    let activeSlotIndex: Int

    var body: some View {
        GeometryReader { proxy in
            let reelSize = fittedReelSize(in: proxy.size)
            let reelOrigin = CGPoint(
                x: (proxy.size.width - reelSize.width) / 2,
                y: (proxy.size.height - reelSize.height) / 2
            )
            let sceneFrame = configuration.sceneFrame(in: reelSize)
            let frames = configuration.layout.normalizedFrames(
                for: configuration.sceneOrientation
            )

            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.black)
                    .frame(width: reelSize.width, height: reelSize.height)
                    .position(
                        x: reelOrigin.x + reelSize.width / 2,
                        y: reelOrigin.y + reelSize.height / 2
                    )

                ForEach(Array(frames.enumerated()), id: \.offset) { index, frame in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(
                            index == activeSlotIndex
                            ? Color.maplogLime
                            : .white.opacity(0.22)
                        )
                        .frame(
                            width: sceneFrame.width * frame.width - 1,
                            height: sceneFrame.height * frame.height - 1
                        )
                        .position(
                            x: reelOrigin.x
                                + sceneFrame.minX
                                + sceneFrame.width * frame.midX,
                            y: reelOrigin.y
                                + sceneFrame.minY
                                + sceneFrame.height * frame.midY
                        )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func fittedReelSize(in availableSize: CGSize) -> CGSize {
        let reelAspectRatio: CGFloat = 9.0 / 16.0

        if availableSize.width / availableSize.height > reelAspectRatio {
            return CGSize(
                width: availableSize.height * reelAspectRatio,
                height: availableSize.height
            )
        }

        return CGSize(
            width: availableSize.width,
            height: availableSize.width / reelAspectRatio
        )
    }
}
