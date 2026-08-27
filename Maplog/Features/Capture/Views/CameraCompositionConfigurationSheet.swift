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
                    onCanvasOrientationSelect: { orientation in
                        draftConfiguration.canvasOrientation = orientation
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

    var body: some View {
        GeometryReader { proxy in
            let frames = configuration.layout.normalizedFrames(
                for: configuration.canvasOrientation
            )

            ForEach(Array(frames.enumerated()), id: \.offset) { _, frame in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(Color.white.opacity(0.9), lineWidth: 1)
                    .frame(
                        width: proxy.size.width * frame.width - 4,
                        height: proxy.size.height * frame.height - 4
                    )
                    .position(
                        x: proxy.size.width * frame.midX,
                        y: proxy.size.height * frame.midY
                    )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
