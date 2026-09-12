//
//  LogReel.swift
//  Maplog
//
//  Created by 한채림 on 8/13/26.
// 앱 내부 모델, 내 로그, 저장한 로그 같은 LogReel 재사용 가능

import Foundation

struct LogReelPage: Equatable, Sendable {
    let reels: [LogReel]
    let hasNext: Bool
    let nextCursor: String?
}

struct LogReel: Identifiable, Equatable, Sendable {
    let id: Int64
    let author: LogReelAuthor
    let caption: String
    let tags: [LogTag]
    let address: String
    let thumbnailURL: URL?
    let playbackURL: URL?
    let publishedAt: Date
    let viewCount: Int64
    let clips: [LogReelClip]
    let likeCount: Int64
    let commentCount: Int64
    let isLikedByViewer: Bool
    let isSavedByViewer: Bool
}

struct LogReelAuthor: Equatable, Sendable {
    let id: UUID
    let nickname: String
    let profileImageURL: URL?
}

struct LogReelClip: Identifiable, Equatable, Sendable {
    let id: Int64
    let displayOrder: Int
    let startTimeMillis: Int64
    let endTimeMillis: Int64
    let location: LogReelLocation
    let thumbnailURL: URL?
}

struct LogReelLocation: Equatable, Sendable {
    let name: String?
    let address: String
    let latitude: Double
    let longitude: Double
}
