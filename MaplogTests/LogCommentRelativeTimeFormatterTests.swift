import Foundation
import XCTest
@testable import Maplog

final class LogCommentRelativeTimeFormatterTests: XCTestCase {
    func testShowsSecondsOnlyBeforeOneMinute() {
        let now = Date(timeIntervalSince1970: 1_000_000)

        XCTAssertEqual(
            LogCommentRelativeTimeFormatter.text(
                for: now.addingTimeInterval(-59),
                relativeTo: now
            ),
            "59초 전"
        )
        XCTAssertEqual(
            LogCommentRelativeTimeFormatter.text(
                for: now.addingTimeInterval(-60),
                relativeTo: now
            ),
            "1분 전"
        )
        XCTAssertEqual(
            LogCommentRelativeTimeFormatter.text(
                for: now.addingTimeInterval(-119),
                relativeTo: now
            ),
            "1분 전"
        )
    }

    func testUsesOnlyTheLargestUnitAfterOneHour() {
        let now = Date(timeIntervalSince1970: 1_000_000)

        XCTAssertEqual(
            LogCommentRelativeTimeFormatter.text(
                for: now.addingTimeInterval(-3_599),
                relativeTo: now
            ),
            "59분 전"
        )
        XCTAssertEqual(
            LogCommentRelativeTimeFormatter.text(
                for: now.addingTimeInterval(-3_600),
                relativeTo: now
            ),
            "1시간 전"
        )
        XCTAssertEqual(
            LogCommentRelativeTimeFormatter.text(
                for: now.addingTimeInterval(-7_200),
                relativeTo: now
            ),
            "2시간 전"
        )
    }
}
