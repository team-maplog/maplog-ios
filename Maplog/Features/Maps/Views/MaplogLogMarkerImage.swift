import SwiftUI
import UIKit

/// 탐색 지도와 릴스 경로 지도에서 같은 사진 마커를 사용한다. 경로만 순번을 추가한다.
enum MaplogLogMarkerImage {
    static func image(
        thumbnailData: Data?,
        isSelected: Bool,
        sequence: Int? = nil
    ) -> UIImage {
        let cardSize = CGSize(
            width: isSelected ? 36 : 30,
            height: isSelected ? 40 : 34
        )
        let pointerHeight: CGFloat = isSelected ? 6 : 5
        let canvasInset: CGFloat = 1
        let size = CGSize(
            width: cardSize.width + canvasInset * 2,
            height: cardSize.height + pointerHeight + canvasInset
        )
        let cardRect = CGRect(
            x: canvasInset,
            y: canvasInset,
            width: cardSize.width,
            height: cardSize.height
        )
        let cardPath = UIBezierPath(
            roundedRect: cardRect,
            cornerRadius: isSelected ? 9 : 7
        )
        let pointerPath = UIBezierPath()
        pointerPath.move(
            to: CGPoint(
                x: cardRect.midX - (isSelected ? 5 : 4),
                y: cardRect.maxY - 1
            )
        )
        pointerPath.addLine(
            to: CGPoint(
                x: cardRect.midX,
                y: size.height
            )
        )
        pointerPath.addLine(
            to: CGPoint(
                x: cardRect.midX + (isSelected ? 5 : 4),
                y: cardRect.maxY - 1
            )
        )
        pointerPath.close()

        return UIGraphicsImageRenderer(size: size).image { context in
            let graphicsContext = context.cgContext

            graphicsContext.saveGState()
            graphicsContext.setShadow(
                offset: CGSize(width: 0, height: 1),
                blur: 2,
                color: UIColor.black.withAlphaComponent(0.16).cgColor
            )
            UIColor.white.setFill()
            cardPath.fill()
            pointerPath.fill()
            graphicsContext.restoreGState()

            let imageRect = cardRect.insetBy(dx: 1.5, dy: 1.5)
            let imagePath = UIBezierPath(
                roundedRect: imageRect,
                cornerRadius: isSelected ? 7.5 : 5.5
            )

            graphicsContext.saveGState()
            imagePath.addClip()

            if let thumbnailData,
               let thumbnailImage = UIImage(data: thumbnailData) {
                drawAspectFill(
                    thumbnailImage,
                    in: imageRect
                )
            } else {
                UIColor(
                    red: 0.25,
                    green: 0.29,
                    blue: 0.25,
                    alpha: 1
                )
                .setFill()
                graphicsContext.fill(imageRect)

                let symbolSize: CGFloat = isSelected ? 14 : 12
                UIImage(
                    systemName: "play.fill",
                    withConfiguration: UIImage.SymbolConfiguration(
                        pointSize: symbolSize,
                        weight: .bold
                    )
                )?
                .withTintColor(
                    .white,
                    renderingMode: .alwaysOriginal
                )
                .draw(
                    in: CGRect(
                        x: imageRect.midX - symbolSize / 2,
                        y: imageRect.midY - symbolSize / 2,
                        width: symbolSize,
                        height: symbolSize
                    )
                )
            }

            graphicsContext.restoreGState()

            (
                isSelected
                    ? UIColor(
                        red: 0.220,
                        green: 0.396,
                        blue: 0.541,
                        alpha: 1
                    )
                    : UIColor.white
            )
            .setStroke()
            cardPath.lineWidth = isSelected ? 2 : 1
            cardPath.stroke()
            pointerPath.lineWidth = isSelected ? 2 : 1
            pointerPath.stroke()

            if let sequence {
                drawSequenceBadge(sequence, in: cardRect)
            }
        }
    }

    private static func drawSequenceBadge(_ sequence: Int, in cardRect: CGRect) {
        let text = String(sequence)
        let font = UIFont.systemFont(ofSize: 9, weight: .bold)
        let textSize = text.size(withAttributes: [.font: font])
        let badgeSize = CGSize(width: max(16, textSize.width + 6), height: 16)
        let badgeRect = CGRect(
            x: cardRect.maxX - badgeSize.width,
            y: cardRect.minY,
            width: badgeSize.width,
            height: badgeSize.height
        )
        UIColor(Color.maplogLime).setFill()
        UIBezierPath(roundedRect: badgeRect, cornerRadius: 8).fill()
        text.draw(
            at: CGPoint(x: badgeRect.midX - textSize.width / 2, y: badgeRect.midY - textSize.height / 2),
            withAttributes: [.font: font, .foregroundColor: UIColor.black]
        )
    }

    private static func drawAspectFill(
        _ image: UIImage,
        in rect: CGRect
    ) {
        let scale = max(
            rect.width / image.size.width,
            rect.height / image.size.height
        )
        let drawSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        let drawRect = CGRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )

        image.draw(in: drawRect)
    }

}
