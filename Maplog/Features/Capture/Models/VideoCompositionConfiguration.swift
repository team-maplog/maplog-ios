//
//  VideoCompositionConfiguration.swift
//  Maplog
//

import CoreGraphics
import Foundation

/// 최종 영상이 놓일 캔버스의 방향입니다.
///
/// 촬영 기기를 어떻게 들었는지와 별개로, 편집 결과를 세로 릴스 또는
/// 가로 영상 중 어느 형태로 내보낼지를 나타냅니다.
enum VideoCanvasOrientation: String, CaseIterable, Equatable, Sendable, Identifiable {
    case portrait
    case landscape

    var id: Self { self }

    var title: String {
        switch self {
        case .portrait:
            return "세로"
        case .landscape:
            return "가로"
        }
    }

    var systemImage: String {
        switch self {
        case .portrait:
            return "rectangle.portrait"
        case .landscape:
            return "rectangle"
        }
    }

    var renderSize: CGSize {
        switch self {
        case .portrait:
            return CGSize(width: 1_080, height: 1_920)
        case .landscape:
            return CGSize(width: 1_920, height: 1_080)
        }
    }

    var aspectRatio: CGFloat {
        renderSize.width / renderSize.height
    }
}

/// 여러 클립을 시간 순서대로 잇거나, 하나의 화면에 나눠 배치하는 방식입니다.
enum VideoCompositionLayout: String, CaseIterable, Equatable, Sendable, Identifiable {
    case single
    case splitTwo
    case splitThree

    var id: Self { self }

    var title: String {
        switch self {
        case .single:
            return "일반"
        case .splitTwo:
            return "2분할"
        case .splitThree:
            return "3분할"
        }
    }

    var detail: String {
        switch self {
        case .single:
            return "선택한 순서대로 이어 붙여요"
        case .splitTwo:
            return "두 장면을 한 화면에 담아요"
        case .splitThree:
            return "세 장면을 한 화면에 담아요"
        }
    }

    var requiredClipCount: Int {
        switch self {
        case .single:
            return 1
        case .splitTwo:
            return 2
        case .splitThree:
            return 3
        }
    }

    var maximumClipCount: Int? {
        switch self {
        case .single:
            return nil
        case .splitTwo, .splitThree:
            return requiredClipCount
        }
    }

    /// 0~1 범위의 슬롯 좌표입니다. 실제 픽셀 크기는 export 시 canvas 크기를 곱해 만듭니다.
    func normalizedFrames(
        for orientation: VideoCanvasOrientation
    ) -> [CGRect] {
        switch (self, orientation) {
        case (.single, _):
            return [CGRect(x: 0, y: 0, width: 1, height: 1)]

        case (.splitTwo, .portrait):
            return [
                CGRect(x: 0, y: 0, width: 1, height: 0.5),
                CGRect(x: 0, y: 0.5, width: 1, height: 0.5)
            ]

        case (.splitTwo, .landscape):
            return [
                CGRect(x: 0, y: 0, width: 0.5, height: 1),
                CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
            ]

        case (.splitThree, .portrait):
            return [
                CGRect(x: 0, y: 0, width: 1, height: 0.5),
                CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5),
                CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
            ]

        case (.splitThree, .landscape):
            return [
                CGRect(x: 0, y: 0, width: 0.5, height: 1),
                CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5),
                CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
            ]
        }
    }
}

struct VideoCompositionConfiguration: Equatable, Sendable {
    var layout: VideoCompositionLayout
    var canvasOrientation: VideoCanvasOrientation

    init(
        layout: VideoCompositionLayout = .single,
        canvasOrientation: VideoCanvasOrientation = .portrait
    ) {
        self.layout = layout
        self.canvasOrientation = canvasOrientation
    }

    var renderSize: CGSize {
        canvasOrientation.renderSize
    }

    var aspectRatio: CGFloat {
        canvasOrientation.aspectRatio
    }

    var requiredClipCount: Int {
        layout.requiredClipCount
    }
}
