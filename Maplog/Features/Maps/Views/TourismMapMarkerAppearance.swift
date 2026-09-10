//
//  TourismMapMarkerAppearance.swift
//  Maplog
//
//  관광 marker와 필터 칩이 같은 카테고리 색·아이콘을 쓰도록 하는 UI 전용 스타일
//

import UIKit

struct TourismMapMarkerVisualStyle {
    let color: UIColor
    let symbolName: String
}

enum TourismMapMarkerAppearance {
    // 카테고리는 색상으로 구분하되 시그니처 라임과 어울리는 선명한 채도를 사용합니다.
    static func style(
        for category: TourismMapCategory
    ) -> TourismMapMarkerVisualStyle {
        switch category {
        case .all:
            return TourismMapMarkerVisualStyle(
                color: color(0x2878F0),
                symbolName: "sparkles"
            )

        case .events:
            return TourismMapMarkerVisualStyle(
                color: color(0x794DFF),
                symbolName: "calendar"
            )

        case .festival:
            return TourismMapMarkerVisualStyle(
                color: color(0x794DFF),
                symbolName: "sparkles"
            )

        case .performance:
            return TourismMapMarkerVisualStyle(
                color: color(0xB737F0),
                symbolName: "music.note"
            )

        case .event:
            return TourismMapMarkerVisualStyle(
                color: color(0x4964F5),
                symbolName: "calendar.badge.star"
            )

        case .accommodation:
            return TourismMapMarkerVisualStyle(
                color: color(0x2878F0),
                symbolName: "bed.double.fill"
            )

        case .food:
            return TourismMapMarkerVisualStyle(
                color: color(0xF56A24),
                symbolName: "fork.knife"
            )

        case .shopping:
            return TourismMapMarkerVisualStyle(
                color: color(0xF03C86),
                symbolName: "bag.fill"
            )

        case .recommendedCourse:
            return TourismMapMarkerVisualStyle(
                color: color(0x00ACA7),
                symbolName: "signpost.right.and.left.fill"
            )

        case .experienceTourism:
            return TourismMapMarkerVisualStyle(
                color: color(0xEFA900),
                symbolName: "figure.hiking"
            )

        case .historyTourism:
            return TourismMapMarkerVisualStyle(
                color: color(0xC77B15),
                symbolName: "building.columns.fill"
            )

        case .leisureSports:
            return TourismMapMarkerVisualStyle(
                color: color(0x00AD7B),
                symbolName: "figure.run"
            )

        case .natureTourism:
            return TourismMapMarkerVisualStyle(
                color: color(0x75C900),
                symbolName: "leaf.fill"
            )

        case .culturalTourism:
            return TourismMapMarkerVisualStyle(
                color: color(0xDB39BD),
                symbolName: "paintpalette.fill"
            )

        case .unknown:
            return TourismMapMarkerVisualStyle(
                color: color(0x8A929B),
                symbolName: "mappin.and.ellipse"
            )
        }
    }

    private static func color(
        _ hex: UInt32
    ) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
