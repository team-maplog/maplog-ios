//
//  TourismGridCard.swift
//  Maplog
//
//  Created by 한채림 on 7/22/26.
//

//2열에서 보이는 작은 관광 카드 하나
// 관광 데이터 하나를 받아서 2열 그리드 안에 그리는 역할만 함. API 호출·페이지네이션·화면 이동은 하지 않음
import SwiftUI

struct TourismGridCard: View {
    let item: TourismListItemViewData
    let categoryTitle: String
    let cardWidth: CGFloat

    // 목록 사진은 카드 폭보다 조금 낮게 잡아, 제목과 기간 정보까지 한 화면에 안정적으로 보이게 한다.
    private var imageHeight: CGFloat {
        cardWidth * 0.82
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
            thumbnail
                .frame(width: cardWidth)
                .frame(height: imageHeight)
                .clipped()
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: MaplogRadius.medium,
                        style: .continuous
                    )
                )
                // 캡슐을 이미지의 overlay로 올리면 썸네일의 크기와 관계없이
                // 항상 카드 안쪽 좌측 상단(8pt)에 고정된다.
                .overlay(alignment: .topLeading) {
                Text(categoryTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.maplogTextPrimary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.white, in: Capsule())
                    .padding(MaplogSpacing.xSmall)
                }

            Text(item.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.maplogTextPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(
                    width: cardWidth,
                    height: 18,
                    alignment: .topLeading
                )

            Text(item.periodText)
                .font(.system(size: 11))
                .foregroundStyle(Color.maplogTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .frame(width: cardWidth, alignment: .leading)
        }
        .frame(width: cardWidth, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(categoryTitle), \(item.title), \(item.periodText), \(item.locationText)"
        )
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let thumbnailURL = item.thumbnailURL {
            AsyncImage(url: thumbnailURL) { phase in
                switch phase {
                case .empty:
                    imagePlaceholder
                        .overlay {
                                ProgressView()
                                    .tint(.secondary)
                        }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .failure:
                    imagePlaceholder

                @unknown default:
                    imagePlaceholder
                }
            }
        } else {
            imagePlaceholder
        }
    }
    
    private var imagePlaceholder: some View {
        Color(uiColor: .tertiarySystemFill)
            .overlay {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
    }
}

#Preview("2열 관광 카드") {
    TourismGridCard(
        item: TourismListItemViewData(
            id: 2993769,
            title: "안동 수(水)페스타",
            locationText: "경상북도 안동시",
            periodText: "2026. 07. 25. ~ 2026. 08. 02.",
            thumbnailURL: nil
        ),
        categoryTitle: "축제",
        cardWidth: 170
    )
    .frame(width: 170)
    .padding()
    .background(Color(uiColor: .systemBackground))
}

#Preview("긴 제목 카드") {
    TourismGridCard(
        item: TourismListItemViewData(
            id: 1,
            title: "2026 이럴때이런음악 해설이 있는 청소년음악회",
            locationText: "서울특별시",
            periodText: "2026. 08. 14. ~ 2026. 08. 14.",
            thumbnailURL: nil
        ),
        categoryTitle: "공연",
        cardWidth: 170
    )
    .frame(width: 170)
    .padding()
}

//TourismGridCard
//├─ thumbnail
//│  ├─ AsyncImage 성공 → 실제 이미지
//│  ├─ 로딩 중 → placeholder + spinner
//│  └─ 실패/URL 없음 → placeholder
//│
//└─ 텍스트 영역
//   ├─ 제목
//   └─ 기간 · 지역
