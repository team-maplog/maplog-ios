//
//  Tourism.swift
//  Maplog
//
//  Created by 한채림 on 7/21/26.
//

// 서버 JSON 그대로가 아니라, 앱이 사용할 관광 도메인 타입 모델

import Foundation

struct Tourism: Identifiable, Equatable, Sendable {
    let id: Int64
    let name: String
    let region: String?
    let address: String?
    let thumbnailURL: URL?
    let startDate: Date?
    let endDate: Date?
    let category: TourismCategory
}

//tourismId가 아니라 id: 서버 세부사항을 앱 전체로 퍼뜨리지 않기 위해서
//thumbnailURL: URL?: 서버의 문자열이 아니라, 앱에서 실제 이미지 요청에 쓸 URL 타입
