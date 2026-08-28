//
//  LogCreateRequestDTO.swift
//  Maplog
//
//  Created by 한채림 on 8/13/26.
// 로그 생성 요청 DTO

import Foundation

struct LogCreateRequestDTO: Encodable {
    let caption: String
    let tags: [String]
    let address: String
    let videoFileId: Int64
    let thumbnailTimeMillis: Int?
    let clips: [LogCreateClipDTO]

    enum CodingKeys: String, CodingKey {
        case caption
        case tags
        case address
        case videoFileId
        case thumbnailTimeMillis
        case clips
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(caption, forKey: .caption)
        // 본문에서 추출한 해시태그입니다. `#`은 제거한 값만 보냅니다.
        try container.encode(tags, forKey: .tags)
        try container.encode(address, forKey: .address)
        try container.encode(videoFileId, forKey: .videoFileId)
        try container.encodeIfPresent( // encodeIfPresent는 값이 있으면 숫자를 넣고, nil이면 그 JSON 키를 아예 보내지 않음
            thumbnailTimeMillis,
            forKey: .thumbnailTimeMillis
        )
        try container.encode(clips, forKey: .clips)
    }
}

struct LogCreateClipDTO: Encodable {
    let location: LogCreateLocationDTO
    let startTimeMillis: Int
    let endTimeMillis: Int
}

struct LogCreateLocationDTO: Encodable {
    let name: String?
    let address: String
    let latitude: Double
    let longitude: Double
}
