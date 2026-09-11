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
    var clipCrops: [UUID: VideoClipCrop] = [:]

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

    /// 카메라에서 한 번에 구도를 잡아야 하는 실제 분할 칸의 가로/세로 비율입니다.
    /// export가 `.fill`로 넣는 대상 칸과 같은 비율을 돌려주므로, 미리보기와
    /// 완성 영상에서 보이는 중심 영역이 일치합니다.
    func captureFrameAspectRatio(for slotIndex: Int) -> CGFloat {
        let frames = layout.normalizedFrames(for: sceneOrientation)

        guard frames.indices.contains(slotIndex) else {
            return sceneOrientation.aspectRatio
        }

        let slot = frames[slotIndex]
        return sceneOrientation.aspectRatio * slot.width / slot.height
    }

    /// 설정 화면에서 보여 줄, 한 컷을 촬영할 때의 실제 프레임 비율입니다.
    var captureFrameRatioTitle: String {
        switch (sceneOrientation, layout) {
        case (.vertical, .single):
            return "9:16"
        case (.vertical, .splitTwo):
            return "9:8"
        case (.vertical, .splitThree):
            return "27:16"
        case (.horizontal, .single):
            return "16:9"
        case (.horizontal, .splitTwo):
            return "8:9"
        case (.horizontal, .splitThree):
            return "16:27"
        }
    }
}

/// 원본에서 보일 영역의 위치(0...1)와 확대 배율. 클립 ID를 키로 써 순서를 바꿔도 구도가 따라간다.
struct VideoClipCrop: Equatable, Sendable {
    let horizontalPosition: Double
    let verticalPosition: Double
    let zoom: Double
    let quarterTurns: Int

    init(horizontalPosition: Double = 0.5, verticalPosition: Double = 0.5, zoom: Double = 1, quarterTurns: Int = 0) {
        self.quarterTurns = ((quarterTurns % 4) + 4) % 4
        self.horizontalPosition = horizontalPosition.isFinite ? min(max(horizontalPosition, 0), 1) : 0.5
        self.verticalPosition = verticalPosition.isFinite ? min(max(verticalPosition, 0), 1) : 0.5
        self.zoom = zoom.isFinite ? min(max(zoom, 1), 3) : 1
    }

    func moved(by translation: CGSize, sourceSize: CGSize, slotSize: CGSize) -> VideoClipCrop {
        guard slotSize.width > 0, slotSize.height > 0 else { return self }
        let rect = sourceRect(in: CGRect(origin: .zero, size: sourceSize),
                              destinationAspectRatio: slotSize.width / slotSize.height)
        guard rect.width > 0 else { return self }
        let scale = slotSize.width / rect.width
        let travelX = (sourceSize.width - rect.width) * scale
        let travelY = (sourceSize.height - rect.height) * scale
        // 영상을 아래로 밀면 원본의 더 위쪽을 보게 되므로 크롭 위치는 반대로 이동한다.
        return VideoClipCrop(
            horizontalPosition: travelX > 0.001 ? horizontalPosition - translation.width / travelX : horizontalPosition,
            verticalPosition: travelY > 0.001 ? verticalPosition - translation.height / travelY : verticalPosition,
            zoom: zoom, quarterTurns: quarterTurns
        )
    }

    func sourceRect(in bounds: CGRect, destinationAspectRatio: CGFloat) -> CGRect {
        guard bounds.width > 0, bounds.height > 0, destinationAspectRatio > 0 else { return .zero }
        let width = min(bounds.width, bounds.height * destinationAspectRatio) / zoom
        let height = width / destinationAspectRatio
        return CGRect(
            x: bounds.minX + (bounds.width - width) * horizontalPosition,
            y: bounds.minY + (bounds.height - height) * verticalPosition,
            width: width,
            height: height
        )
    }
}
