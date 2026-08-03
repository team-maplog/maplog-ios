//
//  MaplogTab.swift
//  Maplog
//
//  Created by 한채림 on 7/22/26.
//

enum MaplogTab: String, CaseIterable, Identifiable {
    case home
    case capture
    case map
    case profile

    var id: String { rawValue }
    static var navigationTabs: [MaplogTab] {
        [.home, .map, .profile]
    }

    var title: String {
        switch self {
        case .home: return "홈"
        case .capture: return "촬영"
        case .map: return "지도"
        case .profile: return "마이"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .capture: return "camera.fill"
        case .map: return "map.fill"
        case .profile: return "person.fill"
        }
    }
}
