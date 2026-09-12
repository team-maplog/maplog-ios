//
//  LogCoverSelectionView.swift
//  Maplog
//
//  Created by 한채림 on 8/12/26.
// 실제 커버 변경 화면

import SwiftUI
import UIKit

struct LogCoverSelectionView: View {
    @ObservedObject var viewModel: LogCoverSelectionViewModel

    @State private var centeredFrameTime: TimeInterval?

    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
            ScrollView(showsIndicators: false) {
                VStack(spacing: MaplogSpacing.large) {
                                selectedPreview

                                Text("영상에서 대표 장면을 골라보세요")
                                    .font(MaplogFont.body)
                                    .foregroundStyle(Color.maplogTextPrimary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)

                                frameSelectionSection
                                errorSection
                            }
                            .maplogPagePadding()
                            .padding(.top, MaplogSpacing.pageTop)
                            .padding(.bottom, MaplogSpacing.section)
                        }
                        .navigationTitle("커버 변경")
                        .navigationBarTitleDisplayMode(.inline)
                        .navigationBarBackButtonHidden(true)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                MaplogNavigationButton(
                                    systemName: "chevron.left",
                                    accessibilityLabel: "뒤로 가기"
                                ) {
                                    dismiss()
                                }
                            }

                            ToolbarItem(placement: .topBarTrailing) {
                                Button("완료", action: onApply)
                                    .font(MaplogFont.bodyStrong)
                                    .foregroundStyle(Color.maplogTextPrimary)
                                    .disabled(
                                        viewModel.selectedFrame?.thumbnailData == nil
                                    )
                            }
                        }
                        .maplogScreenSurface()
                        .maplogNavigationAppearance()
                        .safeAreaInset(edge: .bottom) {
                            PrimaryActionButton(
                                "커버 적용",
                                isEnabled: viewModel.selectedFrame?.thumbnailData != nil,
                                action: onApply
                            )
                            .padding(.horizontal, MaplogSpacing.page)
                            .padding(.vertical, MaplogSpacing.small)
                            .background(Color.maplogSurface)
                        }
                    }

    private var selectedPreview: some View {
        HStack {
            Spacer(minLength: 0)

            ZStack(alignment: .bottom) {
                selectedPreviewImage
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
                    .clipped()

                Text(coverTimeText(viewModel.selectedTime))
                    .font(MaplogFont.caption)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, MaplogSpacing.small)
                    .padding(.vertical, MaplogSpacing.xxSmall)
                    .background(.black.opacity(0.62), in: Capsule())
                    .padding(.bottom, MaplogSpacing.small)
            }
            .frame(
                width: Layout.coverPreviewWidth,
                height: Layout.coverPreviewHeight
            )
            .background(Color.maplogSurfaceRaised)
            .compositingGroup()
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
                .stroke(.white.opacity(0.14), lineWidth: 1)
            }

            Spacer(minLength: 0)
        }
        .accessibilityLabel(
            "\(coverTimeText(viewModel.selectedTime)) 대표 커버"
        )
    }

    @ViewBuilder
        private var selectedPreviewImage: some View {
            if
                let thumbnailData = viewModel.selectedFrame?.thumbnailData,
                let image = UIImage(data: thumbnailData)
            {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.maplogSurfaceRaised
                    .overlay {
                        ProgressView()
                            .tint(Color.maplogPrimary)
                    }
            }
        }

    private var frameSelectionSection: some View {
            VStack(
                alignment: .leading,
                spacing: MaplogSpacing.small
            ) {
                Text("대표 장면")
                    .font(MaplogFont.sectionTitle)
                    .foregroundStyle(Color.maplogTextPrimary)

                frameTimeline

                Text(coverTimeText(viewModel.selectedTime))
                    .font(MaplogFont.bodyStrong)
                    .monospacedDigit()
                    .foregroundStyle(Color.maplogPrimary)
                    .frame(maxWidth: .infinity)
            }
        }

    private var frameTimeline: some View {
            GeometryReader { geometry in
                let horizontalInset = max(
                    (geometry.size.width - Layout.frameWidth) / 2,
                    0
                )

                ZStack {
                    RoundedRectangle(
                        cornerRadius: MaplogRadius.xLarge,
                        style: .continuous
                    )
                    .fill(Color.maplogSurface)
                    .shadow(
                        color: .black.opacity(0.06),
                        radius: 12,
                        y: 4
                    )

                    ScrollView(
                        .horizontal,
                        showsIndicators: false
                    ) {
                        LazyHStack(spacing: Layout.frameSpacing) {
                            ForEach(viewModel.frames) { frame in
                                Button {
                                    viewModel.selectFrame(
                                        at: frame.time
                                    )
                                } label: {
                                    frameCard(frame)
                                }
                                .buttonStyle(MaplogPressFeedbackStyle())
                                .id(frame.time)
                                .accessibilityLabel(
                                    "\(coverTimeText(frame.time)) 장면 선택"
                                )
                                .accessibilityAddTraits(
                                    frame.time == viewModel.selectedTime
                                    ? .isSelected
                                    : []
                                )
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.vertical, Layout.trayVerticalPadding)
                    }
                    .contentMargins(
                        .horizontal,
                        horizontalInset,
                        for: .scrollContent
                    )
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(
                        id: $centeredFrameTime,
                        anchor: .center
                    )

                    selectionIndicator
                }
                .onChange(of: centeredFrameTime) { _, time in
                    guard let time else {
                        return
                    }

                    guard time != viewModel.selectedTime else {
                        return
                    }

                    viewModel.selectFrame(at: time)
                }
                .onChange(of: viewModel.selectedTime) { _, time in
                    guard centeredFrameTime != time else {
                        return
                    }

                    centeredFrameTime = time
                }
                .task {
                    await viewModel.loadFrames()
                    centeredFrameTime = viewModel.selectedTime
                }
            }
            .frame(height: Layout.trayHeight)
        }

        private var selectionIndicator: some View {
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.maplogPrimary)
                    .frame(
                        width: Layout.indicatorDotSize,
                        height: Layout.indicatorDotSize
                    )

                Capsule()
                    .fill(Color.maplogPrimary)
                    .frame(
                        width: Layout.indicatorLineWidth,
                        height: Layout.indicatorLineHeight
                    )
            }
            .offset(y: -8)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }

    private func frameCard(
            _ frame: LogCoverFrame
        ) -> some View {
            Group {
                if
                    let thumbnailData = frame.thumbnailData,
                    let image = UIImage(data: thumbnailData)
                {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.maplogSurfaceRaised
                        .overlay {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Color.maplogPrimary)
                        }
                }
            }
            .frame(
                width: Layout.frameWidth,
                height: Layout.frameHeight
            )
            .clipShape(
                RoundedRectangle(
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
                    frame.time == viewModel.selectedTime
                    ? Color.maplogPrimary
                    : .clear,
                    lineWidth: 3
                )
            }
        }

    @ViewBuilder
        private var errorSection: some View {
            if let errorPresentation = viewModel.errorPresentation {
                VStack(
                    alignment: .leading,
                    spacing: MaplogSpacing.small
                ) {
                    Text(errorPresentation.message)
                        .font(MaplogFont.callout)
                        .foregroundStyle(Color.maplogDanger)

                    if errorPresentation.recoveryAction == .retry {
                        Button("다시 시도") {
                            Task {
                                await viewModel.retry()
                            }
                        }
                        .buttonStyle(
                            MaplogButtonStyle(
                                variant: .secondary,
                                size: .regular
                            )
                        )
                    }
                }
                .padding(MaplogSpacing.medium)
                .maplogCard()
            }
        }

        private func coverTimeText(
            _ time: TimeInterval
        ) -> String {
            let totalSeconds = Int(time.rounded(.down))

            return String(
                format: "%02d:%02d",
                totalSeconds / 60,
                totalSeconds % 60
            )
        }
    }

    private enum Layout {
        static let frameWidth: CGFloat = 56
        static let frameHeight: CGFloat = 80
        static let frameSpacing: CGFloat = 6
        static let trayHeight: CGFloat = 112
        static let trayVerticalPadding: CGFloat = 12
        static let indicatorDotSize: CGFloat = 12
        static let indicatorLineWidth: CGFloat = 2
        static let indicatorLineHeight: CGFloat = 96
        static let coverPreviewWidth: CGFloat = 152
        static let coverPreviewHeight: CGFloat =
            coverPreviewWidth * 16 / 9
    }
