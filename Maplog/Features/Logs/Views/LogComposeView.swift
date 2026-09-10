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
    @State private var isCaptionFocused = false
    @Environment(\.maplogSelectTab) private var selectTab

    let previewPlayer: AVPlayer
    let onCoverChangeTap: () -> Void
    let onClipLocationTap: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isPublicationDestinationPresented = false

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
        .onDisappear { isCaptionFocused = false }
        .navigationTitle("로그 작성")
        .navigationBarTitleDisplayMode(.inline)
        .maplogScreenSurface()
        .maplogNavigationAppearance()
        .safeAreaInset(edge: .bottom) {
            PrimaryActionButton(
                viewModel.isPerformingPublicationAction
                ? "처리 중..."
                : "발행 옵션",
                systemImage: viewModel.isPerformingPublicationAction
                ? nil
                : "paperplane.fill",
                isEnabled: !viewModel.isPerformingPublicationAction
            ) {
                isCaptionFocused = false
                viewModel.stopPreview()
                isPublicationDestinationPresented = true
            }
            .padding(.horizontal, MaplogSpacing.page)
            .padding(.vertical, MaplogSpacing.small)
            .background(Color.maplogSurface)
        }
        .navigationDestination(isPresented: $isPublicationDestinationPresented) {
            LogPublicationOptionsView(
                viewModel: viewModel,
                previewPlayer: previewPlayer,
                onMaplogPublished: {
                    selectTab(.home)
                }
            )
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") { isCaptionFocused = false }
            }
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
                width: previewWidth,
                height: previewHeight
            )

            Button {
                viewModel.togglePreviewPlayback()
            } label: {
                Color.clear
                    .frame(
                        width: previewWidth,
                        height: previewHeight
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
            width: previewWidth,
            height: previewHeight
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

    private var previewWidth: CGFloat {
        LogComposeLayout.previewWidth
    }

    private var previewHeight: CGFloat {
        previewWidth / viewModel.compositionConfiguration.aspectRatio
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
            MaplogVideoPlayerLayerView(player: previewPlayer, videoGravity: .resizeAspect)
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

            Text("여행 이야기와 해시태그를 남기면 검색에서 더 쉽게 발견돼요.")
                .font(MaplogFont.caption)
                .foregroundStyle(Color.maplogTextSecondary)

            ZStack(alignment: .topLeading) {
                if viewModel.caption.isEmpty {
                    Text("영상과 함께 남기고 싶은 여행 이야기를 적어보세요.\n#성수카페 #한강산책")
                        .font(MaplogFont.body)
                        .foregroundStyle(Color.maplogTextTertiary)
                        .padding(.horizontal, MaplogSpacing.medium)
                        .padding(.vertical, MaplogSpacing.medium)
                        .allowsHitTesting(false)
                }

                LogHashtagTextEditor(
                    text: $viewModel.caption,
                    isFocused: $isCaptionFocused
                )
                    .frame(minHeight: 148)
                    .accessibilityLabel("피드 내용")
                    .accessibilityHint("본문에 #해시태그를 입력하면 통합 검색 키워드로 저장됩니다")
                    .accessibilityValue(
                        viewModel.hashtags.isEmpty
                        ? "해시태그 없음"
                        : "해시태그 \(viewModel.hashtagPreviewText)"
                    )

            }
            .maplogCard()

            hashtagInputGuide
        }
    }

    private var hashtagInputGuide: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
            HStack(spacing: MaplogSpacing.xxSmall) {
                Label(
                    "검색 해시태그 \(viewModel.hashtagCountText)",
                    systemImage: "number"
                )
                .font(MaplogFont.caption)
                .foregroundStyle(
                    viewModel.hashtagValidationMessage == nil
                    ? Color.maplogPrimary
                    : Color.maplogDanger
                )

                Spacer()

                Text("최대 10개")
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogTextSecondary)
            }

            if let message = viewModel.hashtagValidationMessage {
                Text(message)
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogDanger)
                    .accessibilityAddTraits(.isStaticText)
            } else if viewModel.hashtags.isEmpty {
                Text("예: #성수카페 #한강산책 · 장소와 여행 주제를 더하면 사람들이 내 로그를 더 쉽게 찾을 수 있어요.")
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogTextSecondary)
            } else {
                Text(viewModel.hashtagPreviewText)
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogPrimary)
                    .lineLimit(2)
                    .accessibilityLabel("추출된 검색 해시태그")
                    .accessibilityValue(viewModel.hashtagPreviewText)
            }
        }
        .padding(.horizontal, MaplogSpacing.xSmall)
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

            Text(
                viewModel.isResolvingClipLocations
                ? "촬영 위치를 자동으로 확인하고 있어요."
                : "장소가 없으면 직접 선택하고, 기록된 장소도 수정할 수 있어요."
            )
            .font(MaplogFont.caption)
            .foregroundStyle(Color.maplogTextSecondary)

            if let error = viewModel.locationResolutionError {
                Text(error.message)
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogDanger)
            }

            if viewModel.canRetryLocationResolution {
                Button("위치 다시 조회") {
                    Task {
                        await viewModel.retryLocationResolution()
                    }
                }
                .font(MaplogFont.caption)
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
    static let playbackControlSize: CGFloat = 60
}
