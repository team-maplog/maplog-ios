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
