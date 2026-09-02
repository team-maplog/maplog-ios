import Foundation

/// 댓글 작성 시각은 가장 큰 경과 단위 하나만 보여 주어 목록이 과도하게 세밀해지지 않게 합니다.
enum LogCommentRelativeTimeFormatter {
    static func text(
        for date: Date,
        relativeTo now: Date = .now
    ) -> String {
        let elapsedSeconds = max(0, Int(now.timeIntervalSince(date)))

        switch elapsedSeconds {
        case 0:
            return "방금 전"

        case ..<60:
            return "\(elapsedSeconds)초 전"

        case ..<3_600:
            return "\(elapsedSeconds / 60)분 전"

        case ..<86_400:
            return "\(elapsedSeconds / 3_600)시간 전"

        case ..<604_800:
            return "\(elapsedSeconds / 86_400)일 전"

        case ..<2_592_000:
            return "\(elapsedSeconds / 604_800)주 전"

        default:
            return "\(elapsedSeconds / 2_592_000)개월 전"
        }
    }
}
