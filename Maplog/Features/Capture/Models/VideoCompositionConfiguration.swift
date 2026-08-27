//
//  VideoCompositionConfiguration.swift
//  Maplog
//

import CoreGraphics
import Foundation

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

    /// 0~1 범위의 슬롯 좌표입니다.
    ///
    /// Maplog 결과물은 항상 세로 릴스 캔버스로 저장합니다. 가로로 촬영한 원본도
    /// 이 세로 캔버스 안에서 처리하고, 분할 화면은 위·아래가 아니라 세로 칸으로
    /// 나눕니다. 따라서 `3분할`은 세로 구분선 두 개가 있는 세 장면입니다.
    /// 실제 픽셀 크기는 export 시 canvas 크기를 곱해 만듭니다.
    var normalizedFrames: [CGRect] {
        switch self {
        case .single:
            return [CGRect(x: 0, y: 0, width: 1, height: 1)]

        case .splitTwo:
            return [
                CGRect(x: 0, y: 0, width: 0.5, height: 1),
                CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
            ]

        case .splitThree:
            return [
                CGRect(x: 0, y: 0, width: 1.0 / 3.0, height: 1),
                CGRect(x: 1.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1),
                CGRect(x: 2.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1)
            ]
        }
    }
}

struct VideoCompositionConfiguration: Equatable, Sendable {
    var layout: VideoCompositionLayout

    init(
        layout: VideoCompositionLayout = .single
    ) {
        self.layout = layout
    }

    var renderSize: CGSize {
        CGSize(width: 1_080, height: 1_920)
    }

    var aspectRatio: CGFloat {
        renderSize.width / renderSize.height
    }

    var requiredClipCount: Int {
        layout.requiredClipCount
    }
}
