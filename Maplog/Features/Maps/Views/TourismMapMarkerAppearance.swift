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
                color: color(0x2A6FDB),
                symbolName: "sparkles"
            )

        case .events:
            return TourismMapMarkerVisualStyle(
                color: color(0x7C5CFC),
                symbolName: "calendar"
            )

        case .festival:
            return TourismMapMarkerVisualStyle(
                color: color(0x7C5CFC),
                symbolName: "sparkles"
            )

        case .performance:
            return TourismMapMarkerVisualStyle(
                color: color(0xA05DE4),
                symbolName: "music.note"
            )

        case .event:
            return TourismMapMarkerVisualStyle(
                color: color(0x5E70D7),
                symbolName: "calendar.badge.star"
            )

        case .accommodation:
            return TourismMapMarkerVisualStyle(
                color: color(0x2A6FDB),
                symbolName: "bed.double.fill"
            )

        case .food:
            return TourismMapMarkerVisualStyle(
                color: color(0xE86C2F),
                symbolName: "fork.knife"
            )

        case .shopping:
            return TourismMapMarkerVisualStyle(
                color: color(0xEC6BB0),
                symbolName: "bag.fill"
            )

        case .recommendedCourse:
            return TourismMapMarkerVisualStyle(
                color: color(0x3B97A4),
                symbolName: "signpost.right.and.left.fill"
            )

        case .experienceTourism:
            return TourismMapMarkerVisualStyle(
                color: color(0xD98C42),
                symbolName: "figure.hiking"
            )

        case .historyTourism:
            return TourismMapMarkerVisualStyle(
                color: color(0x7B5E48),
                symbolName: "building.columns.fill"
            )

        case .leisureSports:
            return TourismMapMarkerVisualStyle(
                color: color(0x15967D),
                symbolName: "figure.run"
            )

        case .natureTourism:
            return TourismMapMarkerVisualStyle(
                color: color(0x4F9E64),
                symbolName: "leaf.fill"
            )

        case .culturalTourism:
            return TourismMapMarkerVisualStyle(
                color: color(0xB85C9D),
                symbolName: "paintpalette.fill"
            )

        case .unknown:
            return TourismMapMarkerVisualStyle(
                color: color(0x59616A),
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
