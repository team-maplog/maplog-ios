//
//  FestivalDTO.swift
//  Maplog
//
//  Created by 한채림 on 7/21/26.
//

// DTO는 서버 JSON 형태를 표현
// 날짜는 아직 String, 이미지도 아직 String
//서버 키는 thumbnailUrl
//Swift 코드에서는 약어를 URL로 쓰는 것이 관례
//그래서 CodingKeys로 두 이름을 연결합니다.
//region은 실제 API 응답에서도 null이므로 반드시 String?
//서버가 보내는 날짜는 "2026-07-30"이므로 이 단계에서는 String
//thumbnailUrl도 서버 원본 값이므로 이 단계에서는 String
//FestivalDTO에 id를 넣으면 안 됩니다. 서버가 주지 않는 값을 DTO에 만들면 DTO가 “서버 계약”이 아니게 됨

import Foundation

struct FestivalDTO: Decodable {
    let festivalId: Int64
    let name: String
    let region: String?
    let thumbnailURL: String
    let startDate: String
    let endDate: String

    enum CodingKeys: String, CodingKey {
        case festivalId
        case name
        case region
        case startDate
        case endDate
        case thumbnailURL = "thumbnailUrl"
    }
}
