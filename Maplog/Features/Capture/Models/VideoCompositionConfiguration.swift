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
    /// Maplog 결과물은 항상 세로 릴스 캔버스로 저장합니다. 여기서 `direction`은
    /// 결과 영상의 가로·세로 비율이 아니라 분할선의 방향입니다. 실제 픽셀 크기는
    /// export 시 canvas 크기를 곱해 만듭니다.
    func normalizedFrames(
        for direction: VideoSplitDirection
    ) -> [CGRect] {
        switch self {
        case .single:
            return [CGRect(x: 0, y: 0, width: 1, height: 1)]

        case .splitTwo:
            switch direction {
            case .vertical:
                return [
                    CGRect(x: 0, y: 0, width: 1, height: 0.5),
                    CGRect(x: 0, y: 0.5, width: 1, height: 0.5)
                ]
            case .horizontal:
                return [
                    CGRect(x: 0, y: 0, width: 0.5, height: 1),
                    CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
                ]
            }

        case .splitThree:
            switch direction {
            case .vertical:
                return [
                    CGRect(x: 0, y: 0, width: 1, height: 1.0 / 3.0),
                    CGRect(x: 0, y: 1.0 / 3.0, width: 1, height: 1.0 / 3.0),
                    CGRect(x: 0, y: 2.0 / 3.0, width: 1, height: 1.0 / 3.0)
                ]
            case .horizontal:
                return [
                    CGRect(x: 0, y: 0, width: 1.0 / 3.0, height: 1),
                    CGRect(x: 1.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1),
                    CGRect(x: 2.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1)
                ]
            }
        }
    }
}

/// 분할 장면의 진행 방향입니다.
///
/// `vertical`은 첨부한 아이콘처럼 세로 화면을 위·아래로 쌓는 방식,
/// `horizontal`은 그 아이콘을 눕힌 것처럼 좌·우로 나누는 방식입니다.
enum VideoSplitDirection: String, CaseIterable, Equatable, Sendable, Identifiable {
    case vertical
    case horizontal

    var id: Self { self }

    var title: String {
        switch self {
        case .vertical:
            return "세로"
        case .horizontal:
            return "가로"
        }
    }

    var detail: String {
        switch self {
        case .vertical:
            return "위아래"
        case .horizontal:
            return "좌우"
        }
    }
}

struct VideoCompositionConfiguration: Equatable, Sendable {
    var layout: VideoCompositionLayout
    var splitDirection: VideoSplitDirection

    init(
        layout: VideoCompositionLayout = .single,
        splitDirection: VideoSplitDirection = .vertical
    ) {
        self.layout = layout
        self.splitDirection = splitDirection
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
