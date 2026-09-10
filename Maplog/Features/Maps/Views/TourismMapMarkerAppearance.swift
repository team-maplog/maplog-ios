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
    static func style(
        for category: TourismMapCategory
    ) -> TourismMapMarkerVisualStyle {
        switch category {
        case .all:
            return TourismMapMarkerVisualStyle(
                color: color(0x718BAA),
                symbolName: "sparkles"
            )

        case .events:
            return TourismMapMarkerVisualStyle(
                color: color(0x9387B6),
                symbolName: "calendar"
            )

        case .festival:
            return TourismMapMarkerVisualStyle(
                color: color(0x9387B6),
                symbolName: "sparkles"
            )

        case .performance:
            return TourismMapMarkerVisualStyle(
                color: color(0xA18CAF),
                symbolName: "music.note"
            )

        case .event:
            return TourismMapMarkerVisualStyle(
                color: color(0x7F8FB7),
                symbolName: "calendar.badge.star"
            )

        case .accommodation:
            return TourismMapMarkerVisualStyle(
                color: color(0x718BAA),
                symbolName: "bed.double.fill"
            )

        case .food:
            return TourismMapMarkerVisualStyle(
                color: color(0xBC826C),
                symbolName: "fork.knife"
            )

        case .shopping:
            return TourismMapMarkerVisualStyle(
                color: color(0xB78298),
                symbolName: "bag.fill"
            )

        case .recommendedCourse:
            return TourismMapMarkerVisualStyle(
                color: color(0x749B9D),
                symbolName: "signpost.right.and.left.fill"
            )

        case .experienceTourism:
            return TourismMapMarkerVisualStyle(
                color: color(0xAF9069),
                symbolName: "figure.hiking"
            )

        case .historyTourism:
            return TourismMapMarkerVisualStyle(
                color: color(0x978472),
                symbolName: "building.columns.fill"
            )

        case .leisureSports:
            return TourismMapMarkerVisualStyle(
                color: color(0x68958B),
                symbolName: "figure.run"
            )

        case .natureTourism:
            return TourismMapMarkerVisualStyle(
                color: color(0x7D9A7C),
                symbolName: "leaf.fill"
            )

        case .culturalTourism:
            return TourismMapMarkerVisualStyle(
                color: color(0xA783A2),
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
