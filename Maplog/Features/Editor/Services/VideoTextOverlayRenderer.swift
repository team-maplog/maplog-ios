//
//  VideoTextOverlayRenderer.swift
//  Maplog
//
//  Created by 한채림 on 8/9/26.
// 영상 파일에 자막을 그리는 기술 작업

//parentLayer
// ├─ videoLayer       ← 원본 영상
// ├─ timeLayer        ← 시간 자막
// ├─ miniVlogLayer    ← mini vlog 자막
// └─ locationLayer    ← 장소 자막
//parentLayer: 최종 영상 전체 캔버스
//└─ videoLayer: 합쳐진 원본 영상이 들어갈 자리

import AVFoundation
import CoreText
import QuartzCore
import UIKit

protocol VideoTextOverlayRendering: Sendable {
    func makeAnimationTool(
        overlays: [ClipTextOverlay],
        timeline: ClipEditorTimeline,
        renderSize: CGSize
    ) -> AVVideoCompositionCoreAnimationTool?
}

struct VideoTextOverlayRenderer: VideoTextOverlayRendering {
    func makeAnimationTool(
        overlays: [ClipTextOverlay],
        timeline: ClipEditorTimeline,
        renderSize: CGSize
    ) -> AVVideoCompositionCoreAnimationTool? {
        guard !overlays.isEmpty, timeline.totalDuration > 0 else {
                    return nil
                }

                let parentLayer = CALayer()
                parentLayer.frame = CGRect(
                    origin: .zero,
                    size: renderSize
                )
                parentLayer.isGeometryFlipped = true

                let videoLayer = CALayer()
                videoLayer.frame = parentLayer.bounds
        
        parentLayer.addSublayer(videoLayer)
        
        // 자막 추가
        for overlay in overlays {
            guard let segment = timeline.segments.first(
                where: { $0.clipID == overlay.clipID }
            ) else {
                continue
            }
            
            let localStartTime = min(
                max(overlay.startTime, 0),
                segment.duration
            )
            
            let localEndTime = min(
                max(overlay.endTime, localStartTime),
                segment.duration
            )
            
            let globalStartTime = segment.startTime + localStartTime
            let globalEndTime = segment.startTime + localEndTime
            
            guard globalEndTime > globalStartTime,
                  let textLayer = makeTextLayer(
                    for: overlay,
                    renderSize: renderSize
                  )
            else {
                continue
            }
            
            textLayer.opacity = 0
            
            let visibilityAnimation = makeVisibilityAnimation(
                startTime: globalStartTime,
                endTime: globalEndTime
            )
            
            textLayer.add(
                visibilityAnimation,
                forKey: "overlayVisibility"
            )
            
            parentLayer.addSublayer(textLayer)
        }
        
        return AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )
    }
    
    private func makeTextLayer(
            for overlay: ClipTextOverlay,
            renderSize: CGSize
        ) -> CALayer? {
            let text = overlay.text.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard !text.isEmpty else {
                return nil
            }

            let editorReferenceWidth: CGFloat = 390
            let fontScale = renderSize.width / editorReferenceWidth

            let font = makeFont(
                style: overlay.style,
                scale: fontScale
            )

            let maximumWidth = renderSize.width * 0.75

            let measuredTextSize = (text as NSString).boundingRect(
                with: CGSize(
                    width: maximumWidth,
                    height: .greatestFiniteMagnitude
                ),
                options: [
                    .usesLineFragmentOrigin,
                    .usesFontLeading
                ],
                attributes: [
                    .font: font
                ],
                context: nil
            ).integral.size

            let horizontalInset: CGFloat
            let verticalInset: CGFloat

            switch overlay.style.containerStyle {
            case .none:
                horizontalInset = 0
                verticalInset = 0

            case .glass:
                horizontalInset = 8 * fontScale
                verticalInset = 6 * fontScale
            }

            let containerSize = CGSize(
                width: measuredTextSize.width + (horizontalInset * 2),
                height: measuredTextSize.height + (verticalInset * 2)
            )

            let containerLayer = CALayer()
            containerLayer.isGeometryFlipped = true
            containerLayer.bounds = CGRect(
                origin: .zero,
                size: containerSize
            )

            let textLayer = CATextLayer()
            textLayer.string = text
            textLayer.font = CTFontCreateWithName(
                font.fontName as CFString,
                font.pointSize,
                nil
            )
            textLayer.fontSize = font.pointSize
            textLayer.foregroundColor = makeTextColor(
                for: overlay.style.color
            ).cgColor
            textLayer.contentsScale = 2
            textLayer.isWrapped = true
            textLayer.frame = CGRect(
                x: horizontalInset,
                y: verticalInset,
                width: measuredTextSize.width,
                height: measuredTextSize.height
            )

            let x = CGFloat(overlay.position.x) * renderSize.width
            let y = CGFloat(overlay.position.y) * renderSize.height

            switch overlay.alignment {
            case .leading:
                containerLayer.anchorPoint = CGPoint(x: 0, y: 0.5)
                textLayer.alignmentMode = .left

            case .center:
                containerLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                textLayer.alignmentMode = .center

            case .trailing:
                containerLayer.anchorPoint = CGPoint(x: 1, y: 0.5)
                textLayer.alignmentMode = .right
            }

            containerLayer.position = CGPoint(x: x, y: y)

            switch overlay.style.containerStyle {
            case .none:
                containerLayer.backgroundColor = UIColor.clear.cgColor

            case .glass:
                containerLayer.backgroundColor = UIColor.white
                    .withAlphaComponent(0.22)
                    .cgColor
                containerLayer.cornerRadius = 16 * fontScale
                containerLayer.borderWidth = 1 * fontScale
                containerLayer.borderColor = UIColor.white
                    .withAlphaComponent(0.55)
                    .cgColor
            }

            containerLayer.addSublayer(textLayer)

            return containerLayer
        }
    
    // 자막 등장 퇴장 애니메이션 메서드
    private func makeVisibilityAnimation(
        startTime: TimeInterval,
        endTime: TimeInterval
    ) -> CAAnimationGroup {
        let visibleDuration = endTime - startTime
        let fadeDuration = min(
            1.0 / 30.0,
            visibleDuration / 2
        )

        let fadeIn = CABasicAnimation(
            keyPath: "opacity"
        )
        fadeIn.fromValue = 0
        fadeIn.toValue = 1
        fadeIn.beginTime = 0
        fadeIn.duration = fadeDuration

        let hold = CABasicAnimation(
            keyPath: "opacity"
        )
        hold.fromValue = 1
        hold.toValue = 1
        hold.beginTime = fadeDuration
        hold.duration = max(
            visibleDuration - (fadeDuration * 2),
            0
        )

        let fadeOut = CABasicAnimation(
            keyPath: "opacity"
        )
        fadeOut.fromValue = 1
        fadeOut.toValue = 0
        fadeOut.beginTime = max(
            visibleDuration - fadeDuration,
            fadeDuration
        )
        fadeOut.duration = fadeDuration

        let group = CAAnimationGroup()
        group.animations = [
            fadeIn,
            hold,
            fadeOut
        ]
        group.beginTime = AVCoreAnimationBeginTimeAtZero + startTime
        group.duration = visibleDuration
        group.fillMode = .both
        group.isRemovedOnCompletion = false

        return group
    }
    
    private func makeFont(
        style: ClipTextStyle,
        scale: CGFloat
    ) -> UIFont {
        let fontSize = CGFloat(style.fontSize) * scale

        let baseFont = UIFont.systemFont(
            ofSize: fontSize,
            weight: fontWeight(for: style.weight)
        )

        let descriptor: UIFontDescriptor

        switch style.font {
        case .standard:
            descriptor = baseFont.fontDescriptor

        case .rounded:
            descriptor = baseFont.fontDescriptor.withDesign(
                .rounded
            ) ?? baseFont.fontDescriptor

        case .serif:
            descriptor = baseFont.fontDescriptor.withDesign(
                .serif
            ) ?? baseFont.fontDescriptor

        case .monospaced:
            descriptor = baseFont.fontDescriptor.withDesign(
                .monospaced
            ) ?? baseFont.fontDescriptor
        }

        return UIFont(
            descriptor: descriptor,
            size: baseFont.pointSize
        )
    }

    private func fontWeight(
        for weight: ClipTextWeight
    ) -> UIFont.Weight {
        switch weight {
        case .regular:
            return .regular

        case .medium:
            return .medium

        case .semibold:
            return .semibold

        case .bold:
            return .bold
        }
    }
    
    private func makeTextColor(
        for color: ClipTextColor
    ) -> UIColor {
        switch color {
        case .white:
            return .white

        case .black:
            return .black

        case .maplogLime:
            return UIColor(
                named: "MaplogAccent"
            ) ?? .white

        case .warmYellow:
            return UIColor(
                red: 1,
                green: 0.82,
                blue: 0.2,
                alpha: 1
            )

        case .coral:
            return UIColor(
                red: 1,
                green: 0.35,
                blue: 0.3,
                alpha: 1
            )

        case .pink:
            return UIColor(
                red: 1,
                green: 0.42,
                blue: 0.65,
                alpha: 1
            )

        case .lavender:
            return UIColor(
                red: 0.68,
                green: 0.58,
                blue: 1,
                alpha: 1
            )

        case .skyBlue:
            return UIColor(
                red: 0.28,
                green: 0.65,
                blue: 1,
                alpha: 1
            )

        case .mint:
            return UIColor(
                red: 0.28,
                green: 0.9,
                blue: 0.7,
                alpha: 1
            )
        }
    }
}

//편집 화면의 ClipTextStyle
// ├─ font        → standard / rounded / serif / monospaced
// ├─ weight      → regular / medium / semibold / bold
// ├─ color       → 9가지 색상
// └─ fontSize    → 영상 해상도에 맞춰 확대
