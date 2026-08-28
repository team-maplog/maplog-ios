//
//  LogTag.swift
//  Maplog
//

import Foundation

/// 서버가 정의한 로그 분류 값과 화면에 보여 줄 한글 이름을 함께 관리합니다.
/// DTO에는 서버 원문(String)을 두고, 앱 안에서는 이 타입만 사용합니다.
enum LogTag: String, CaseIterable, Hashable, Sendable, Identifiable {
    case cafe = "CAFE"
    case restaurant = "RESTAURANT"
    case bakery = "BAKERY"
    case walk = "WALK"
    case date = "DATE"
    case nightView = "NIGHT_VIEW"
    case nature = "NATURE"
    case culture = "CULTURE"
    case exhibition = "EXHIBITION"
    case activity = "ACTIVITY"
    case healing = "HEALING"
    case petFriendly = "PET_FRIENDLY"
    case kidsFriendly = "KIDS_FRIENDLY"
    case shopping = "SHOPPING"
    case driving = "DRIVING"
    case travel = "TRAVEL"

    var id: Self { self }

    var title: String {
        switch self {
        case .cafe: return "카페"
        case .restaurant: return "맛집"
        case .bakery: return "베이커리"
        case .walk: return "산책"
        case .date: return "데이트"
        case .nightView: return "야경"
        case .nature: return "자연"
        case .culture: return "문화"
        case .exhibition: return "전시"
        case .activity: return "액티비티"
        case .healing: return "힐링"
        case .petFriendly: return "반려동물"
        case .kidsFriendly: return "아이와 함께"
        case .shopping: return "쇼핑"
        case .driving: return "드라이브"
        case .travel: return "여행"
        }
    }

    static func makeTags(from rawValues: [String]?) -> [LogTag] {
        (rawValues ?? []).compactMap(LogTag.init(rawValue:))
    }
}
