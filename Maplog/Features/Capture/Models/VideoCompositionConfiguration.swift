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
    /// 이 좌표는 장면 영역 안에서만 쓰입니다. 실제 결과물은 항상 세로 릴스
    /// 캔버스에 저장하고, 가로 장면은 그 안에 16:9로 가운데 배치합니다.
    func normalizedFrames(
        for orientation: VideoSceneOrientation
    ) -> [CGRect] {
        switch self {
        case .single:
            return [CGRect(x: 0, y: 0, width: 1, height: 1)]

        case .splitTwo:
            switch orientation {
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
            switch orientation {
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

/// 완성 릴스 안에 놓을 장면의 비율입니다.
///
/// 세로 장면은 9:16 캔버스를 전부 쓰고, 가로 장면은 세로 릴스의 중앙에
/// 16:9로 배치됩니다. 따라서 가로 장면의 위·아래 여백은 검정으로 남습니다.
enum VideoSceneOrientation: String, CaseIterable, Equatable, Sendable, Identifiable {
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
            return "9:16"
        case .horizontal:
            return "16:9"
        }
    }

    var aspectRatio: CGFloat {
        switch self {
        case .vertical:
            return 9.0 / 16.0
        case .horizontal:
            return 16.0 / 9.0
        }
    }
}

struct VideoCompositionConfiguration: Equatable, Sendable {
    var layout: VideoCompositionLayout
    var sceneOrientation: VideoSceneOrientation

    init(
        layout: VideoCompositionLayout = .single,
        sceneOrientation: VideoSceneOrientation = .vertical
    ) {
        self.layout = layout
        self.sceneOrientation = sceneOrientation
    }

    var renderSize: CGSize {
        CGSize(width: 1_080, height: 1_920)
    }

    var aspectRatio: CGFloat {
        renderSize.width / renderSize.height
    }

    /// 가로 장면은 세로 결과물 안에서 가로 폭을 꽉 채우고 중앙에 놓습니다.
    /// 이 프레임 밖은 export의 검은 배경으로 그대로 남습니다.
    func sceneFrame(in canvasSize: CGSize) -> CGRect {
        let sceneAspectRatio = sceneOrientation.aspectRatio
        let canvasAspectRatio = canvasSize.width / canvasSize.height

        if sceneAspectRatio <= canvasAspectRatio {
            return CGRect(origin: .zero, size: canvasSize)
        }

        let sceneHeight = canvasSize.width / sceneAspectRatio
        return CGRect(
            x: 0,
            y: (canvasSize.height - sceneHeight) / 2,
            width: canvasSize.width,
            height: sceneHeight
        )
    }

    var sceneFrame: CGRect {
        sceneFrame(in: renderSize)
    }

    var requiredClipCount: Int {
        layout.requiredClipCount
    }
}
