import SwiftUI

/// 홈 소개의 가변 높이 뒤에 이어지는 전체 화면 릴스의 시작점에 정렬한다.
struct HomeReelScrollBehavior: ScrollTargetBehavior {
    let introHeight: CGFloat
    let pageHeight: CGFloat

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard introHeight > 0, pageHeight > 0 else { return }
        target.rect.origin.y = alignedOffset(
            proposedOffset: target.rect.minY,
            maximumOffset: max(0, context.contentSize.height - context.containerSize.height)
        )
        target.anchor = .top
    }

    func alignedOffset(proposedOffset: CGFloat, maximumOffset: CGFloat) -> CGFloat {
        guard introHeight > 0, pageHeight > 0, maximumOffset > 0 else { return 0 }

        // 소개 영역은 한 화면보다 짧을 수 있어 0부터 paging하면 릴스 경계와 어긋난다.
        if proposedOffset < introHeight / 2 { return 0 }
        let page = max(0, ((proposedOffset - introHeight) / pageHeight).rounded())
        return min(introHeight + page * pageHeight, maximumOffset)
    }
}
