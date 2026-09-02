//
//  ExploreMapMarkerPreviewCard.swift
//  Maplog
//
//  Created by 한채림 on 8/25/26.
// 지도 탭의 하단 카드

import SwiftUI
import UIKit

struct ExploreMapMarkerPreviewCard: View {
    let marker: MapMarker
    let thumbnailData: Data?
    let isLoadingThumbnail: Bool

    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 12) {
                    thumbnail

                    VStack(alignment: .leading, spacing: 5) {
                        Text(markerTypeTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.maplogOlive)

                        Text(marker.title)
                            .font(.headline)
                            .foregroundStyle(Color.maplogInk)
                            .lineLimit(1)

                        if !marker.subtitle.isEmpty {
                            Text(marker.subtitle)
                                .font(.caption)
                                .foregroundStyle(Color.maplogMuted)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(marker.title) 상세 보기")
            .accessibilityHint("카드를 탭하면 상세 화면으로 이동합니다.")
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.maplogMuted)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("장소 카드 닫기")
        }
        .padding(12)
        .background(
            .regularMaterial,
            in: RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
        .shadow(
            color: .black.opacity(0.16),
            radius: 18,
            x: 0,
            y: 8
        )
    }

    @ViewBuilder
    private var thumbnail: some View {
        ZStack {
            if let thumbnailData,
               let image = UIImage(data: thumbnailData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()

            } else if isLoadingThumbnail {
                ProgressView()
                    .tint(Color.maplogOlive)

            } else {
                Image(systemName: fallbackImageName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 72, height: 72)
        .background(
            fallbackColor
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
        )
        .accessibilityLabel("\(marker.title) 미리보기")
    }

    private var markerTypeTitle: String {
        switch marker {
        case .log:
            return "맵로그"

        case let .tourism(tourismMarker):
            return tourismMarker.category.title
        }
    }

    private var fallbackImageName: String {
        switch marker {
        case .log:
            return "play.fill"

        case let .tourism(tourismMarker):
            return TourismMapMarkerAppearance.style(
                for: tourismMarker.category
            )
            .symbolName
        }
    }

    private var fallbackColor: Color {
        switch marker {
        case .log:
            return Color.maplogOlive

        case let .tourism(tourismMarker):
            return Color(
                uiColor: TourismMapMarkerAppearance.style(
                    for: tourismMarker.category
                )
                .color
            )
        }
    }
}
