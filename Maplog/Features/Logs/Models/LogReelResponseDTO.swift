//
//  LogReelResponseDTO.swift
//  Maplog
//
//  Created by 한채림 on 8/13/26.
// 서버 DTO

import Foundation

struct LogReelPageDTO: Decodable {
    let content: [LogReelDTO]
    let hasNext: Bool
    let nextCursor: String?
}

struct LogReelDTO: Decodable {
    let logID: Int64
    let author: LogReelAuthorDTO
    let caption: String
    let address: String
    let thumbnailURL: String?
    let playbackURL: String?
    let publishedAt: String
    let viewCount: Int64
    let clips: [LogReelClipDTO]
    let likeCount: Int64
    let commentCount: Int64
    let likedByViewer: Bool
    let savedByViewer: Bool

    enum CodingKeys: String, CodingKey {
        case logID = "logId"
        case author
        case caption
        case address
        case thumbnailURL = "thumbnailUrl"
        case playbackURL = "playbackUrl"
        case publishedAt
        case viewCount
        case clips
        case likeCount
        case commentCount
        case likedByViewer
        case savedByViewer
    }
}

struct LogReelAuthorDTO: Decodable {
    let userID: UUID
    let nickname: String
    let profileImageURL: String?

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case nickname
        case profileImageURL = "profileImageUrl"
    }
}

struct LogReelClipDTO: Decodable {
    let clipID: Int64
    let displayOrder: Int
    let startTimeMillis: Int64
    let endTimeMillis: Int64
    let location: LogReelLocationDTO
    let thumbnailURL: String?

    enum CodingKeys: String, CodingKey {
        case clipID = "clipId"
        case displayOrder
        case startTimeMillis
        case endTimeMillis
        case location
        case thumbnailURL = "thumbnailUrl"
    }
}

struct LogReelLocationDTO: Decodable {
    let name: String?
    let address: String
    let latitude: Double
    let longitude: Double
}
