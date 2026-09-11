import SwiftUI

/// 홈 미리보기 전환은 화면 좌표로 보간하고, 진입 후에는 첫 릴스와 함께 스크롤한다.
enum HomeReelMetadataLayout {
    static func isVisible(pageTop: CGFloat, viewportHeight: CGFloat) -> Bool {
        viewportHeight > 0 && pageTop > -viewportHeight && pageTop < viewportHeight
    }

    static func verticalOffset(
        sourceY: CGFloat,
        authorY: CGFloat,
        pageTop: CGFloat,
        revealProgress: CGFloat
    ) -> CGFloat {
        // 음수 pageTop을 빼면 스크롤 이동이 취소되어 다음 릴스 위에 프로필이 남는다.
        guard pageTop > 0 else { return authorY }
        let destinationY = authorY - pageTop
        return sourceY + (destinationY - sourceY) * revealProgress
    }
}
