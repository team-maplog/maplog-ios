import Foundation
import SwiftUI
import UIKit

/// 상세 영상의 클립 순서를 유지한 채, 방문 장소를 세로 목록으로 보여 줍니다.
struct LogDetailPlacesSection: View {
    let clips: [LogReelClip]
    let thumbnailDataByClipID: [Int64: Data]
    let loadingClipThumbnailIDs: Set<Int64>

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Text("영상 속 장소")
                .font(MaplogFont.sectionTitle)
                .foregroundStyle(Color.maplogInk)

            LazyVStack(spacing: MaplogSpacing.xSmall) {
                ForEach(clips) { clip in
                    LogDetailPlaceCard(
                        clip: clip,
                        thumbnailData: thumbnailDataByClipID[clip.id],
                        isLoadingThumbnail: loadingClipThumbnailIDs.contains(clip.id)
                    )
                }
            }
        }
    }
}

private struct LogDetailPlaceCard: View {
    let clip: LogReelClip
    let thumbnailData: Data?
    let isLoadingThumbnail: Bool

    var body: some View {
        HStack(spacing: MaplogSpacing.xSmall) {
            thumbnail

            VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                HStack(spacing: MaplogSpacing.xxSmall) {
                    Text("\(clip.displayOrder + 1)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.maplogInk)
                        .frame(width: 18, height: 18)
                        .background(Color.maplogLime, in: Circle())

                    Text(clip.location.name ?? "장소 정보 없음")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.maplogInk)
                        .lineLimit(1)
                }

                Text(clip.location.address)
                    .font(.caption2)
                    .foregroundStyle(Color.maplogMuted)
                    .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(MaplogSpacing.xSmall)
        .background(
            Color.maplogCanvas,
            in: RoundedRectangle(cornerRadius: MaplogRadius.large, style: .continuous)
        )
        .accessibilityLabel(
            "\(clip.displayOrder + 1)번째 장소, \(clip.location.name ?? clip.location.address)"
        )
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let thumbnailData,
           let image = UIImage(data: thumbnailData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 46, height: 54)
                .clipped()
        } else {
            Color.maplogSurfaceRaised
                .frame(width: 46, height: 54)
                .overlay {
                    if isLoadingThumbnail {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color.maplogOlive)
                    } else {
                        Image(systemName: "photo")
                            .font(.caption)
                            .foregroundStyle(Color.maplogMuted)
                    }
                }
        }
    }
}
