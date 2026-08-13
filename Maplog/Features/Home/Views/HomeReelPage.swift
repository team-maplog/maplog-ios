//
//  HomeReelPage.swift
//  Maplog
//
//  Created by 한채림 on 8/13/26.
// 실제 홈 릴스 페이지

import SwiftUI
import UIKit

struct HomeReelPage: View {
    let reel: HomeReelViewData
    let thumbnailData: Data?
    let isLoadingThumbnail: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                reelThumbnail
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height
                    )

                LinearGradient(
                    colors: [
                        .black.opacity(0.18),
                        .clear,
                        .black.opacity(0.88)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
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
                    proxy.safeAreaInsets.bottom
                        + MaplogSpacing.reelTabBarClearance
                )
            }
        }
        .background(Color.black)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(reel.authorName)의 로그, \(reel.address)"
        )
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
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)

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
                accessibilityLabel: "좋아요 \(reel.likeCount)개"
            )

            HomeReelMetric(
                systemImage: "message.fill",
                text: countText(reel.commentCount),
                accessibilityLabel: "댓글 \(reel.commentCount)개"
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
                accessibilityLabel: "저장"
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
}

private struct HomeReelMetric: View {
    let systemImage: String
    let text: String
    var tint: Color = .white
    let accessibilityLabel: String

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(tint)

            Text(text)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 44)
        .frame(minHeight: 45)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}
