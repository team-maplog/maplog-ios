//
//  VideoRenderCanvas.swift
//  Maplog
//
//  Created by 한채림 on 8/15/26.
// 공통 영상 캔버스

import CoreGraphics

enum VideoRenderCanvas {
    // 최종으로 내보내는 세로 영상의 실제 기준 크기
    static let standardPortraitSize = CGSize(
        width: 1_080,
        height: 1_920
    )

    static let standardPortraitAspectRatio =
        standardPortraitSize.width / standardPortraitSize.height

    // 홈 릴스와 편집기에서 공통으로 사용할 하단 영역 높이
    // 재생 바 + 탭 바가 들어갈 자리
    static let reelBottomTrayHeight: CGFloat = 114

    static func reelMediaSize(
        in containerSize: CGSize
    ) -> CGSize {
        CGSize(
            width: containerSize.width,
            height: max(
                0,
                containerSize.height - reelBottomTrayHeight
            )
        )
    }

    static func reelBottomTrayHeight(
        in containerSize: CGSize
    ) -> CGFloat {
        containerSize.height - reelMediaSize(
            in: containerSize
        ).height
    }
}

// 화면에 보이는 영상 영역과,
// 실제 9:16 원본 영상 좌표를 서로 바꿔 주는 도구
struct VideoRenderViewport {
    let viewportSize: CGSize

    private var scale: CGFloat {
        max(
            viewportSize.width
                / VideoRenderCanvas.standardPortraitSize.width,
            viewportSize.height
                / VideoRenderCanvas.standardPortraitSize.height
        )
    }

    private var renderedVideoSize: CGSize {
        CGSize(
            width: VideoRenderCanvas.standardPortraitSize.width * scale,
            height: VideoRenderCanvas.standardPortraitSize.height * scale
        )
    }

    private var renderedVideoOrigin: CGPoint {
        CGPoint(
            x: (
                viewportSize.width
                    - renderedVideoSize.width
            ) / 2,
            y: (
                viewportSize.height
                    - renderedVideoSize.height
            ) / 2
        )
    }

    // 저장된 0~1 비율 좌표를
    // 현재 화면에서의 실제 CGPoint로 바꾼다.
    func point(
        for position: ClipOverlayPosition
    ) -> CGPoint {
        CGPoint(
            x: renderedVideoOrigin.x
                + CGFloat(position.x) * renderedVideoSize.width,
            y: renderedVideoOrigin.y
                + CGFloat(position.y) * renderedVideoSize.height
        )
    }

    // 사용자가 화면에서 드래그한 CGPoint를
    // 최종 영상에 저장할 0~1 비율 좌표로 바꾼다.
    func position(
        for point: CGPoint
    ) -> ClipOverlayPosition {
        ClipOverlayPosition(
            x: Double(
                (point.x - renderedVideoOrigin.x)
                    / renderedVideoSize.width
            ),
            y: Double(
                (point.y - renderedVideoOrigin.y)
                    / renderedVideoSize.height
            )
        )
    }
}
