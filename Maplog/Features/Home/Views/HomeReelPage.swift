//
//  HomeReelPage.swift
//  Maplog
//
//  Created by 한채림 on 8/13/26.
// 실제 홈 릴스 페이지

import SwiftUI
import UIKit
import AVFoundation

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
    let onShare: () -> Void

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
                    reelInformation
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )

                    actionRail
                }
                .padding(.horizontal, MaplogSpacing.page)
                .padding(
                    .bottom,
                    reelBottomBlurHeight + MaplogSpacing.small
                )
            }
        }
        .background(Color.black)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(reel.authorName)의 로그, \(reel.address)"
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
        originalMedia
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
            HStack(spacing: 6) {
                MaplogProfileAvatar(
                    imageData: authorProfileImageData,
                    nickname: reel.authorName,
                    size: 28,
                    fallbackBackground: .white.opacity(0.22),
                    fallbackForeground: .white,
                    borderColor: .white.opacity(0.48)
                )

                Text(reel.authorName)
                    .font(.headline)
            }

            if !reel.caption.isEmpty {
                Text(reel.caption)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(3)
            }

            Label(reel.address, systemImage: "mappin.and.ellipse")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
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
                systemImage: "eye.fill",
                text: countText(reel.viewCount),
                accessibilityLabel: "조회 \(reel.viewCount)회"
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

private struct HomeReelMetric: View {
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
