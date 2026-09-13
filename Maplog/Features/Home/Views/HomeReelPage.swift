//
//  HomeReelPage.swift
//  Maplog
//
//  Created by 한채림 on 8/13/26.
// 실제 홈 릴스 페이지

import SwiftUI
import UIKit
import AVFoundation

/// 홈 첫 릴스 진입 중에는 부모 화면이 같은 프로필 행을 이동시킨다.
/// 이 기준점은 이동이 끝나는 실제 릴스 안 작성자 위치를 알려 준다.
struct HomeReelAuthorAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [Int64: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [Int64: Anchor<CGRect>],
        nextValue: () -> [Int64: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

struct HomeReelPage: View {
    let reel: HomeReelViewData
    let thumbnailData: Data?
    let isLoadingThumbnail: Bool
    let authorProfileImageData: Data?
    let player: AVPlayer?
    let isLoadingPlayback: Bool
    let playbackProgress: Double
    let onPlayToggle: () -> Void
    let onSeek: (Double) -> Void
    let isPlaying: Bool
    let isUpdatingLike: Bool
    let isUpdatingSave: Bool
    let onToggleLike: () -> Void
    let onToggleSave: () -> Void
    let onShowComments: () -> Void
    let onShowAuthorProfile: () -> Void
    let onShare: () -> Void
    /// 홈 미리보기의 네 모서리를 둥글게 표시하고 전체 릴스에서는 0으로 편다.
    var cornerRadius: CGFloat = 0
    /// 스크롤 페이지 크기는 유지하면서 홈에 보이는 영상 부분만 카드 모양으로 잘라낸다.
    var previewHorizontalInset: CGFloat = 0
    var previewBottomInset: CGFloat = 0
    /// 홈 첫 릴스 진입 중에는 HomeView가 정보 블록 전체를 이동시킨다.
    var usesExternalReelInfoOverlay = false
    /// 홈에서는 상단 작성자만 표시하고, 전체 릴스 진입 후 본문·위치·액션을 노출한다.
    var showsMetadata = true

    @State private var isScrubbing = false
    @State private var scrubbingProgress = 0.0
    @State private var showPlayStateBadge = false
    @State private var hideBadgeTask: Task<Void, Never>?

    private let reelBottomBlurHeight: CGFloat =
        VideoRenderCanvas.reelBottomTrayHeight
    private let reelPlaybackBarHeight: CGFloat = 4
    
    var body: some View {
        GeometryReader { proxy in
            let mediaSize = VideoRenderCanvas.reelMediaSize(
                in: proxy.size
            )

            let bottomTrayHeight =
                VideoRenderCanvas.reelBottomTrayHeight(
                    in: proxy.size
                )

            ZStack(alignment: .bottomLeading) {
                VStack(spacing: 0) {
                    reelMedia(in: mediaSize)

                    reelBottomBlur(
                        mediaSize: mediaSize,
                        trayHeight: bottomTrayHeight
                    )
                    .frame(
                        width: proxy.size.width,
                        height: bottomTrayHeight
                    )
                    .allowsHitTesting(false)
                }
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height,
                    alignment: .top
                )

                reelPlaybackBar(progress: playbackProgress)
                    .padding(.horizontal, MaplogSpacing.page)
                    .padding(
                        .bottom,
                        reelPlaybackBarBottomInset
                    )
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .bottom
                    )

                HStack(alignment: .bottom, spacing: 16) {
                    // 정보가 적으면 하단 기준이 유지되고, 본문이 길어질 때만 위로 자랍니다.
                    // 그래서 작성자마다 위치·본문이 없어도 액션 영역과 같은 높이에 놓입니다.
                    reelInformation
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )

                    actionRail
                }
                .opacity(showsMetadata ? 1 : 0)
                .allowsHitTesting(showsMetadata)
                .accessibilityHidden(!showsMetadata)
                .padding(.horizontal, MaplogSpacing.page)
                .padding(
                    .bottom,
                    // 장소의 아래쪽을 재생 바와 분리하고 첫 릴스의 외부 정보 오버레이에도 같은 기준점을 전달한다.
                    bottomTrayHeight + MaplogSpacing.large
                )

                if !showsMetadata {
                    authorProfileButton
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.65), radius: 4, y: 1)
                        .padding(MaplogSpacing.page)
                        .padding(.leading, previewHorizontalInset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .mask {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .frame(
                        width: max(0, proxy.size.width - previewHorizontalInset * 2),
                        height: max(0, proxy.size.height - previewBottomInset)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .contentShape(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .path(in: CGRect(
                        x: previewHorizontalInset, y: 0,
                        width: max(0, proxy.size.width - previewHorizontalInset * 2),
                        height: max(0, proxy.size.height - previewBottomInset)
                    ))
            )
        }
        .background(previewBottomInset > 0 ? Color(uiColor: .systemBackground) : Color.black)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            showsMetadata
                ? "\(reel.authorName)의 로그, \(reel.address)"
                : "여행 로그 미리보기"
        )

    }

    private func reelMedia(
        in size: CGSize
    ) -> some View {
        originalMedia
            .frame(
                width: size.width,
                height: size.height
            )
            .background(Color.black)
            .clipped()
    }

    private func reelBottomBlur(
        mediaSize: CGSize,
        trayHeight: CGFloat
    ) -> some View {
        originalThumbnail
            .frame(
                width: mediaSize.width,
                height: mediaSize.height
            )
            .blur(
                radius: 24,
                opaque: true
            )
            .frame(
                width: mediaSize.width,
                height: trayHeight,
                alignment: .bottom
            )
            .clipped()
    }
    
    
    // 실제 원본 영상
    private var originalMedia: some View {
        ZStack {
            originalThumbnail

            if let player {
                // 활성 플레이어는 항상 표시한다. 준비 신호 누락이 썸네일 정지로 남지 않게 한다.
                MaplogVideoPlayerLayerView(
                    player: player,
                    videoGravity: .resizeAspectFill
                )
                .equatable()
                .allowsHitTesting(false)
            }

            if isLoadingPlayback {
                Color.black.opacity(0.18)

                ProgressView()
                    .tint(.white)
            }
            
            if showPlayStateBadge {
                    ZStack {
                        Circle()
                            .fill(.black.opacity(0.45))
                            .frame(width: 56, height: 56)

                        Image(systemName: "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .zIndex(10)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
                }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard player != nil else { return }

                if isPlaying {
                    showPlayPauseBadge() // 정지시키는 동작 직전에 호출
                }

                onPlayToggle()
        }
        .background(Color.black)
        .clipped()
    }
    
    @ViewBuilder
    private var originalThumbnail: some View {
        if let thumbnailData,
           let image = UIImage(data: thumbnailData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
                .background(Color.black)

        } else if isLoadingThumbnail {
            ZStack {
                Color.black

                ProgressView()
                    .tint(.white)
            }

        } else {
            thumbnailFallback
        }
    }

//    인증된 API 요청
//    → Data
//    → UIImage(data:)
//    → Image(uiImage:)
//    → 화면
    @ViewBuilder
    private var reelThumbnail: some View {
        if let thumbnailData,
           let image = UIImage(data: thumbnailData) { // 이미지 원본 바이트를 iOS 이미지 객체로 바꿔줌
            Image(uiImage: image)
                .resizable()
                .scaledToFill()

        } else if isLoadingThumbnail {
            ZStack {
                Color.black

                ProgressView()
                    .tint(.white)
            }

        } else {
            thumbnailFallback
        }
    }

    private var thumbnailFallback: some View {
        ZStack {
            Color.maplogInk

            Image(systemName: "video.slash")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private var reelInformation: some View {
        VStack(alignment: .leading, spacing: 10) {
            authorProfileButton
                .anchorPreference(
                    key: HomeReelAuthorAnchorPreferenceKey.self,
                    value: .bounds
                ) { [reel.id: $0] }

            if let caption = nonEmptyText(reel.caption) {
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(3)
            }

            if let address = nonEmptyText(reel.address) {
                HStack(spacing: MaplogSpacing.xxSmall) {
                    MaplogPinGlyphIcon(size: 13)

                    Text(address)
                }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
                    .accessibilityElement(children: .combine)
            }
        }
        .foregroundStyle(.white)
        .opacity(usesExternalReelInfoOverlay ? 0 : 1)
        .allowsHitTesting(!usesExternalReelInfoOverlay)
        .accessibilityHidden(usesExternalReelInfoOverlay)
    }

    private var authorProfileButton: some View {
        Button(action: onShowAuthorProfile) {
            HStack(spacing: 6) {
                MaplogProfileAvatar(
                    imageData: authorProfileImageData,
                    nickname: reel.authorName,
                    size: 32,
                    fallbackBackground: .white.opacity(0.22),
                    fallbackForeground: .white,
                    borderColor: .white.opacity(0.64)
                )

                Text(reel.authorName)
                    .font(.headline)
            }
            .frame(
                minWidth: MaplogSize.minimumTapTarget,
                minHeight: MaplogSize.minimumTapTarget,
                alignment: .leading
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(reel.authorName)의 프로필")
        .accessibilityHint("탭하면 작성자의 공개 프로필을 봅니다")
    }

    private var actionRail: some View {
        VStack(spacing: MaplogSpacing.small) {
            HomeReelMetric(
                systemImage: reel.isLikedByViewer ? "heart.fill" : "heart",
                text: countText(reel.likeCount),
                tint: reel.isLikedByViewer
                    ? Color.maplogLime
                    : .white,
                accessibilityLabel: reel.isLikedByViewer
                    ? "좋아요 취소, \(reel.likeCount)개"
                    : "좋아요, \(reel.likeCount)개",
                isLoading: isUpdatingLike,
                action: onToggleLike
            )

            HomeReelMetric(
                systemImage: "message.fill",
                text: countText(reel.commentCount),
                accessibilityLabel: "댓글 \(reel.commentCount)개",
                action: onShowComments
            )

            HomeReelMetric(
                systemImage: "square.and.arrow.up",
                text: "공유",
                accessibilityLabel: "공유",
                action: onShare
            )

            HomeReelMetric(
                systemImage: reel.isSavedByViewer
                    ? "bookmark.fill"
                    : "bookmark",
                text: "저장",
                tint: reel.isSavedByViewer
                    ? Color.maplogLime
                    : .white,
                accessibilityLabel: reel.isSavedByViewer
                    ? "저장 취소"
                    : "저장",
                isLoading: isUpdatingSave,
                action: onToggleSave
            )
        }
        .frame(width: 44)
    }

    private func countText(_ count: Int64) -> String {
        guard count >= 1_000 else {
            return "\(count)"
        }

        let value = Double(count) / 1_000
        let text = String(format: "%.1f", value)

        return "\(text.replacingOccurrences(of: ".0", with: ""))K"
    }
    
    private func nonEmptyText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func reelPlaybackBar(
        progress: Double
    ) -> some View {
        let safeProgress = progress.isFinite ? min(max(progress, 0), 1) : 0
        let displayProgress = isScrubbing ? scrubbingProgress : safeProgress

        return GeometryReader { proxy in
            let clampedWidth = max(proxy.size.width, 1)
            let clampedProgress = min(max(displayProgress, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.32))
                    .frame(
                        width: clampedWidth,
                        height: reelPlaybackBarHeight
                    )

                Capsule()
                    .fill(Color.maplogLime)
                    .frame(
                        width: max(4, clampedWidth * clampedProgress),
                        height: reelPlaybackBarHeight
                    )
            }
            .frame(
                width: clampedWidth,
                height: reelPlaybackBarHeight
            )
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let clamped = min(max(value.location.x / clampedWidth, 0), 1)
                        isScrubbing = true
                        scrubbingProgress = clamped
                    }
                    .onEnded { value in
                        let clamped = min(max(value.location.x / clampedWidth, 0), 1)
                        isScrubbing = false
                        scrubbingProgress = clamped
                        onSeek(clamped)
                    }
            )
        }
        .frame(height: reelPlaybackBarHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("영상 재생 위치")
        .accessibilityValue("\(Int(displayProgress * 100))퍼센트")
    }
    
    private let reelPlaybackBarVerticalSpacing: CGFloat =
        MaplogSpacing.large

    private var reelPlaybackBarBottomInset: CGFloat {
        max(
            0,
            reelBottomBlurHeight
                - reelPlaybackBarHeight
                - reelPlaybackBarVerticalSpacing
        )
    }
    
    private func showPlayPauseBadge() {
        showPlayStateBadge = true
        hideBadgeTask?.cancel()

        hideBadgeTask = Task {
            try? await Task.sleep(for: .milliseconds(750))
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.2)) {
                    showPlayStateBadge = false
                }
            }
        }
    }


}

/// 홈 미리보기와 전체 릴스가 동일한 세로 액션 모양을 사용한다.
struct HomeReelMetric: View {
    let systemImage: String
    let text: String
    var tint: Color = .white
    let accessibilityLabel: String
    var isLoading = false
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) {
                metricContent
            }
            .buttonStyle(MaplogPressFeedbackStyle())
            .disabled(isLoading)
            .accessibilityLabel(accessibilityLabel)
        } else {
            metricContent
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel)
        }
    }

    private var metricContent: some View {
        VStack(spacing: 3) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
                    .frame(width: 21, height: 21)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 21, height: 21)
            }

            Text(text)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 44)
        .frame(minHeight: 45)
    }
}
