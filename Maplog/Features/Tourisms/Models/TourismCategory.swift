//
//  Untitled.swift
//  Maplog
//
//  Created by 한채림 on 7/23/26.
//

enum TourismCategory: String, Codable, CaseIterable, Hashable {
    case all = "ALL"

    case events = "EVENTS"
    case festival = "FESTIVAL"
    case performance = "PERFORMANCE"
    case event = "EVENT"

    case accommodation = "ACCOMMODATION"
    case food = "FOOD"
    case shopping = "SHOPPING"

    case recommendedCourse = "RECOMMENDED_COURSE"
    case experienceTourism = "EXPERIENCE_TOURISM"
    case historyTourism = "HISTORY_TOURISM"
    case leisureSports = "LEISURE_SPORTS"
    case natureTourism = "NATURE_TOURISM"
    case culturalTourism = "CULTURAL_TOURISM"
}

// String: 서버의 문자열 값과 연결
// Codable: 응답의 "category": "FOOD"를 자동 해석
// CaseIterable: 나중에 “전체보기에서 허용할 카테고리 목록”을 다룰 때 사용 가능
// Hashable: SwiftUI의 선택 상태나 ForEach 등에 안전하게 사용 가능
