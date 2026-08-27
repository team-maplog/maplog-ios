//
//  CameraCompositionConfigurationSheet.swift
//  Maplog
//

import SwiftUI

struct CameraCompositionConfigurationSheet: View {
    let configuration: VideoCompositionConfiguration
    let onConfigurationChange: (VideoCompositionConfiguration) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftConfiguration: VideoCompositionConfiguration

    init(
        configuration: VideoCompositionConfiguration,
        onConfigurationChange: @escaping (VideoCompositionConfiguration) -> Void
    ) {
        self.configuration = configuration
        self.onConfigurationChange = onConfigurationChange
        _draftConfiguration = State(initialValue: configuration)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: MaplogSpacing.section) {
                VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                    Text("촬영 구성")
                        .font(MaplogFont.screenTitle)

                    Text("장면을 차례로 촬영한 뒤 선택한 구성으로 한 영상에 배치해요.")
                        .font(MaplogFont.callout)
                        .foregroundStyle(Color.maplogTextSecondary)
                }

                VideoCompositionConfigurationPicker(
                    configuration: draftConfiguration,
                    selectedClipCount: draftConfiguration.requiredClipCount,
                    onLayoutSelect: { layout in
                        draftConfiguration.layout = layout
                    },
                    onSceneOrientationSelect: { orientation in
                        draftConfiguration.sceneOrientation = orientation
                    }
                )

                Spacer()

                PrimaryActionButton("구성 적용", systemImage: "checkmark") {
                    onConfigurationChange(draftConfiguration)
                    dismiss()
                }
            }
            .padding(MaplogSpacing.page)
            .navigationTitle("촬영 설정")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

struct CameraCompositionGuideOverlay: View {
    let configuration: VideoCompositionConfiguration
    let activeSlotIndex: Int

    var body: some View {
        GeometryReader { proxy in
            let sceneFrame = configuration.sceneFrame(in: proxy.size)
            let frames = configuration.layout.normalizedFrames(
                for: configuration.sceneOrientation
            )
            let visibleSlotIndex = min(
                activeSlotIndex,
                max(0, frames.count - 1)
            )

            ZStack {
                letterboxMask(sceneFrame: sceneFrame, canvasSize: proxy.size)

                ForEach(Array(frames.enumerated()), id: \.offset) { index, frame in
                    let isActive = index == visibleSlotIndex
                    let slotFrame = CGRect(
                        x: sceneFrame.minX + sceneFrame.width * frame.minX,
                        y: sceneFrame.minY + sceneFrame.height * frame.minY,
                        width: sceneFrame.width * frame.width,
                        height: sceneFrame.height * frame.height
                    )

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isActive ? Color.clear : Color.black.opacity(0.74))
                        .overlay {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(
                                    isActive
                                    ? Color.maplogLime
                                    : Color.white.opacity(0.28),
                                    lineWidth: isActive ? 3 : 1
                                )
                        }
                        .overlay(alignment: .topLeading) {
                            if isActive {
                                Text("지금 촬영")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.maplogInk)
                                    .padding(.horizontal, MaplogSpacing.small)
                                    .padding(.vertical, MaplogSpacing.xxSmall)
                                    .background(Color.maplogLime, in: Capsule())
                                    .padding(MaplogSpacing.xSmall)
                            } else {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .frame(width: 24, height: 24)
                                    .background(.black.opacity(0.5), in: Circle())
                                    .padding(MaplogSpacing.xSmall)
                            }
                        }
                        .frame(width: slotFrame.width - 4, height: slotFrame.height - 4)
                        .position(x: slotFrame.midX, y: slotFrame.midY)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(.easeInOut(duration: 0.2), value: activeSlotIndex)
    }

    @ViewBuilder
    private func letterboxMask(
        sceneFrame: CGRect,
        canvasSize: CGSize
    ) -> some View {
        if configuration.sceneOrientation == .horizontal {
            VStack(spacing: 0) {
                Color.black.opacity(0.88)
                    .frame(height: sceneFrame.minY)

                Color.clear
                    .frame(height: sceneFrame.height)

                Color.black.opacity(0.88)
                    .frame(height: max(0, canvasSize.height - sceneFrame.maxY))
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
        }
    }
}
