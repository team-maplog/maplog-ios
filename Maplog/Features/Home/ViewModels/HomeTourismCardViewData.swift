//
//  HomeTourismCardViewData.swift
//  Maplog
//
//  Created by 한채림 on 7/21/26.
//
//Home 전용 관광 카드 모델
//View가 region == nil을 처리하거나 날짜를 문자열로 바꾸면 View가 너무 많은 일을 하게 됩니다. ViewModel이 이미 가공된 값을 주고, 카드는 그리기만 하게 만듦
//Tourism을 HomeTourismCardViewData로 바꾸는 함수이고, 홈 카드가 바로 보여 주기 편한 형태로 가공하기 위해 존재

import Foundation

struct HomeTourismCardViewData: Identifiable, Equatable {
    let id: Int64
    let title: String
    let locationText: String
    let periodText: String
    let dDayText: String?
    let poster: TourismPortraitImage
}

/// 좁은 홈 카드에서는 같은 연도의 기간을 간결하게 표시한다.
/// 연도가 바뀌는 행사는 양쪽 연도를 남겨 기간이 거꾸로 보이지 않게 한다.
enum HomeTourismPeriodFormatter {
    static func string(startDate: Date?, endDate: Date?) -> String {
        guard let startDate, let endDate else {
            return "기간 정보 없음"
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = calendar.component(.year, from: startDate)
            == calendar.component(.year, from: endDate)
            ? "MM.dd"
            : "yyyy.MM.dd"

        if calendar.isDate(startDate, inSameDayAs: endDate) {
            return formatter.string(from: startDate)
        }

        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }
}
