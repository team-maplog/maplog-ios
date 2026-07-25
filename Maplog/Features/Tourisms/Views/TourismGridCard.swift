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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnail
                .frame(maxWidth: .infinity)
                .frame(height: 128)
                .clipped()
            
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 40,
                        alignment: .topLeading
                    )
                
                Label(item.periodText, systemImage: "calendar")
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                
                Label(item.locationText, systemImage: "mappin.and.ellipse")
                    .lineLimit(1)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(12)
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.black.opacity(0.06), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(item.title), \(item.periodText), \(item.locationText)"
        )
    }
    
    @ViewBuilder
    private var thumbnail: some View {
        if let thumbnailURL = item.thumbnailURL{
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
        )
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
        )
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
//   ├─ 기간
//   └─ 지역
