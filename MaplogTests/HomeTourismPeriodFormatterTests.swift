import Foundation
import XCTest
@testable import Maplog

final class HomeTourismPeriodFormatterTests: XCTestCase {
    func testSameYearOmitsRepeatedYear() {
        XCTAssertEqual(
            HomeTourismPeriodFormatter.string(
                startDate: date("2026-09-18T00:00:00+09:00"),
                endDate: date("2026-09-20T00:00:00+09:00")
            ),
            "09.18 – 09.20"
        )
    }

    func testCrossYearKeepsBothYears() {
        XCTAssertEqual(
            HomeTourismPeriodFormatter.string(
                startDate: date("2026-12-31T00:00:00+09:00"),
                endDate: date("2027-01-02T00:00:00+09:00")
            ),
            "2026.12.31 – 2027.01.02"
        )
    }

    func testSingleDayUsesKoreanCalendarDate() {
        XCTAssertEqual(
            HomeTourismPeriodFormatter.string(
                startDate: date("2026-09-17T15:00:00Z"),
                endDate: date("2026-09-18T14:59:00Z")
            ),
            "09.18"
        )
    }

    func testIncompletePeriodDoesNotInventDate() {
        let knownDate = date("2026-09-18T00:00:00+09:00")
        for dates in [(knownDate, nil), (nil, knownDate), (nil, nil)] {
            XCTAssertEqual(
                HomeTourismPeriodFormatter.string(startDate: dates.0, endDate: dates.1),
                "기간 정보 없음"
            )
        }
    }

    private func date(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }
}
