//
//  TourismScheduleStatus.swift
//  Maplog
//
//  Created by 한채림 on 7/28/26.
//

import Foundation

enum TourismScheduleStatus: Equatable {
    case upcoming(daysRemaining: Int)
    case ongoing
    case ended
    case unavailable
}

enum TourismScheduleStatusCalculator {
    static func make(startDate: Date?, endDate: Date?, now: Date = Date()) -> TourismScheduleStatus {
        guard let startDate else {
            return .unavailable
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current

        let today = calendar.startOfDay(for: now)
        let start = calendar.startOfDay(for: startDate)
        let end = endDate
            .map { calendar.startOfDay(for: $0) }
            ?? start

        guard start <= end else {
            return .unavailable
        }

        if today < start {
            let daysRemaining = calendar.dateComponents(
                [.day],
                from: today,
                to: start
            ).day ?? 0

            return .upcoming(daysRemaining: daysRemaining)
        }

        if today <= end {
            return .ongoing
        }

        return .ended
    }
}
