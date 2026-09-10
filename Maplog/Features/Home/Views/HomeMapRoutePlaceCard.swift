import SwiftUI
import UIKit

struct HomeMapRoutePlaceCard: View {
    let point: HomeMapRoutePointViewData
    let logID: Int64
    let thumbnailData: Data?
    let isLoadingThumbnail: Bool
    let onPlay: (HomeMapRoutePlaybackRequest) -> Void

    var body: some View {
        // 아이콘뿐 아니라 사진·텍스트·여백도 같은 재생 버튼의 영역이다.
        Button {
            onPlay(HomeMapRoutePlaybackRequest(
                logID: logID,
                startTimeMillis: point.startTimeMillis
            ))
        } label: {
            HStack(spacing: 12) {
                thumbnail

                VStack(alignment: .leading, spacing: 5) {
                    Text("\(point.sequence)번째 장소")
                        .font(.caption2)
                        .foregroundStyle(Color.maplogMapLightTextSecondary)

                    Text(point.placeName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.maplogMapLightTextPrimary)
                        .lineLimit(1)

                    MaplogLocationLabel(title: point.address, pinSize: 13)
                        .font(.caption)
                        .foregroundStyle(Color.maplogMapLightTextSecondary)
                        .lineLimit(1)

                    Text("\(startTimeText)부터 재생")
                        .font(.caption2)
                        .foregroundStyle(Color.maplogMapLightTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "play.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.maplogOnPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.maplogLime, in: Circle())
            }
            .padding(14)
            .background(
                Color.maplogMapLightSurface,
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(point.sequence)번째 장소, \(point.placeName), \(point.address), \(startTimeText)부터 재생")
        .accessibilityHint("지도 위 영상 미리보기에서 해당 장소가 시작되는 시점부터 재생합니다")
        .accessibilityIdentifier("route-place-card-\(point.id)")
    }

    private var startTimeText: String {
        let totalSeconds = max(0, point.startTimeMillis / 1_000)
        return String(format: "%02lld:%02lld", totalSeconds / 60, totalSeconds % 60)
    }

    private var thumbnail: some View {
        Group {
            if let thumbnailData, let image = UIImage(data: thumbnailData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.maplogMapLightSurfaceRaised
                    if isLoadingThumbnail {
                        ProgressView().tint(Color.maplogPrimary)
                    } else {
                        Image(systemName: "photo")
                            .foregroundStyle(Color.maplogMapLightTextSecondary)
                    }
                }
            }
        }
        .frame(width: 64, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
