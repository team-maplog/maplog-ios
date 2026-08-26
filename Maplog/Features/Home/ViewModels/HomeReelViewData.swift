//
//  HomeReelViewData.swift
//  Maplog
//
//  Created by 한채림 on 8/13/26.
// 홈 전용 릴스 표시 모델

import Foundation

struct HomeReelViewData: Identifiable, Equatable {
    let id: Int64
    let authorName: String
    let authorProfileImageURL: URL?
    let caption: String
    let address: String

    let thumbnailURL: URL?
    let playbackURL: URL?
    let publishedAt: Date

    let viewCount: Int64
    let likeCount: Int64
    let commentCount: Int64

    let isLikedByViewer: Bool
    let isSavedByViewer: Bool

    let clips: [HomeReelClipViewData]

    func replacingLike(
        isLikedByViewer: Bool,
        likeCount: Int64
    ) -> HomeReelViewData {
        HomeReelViewData(
            id: id,
            authorName: authorName,
            authorProfileImageURL: authorProfileImageURL,
            caption: caption,
            address: address,
            thumbnailURL: thumbnailURL,
            playbackURL: playbackURL,
            publishedAt: publishedAt,
            viewCount: viewCount,
            likeCount: likeCount,
            commentCount: commentCount,
            isLikedByViewer: isLikedByViewer,
            isSavedByViewer: isSavedByViewer,
            clips: clips
        )
    }

    func replacingSaved(
        isSavedByViewer: Bool
    ) -> HomeReelViewData {
        HomeReelViewData(
            id: id,
            authorName: authorName,
            authorProfileImageURL: authorProfileImageURL,
            caption: caption,
            address: address,
            thumbnailURL: thumbnailURL,
            playbackURL: playbackURL,
            publishedAt: publishedAt,
            viewCount: viewCount,
            likeCount: likeCount,
            commentCount: commentCount,
            isLikedByViewer: isLikedByViewer,
            isSavedByViewer: isSavedByViewer,
            clips: clips
        )
    }

    func replacingCommentCount(
        _ commentCount: Int64
    ) -> HomeReelViewData {
        HomeReelViewData(
            id: id,
            authorName: authorName,
            authorProfileImageURL: authorProfileImageURL,
            caption: caption,
            address: address,
            thumbnailURL: thumbnailURL,
            playbackURL: playbackURL,
            publishedAt: publishedAt,
            viewCount: viewCount,
            likeCount: likeCount,
            commentCount: commentCount,
            isLikedByViewer: isLikedByViewer,
            isSavedByViewer: isSavedByViewer,
            clips: clips
        )
    }
}

struct HomeReelClipViewData: Identifiable, Equatable {
    let id: Int64
    let displayOrder: Int
    let startTimeMillis: Int64
    let endTimeMillis: Int64

    let placeName: String?
    let address: String
    let latitude: Double
    let longitude: Double

    let thumbnailURL: URL?
}
