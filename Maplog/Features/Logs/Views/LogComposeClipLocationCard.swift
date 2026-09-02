//
//  LogComposeClipLcationCard.swift
//  Maplog
//
//  Created by 한채림 on 8/9/26.
//  실제 카드 View

import SwiftUI
import UIKit

struct LogComposeClipLocationCard: View {
    let thumbnailData: Data?
    let timeRangeText: String
    let locationText: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: MaplogSpacing.small) {
                thumbnail

                VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                    Text(timeRangeText)
                        .font(MaplogFont.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color.maplogTextSecondary)

                    MaplogLocationLabel(
                        title: locationText,
                        pinSize: 14
                    )
                        .font(MaplogFont.bodyStrong)
                        .foregroundStyle(Color.maplogTextPrimary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: MaplogSize.iconSmall, weight: .semibold))
                    .foregroundStyle(Color.maplogTextTertiary)
            }
            .padding(MaplogSpacing.xSmall)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .maplogCard()
        .accessibilityLabel("\(timeRangeText), \(locationText)")
        .accessibilityHint("클립 장소 수정")
    }

    @ViewBuilder
    private var thumbnail: some View {
        if
            let thumbnailData,
            let image = UIImage(data: thumbnailData)
        {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: MaplogRadius.medium,
                        style: .continuous
                    )
                )
        } else {
            Color.maplogSurfaceRaised
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "video.fill")
                        .foregroundStyle(Color.maplogTextTertiary)
                }
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: MaplogRadius.medium,
                        style: .continuous
                    )
                )
        }
    }
}
