//
//  Untitled.swift
//  Maplog
//
//  Created by 한채림 on 8/9/26.
//

import AVFoundation
import AVKit
import SwiftUI

struct LogComposeView: View {
    @ObservedObject var viewModel: LogComposeViewModel
    @FocusState private var isCaptionFocused: Bool

    let previewPlayer: AVPlayer
    let onCoverChangeTap: () -> Void
    let onClipLocationTap: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(
                alignment: .leading,
                spacing: MaplogSpacing.section
            ) {
                previewSection
                feedEditor
                clipLocationSection
            }
            .maplogPagePadding()
            .padding(.top, MaplogSpacing.pageTop)
            .padding(.bottom, MaplogSpacing.section)
        }
        .scrollDismissesKeyboard(.interactively)
        .contentShape(Rectangle())
        .gesture(
            TapGesture().onEnded {
                isCaptionFocused = false
            },
            including: .gesture
        )
        .navigationTitle("로그 작성")
        .navigationBarTitleDisplayMode(.inline)
        .maplogScreenSurface()
        .maplogNavigationAppearance()
        .safeAreaInset(edge: .bottom) {
            PrimaryActionButton(
                "로그 발행",
                systemImage: "paperplane.fill",
                isEnabled: false
            ) {
            }
            .padding(.horizontal, MaplogSpacing.page)
            .padding(.vertical, MaplogSpacing.small)
            .background(Color.maplogSurface)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("로그 작성 닫기")
            }
        }
    }

    private var previewSection: some View {
        ZStack {
            previewContent(
                width: LogComposeLayout.previewWidth,
                height: LogComposeLayout.previewHeight
            )

            Button {
                viewModel.togglePreviewPlayback()
            } label: {
                Color.clear
                    .frame(
                        width: LogComposeLayout.previewWidth,
                        height: LogComposeLayout.previewHeight
                    )
                    .overlay {
                        Image(
                            systemName: viewModel.isPreviewPlaying
                            ? "pause.fill"
                            : "play.fill"
                        )
                        .font(
                            .system(
                                size: LogComposeLayout.playbackControlSize * 0.4,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(.white)
                        .frame(
                            width: LogComposeLayout.playbackControlSize,
                            height: LogComposeLayout.playbackControlSize
                        )
                        .background(
                            .black.opacity(0.54),
                            in: Circle()
                        )
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                viewModel.isPreviewPlaying
                ? "영상 일시정지"
                : "영상 재생"
            )

            previewFooter
        }
        .frame(
            width: LogComposeLayout.previewWidth,
            height: LogComposeLayout.previewHeight
        )
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
            .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("완성된 로그 영상 미리보기")
    }

    private var previewFooter: some View {
        VStack {
            Spacer()

            HStack {
                Button(action: onCoverChangeTap) {
                    Label(
                        "커버 변경",
                        systemImage: "photo.on.rectangle"
                    )
                    .font(MaplogFont.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, MaplogSpacing.small)
                    .padding(.vertical, MaplogSpacing.xSmall)
                    .background(
                        .black.opacity(0.58),
                        in: Capsule()
                    )
                }
                .buttonStyle(MaplogPressFeedbackStyle())

                Spacer()

                Text(viewModel.videoDurationText)
                    .font(MaplogFont.caption)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, MaplogSpacing.small)
                    .padding(.vertical, MaplogSpacing.xSmall)
                    .background(
                        .black.opacity(0.58),
                        in: Capsule()
                    )
            }
            .padding(MaplogSpacing.small)
        }
    }

    @ViewBuilder
    private func previewContent(
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        if
            !viewModel.isPreviewPlaying,
            let thumbnailData = viewModel.selectedCoverThumbnailData,
            let image = UIImage(data: thumbnailData)
        {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(
                    width: width,
                    height: height
                )
                .clipped()
        } else {
            VideoPlayer(player: previewPlayer)
                .frame(
                    width: width,
                    height: height
                )
                .clipped()
                .allowsHitTesting(false)
        }
    }

    private var feedEditor: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            SectionHeader(title: "피드에 기록")

            ZStack(alignment: .topLeading) {
                if viewModel.caption.isEmpty {
                    Text("영상과 함께 남기고 싶은 이야기를 적어보세요.")
                        .font(MaplogFont.body)
                        .foregroundStyle(Color.maplogTextTertiary)
                        .padding(.horizontal, MaplogSpacing.medium)
                        .padding(.vertical, MaplogSpacing.medium)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $viewModel.caption)
                    .font(MaplogFont.body)
                    .foregroundStyle(Color.maplogInk)
                    .frame(minHeight: 120)
                    .padding(MaplogSpacing.xSmall)
                    .scrollContentBackground(.hidden)
                    .accessibilityLabel("피드 내용")
                    .focused($isCaptionFocused)
            }
            .maplogCard()
        }
    }

    private var clipLocationSection: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            HStack(spacing: MaplogSpacing.xxSmall) {
                Text("클립별 장소 기록")
                    .font(MaplogFont.sectionTitle)
                    .foregroundStyle(Color.maplogTextPrimary)

                Text(viewModel.clipLocationCountText)
                    .font(MaplogFont.calloutStrong)
                    .foregroundStyle(Color.maplogPrimary)
            }

            LazyVStack(spacing: MaplogSpacing.xSmall) {
                ForEach(viewModel.clipLocations) { clipLocation in
                    LogComposeClipLocationCard(
                        thumbnailData: viewModel.thumbnailData(
                            for: clipLocation.id
                        ),
                        timeRangeText: viewModel.timeRangeText(
                            for: clipLocation
                        ),
                        locationText: viewModel.locationText(
                            for: clipLocation
                        ),
                        onTap: {
                            onClipLocationTap(clipLocation.id)
                        }
                    )
                }
            }
        }
    }
}

private enum LogComposeLayout {
    static let previewWidth: CGFloat = 210
    static let videoWidth: CGFloat = 9
    static let videoHeight: CGFloat = 16
    static let previewHeight: CGFloat = previewWidth * videoHeight / videoWidth
    static let playbackControlSize: CGFloat = 60
}
