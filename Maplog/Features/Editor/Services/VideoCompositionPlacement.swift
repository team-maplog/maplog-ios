//
//  VideoCompositionPlacement.swift
//  Maplog
//
//  원본 영상의 회전 메타데이터를 반영해 export와 편집 미리보기에 같은 배치를 적용한다.
//

import AVFoundation
import CoreGraphics

enum VideoSlotContentMode {
    case fit
    case fill
}

struct VideoPlacement {
    let sourceCropRect: CGRect?
    let transform: CGAffineTransform
}

enum VideoCompositionPlacement {
    static func make(
        for sourceVideoTrack: AVAssetTrack,
        in destinationFrame: CGRect,
        contentMode: VideoSlotContentMode
    ) async throws -> VideoPlacement {
        let naturalSize = try await sourceVideoTrack.load(.naturalSize)
        let preferredTransform = try await sourceVideoTrack.load(
            .preferredTransform
        )
        let transformedBounds = CGRect(
            origin: .zero,
            size: naturalSize
        ).applying(preferredTransform)
        let orientedWidth = abs(transformedBounds.width)
        let orientedHeight = abs(transformedBounds.height)

        guard
            orientedWidth > 0,
            orientedHeight > 0,
            destinationFrame.width > 0,
            destinationFrame.height > 0
        else {
            throw VideoExportServiceError.sourceVideoUnavailable
        }

        let sourceAspectRatio = orientedWidth / orientedHeight
        let destinationAspectRatio = destinationFrame.width
            / destinationFrame.height

        let orientedSourceRect: CGRect
        let sourceCropRect: CGRect?

        switch contentMode {
        case .fit:
            orientedSourceRect = transformedBounds
            sourceCropRect = nil

        case .fill:
            let orientedCropSize: CGSize
            if sourceAspectRatio > destinationAspectRatio {
                orientedCropSize = CGSize(
                    width: orientedHeight * destinationAspectRatio,
                    height: orientedHeight
                )
            } else {
                orientedCropSize = CGSize(
                    width: orientedWidth,
                    height: orientedWidth / destinationAspectRatio
                )
            }

            orientedSourceRect = CGRect(
                x: transformedBounds.midX - orientedCropSize.width / 2,
                y: transformedBounds.midY - orientedCropSize.height / 2,
                width: orientedCropSize.width,
                height: orientedCropSize.height
            )

            let sourceBounds = CGRect(origin: .zero, size: naturalSize)
            sourceCropRect = orientedSourceRect
                .applying(preferredTransform.inverted())
                .standardized
                .intersection(sourceBounds)
        }

        let scale: CGFloat
        let targetOrigin: CGPoint

        switch contentMode {
        case .fit:
            scale = min(
                destinationFrame.width / orientedSourceRect.width,
                destinationFrame.height / orientedSourceRect.height
            )
            targetOrigin = CGPoint(
                x: destinationFrame.midX
                    - orientedSourceRect.width * scale / 2,
                y: destinationFrame.midY
                    - orientedSourceRect.height * scale / 2
            )

        case .fill:
            scale = destinationFrame.width / orientedSourceRect.width
            targetOrigin = destinationFrame.origin
        }

        var transform = preferredTransform
        transform = transform.concatenating(
            CGAffineTransform(
                translationX: -orientedSourceRect.minX,
                y: -orientedSourceRect.minY
            )
        )
        transform = transform.concatenating(
            CGAffineTransform(scaleX: scale, y: scale)
        )
        transform = transform.concatenating(
            CGAffineTransform(
                translationX: targetOrigin.x,
                y: targetOrigin.y
            )
        )

        return VideoPlacement(
            sourceCropRect: sourceCropRect,
            transform: transform
        )
    }
}
