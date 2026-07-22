//
//  TourismPageDTO.swift
//  Maplog
//
//  Created by 한채림 on 7/21/26.
//
//content라는 이름을 유지하는 이유는 JSON이 실제로 그렇게 내려오기 때문
//APIResponse<TourismPageDTO>
//  └─ data
//      ├─ content
//      ├─ hasNext
//      └─ nextCursor
//앱의 Domain Model인 TourismPage에서는 content가 아니라 tourisms를 사용. 서버 용어와 앱 용어가 분리되어야 백엔드 JSON이 바뀌어도 UI까지 흔들리지 않음

import Foundation

import Foundation

struct TourismPageDTO: Decodable {
    let content: [TourismDTO]
    let hasNext: Bool
    let nextCursor: String?
}
