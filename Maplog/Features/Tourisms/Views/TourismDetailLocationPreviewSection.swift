//
//  TourismDetailLocationPreviewSection.swift
//  Maplog
//
//  Created by 한채림 on 7/28/26.
// 상세 화면 안의 작은 지도 미리보기

import SwiftUI

struct TourismDetailLocationPreviewSection: View {
    let title: String
    let addressText: String?
    let coordinate: TourismDetailCoordinateViewData

    private let mapHeight: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Text("위치 안내")
                .font(MaplogFont.sectionTitle)
                .foregroundStyle(Color.maplogTextPrimary)

            NavigationLink {
                TourismLocationMapView(
                    title: title,
                    coordinate: coordinate
                )
            } label: {
                ZStack(alignment: .bottomLeading) {
                    TourismKakaoMapCanvas(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    )
                    .allowsHitTesting(false)

                    LinearGradient(
                        colors: [
                            .clear,
                            Color.maplogMapLightSurface.opacity(0.94)
                        ],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    HStack(spacing: MaplogSpacing.xSmall) {
                        MaplogPinGlyphIcon(size: 14)
                        Text("지도 크게 보기")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(MaplogFont.calloutStrong)
                    .foregroundStyle(Color.maplogMapLightTextPrimary)
                    .padding(MaplogSpacing.small)
                }
                .frame(maxWidth: .infinity)
                .frame(height: mapHeight)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: MaplogRadius.large,
                        style: .continuous
                    )
                )
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: MaplogRadius.large,
                        style: .continuous
                    )
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title) 위치 지도 보기")
            .accessibilityHint("두 번 탭하면 전체 지도 화면을 엽니다")

            if let addressText {
                MaplogLocationLabel(
                    title: addressText,
                    pinSize: 14
                )
                .font(MaplogFont.callout)
                .foregroundStyle(Color.maplogTextSecondary)
            }
        }
    }
}
