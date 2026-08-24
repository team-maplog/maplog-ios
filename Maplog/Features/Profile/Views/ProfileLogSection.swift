import SwiftUI
import UIKit

struct ProfileLogSection: View {
    let logs: [ProfileLogCardViewData]
    let thumbnailData: (Int64) -> Data?
    let isLoadingThumbnail: (Int64) -> Bool
    let hasNextPage: Bool
    let isLoadingNextPage: Bool
    let nextPageError: ErrorPresentation?
    let onLoadNextPage: () -> Void
    let onRetryNextPage: () -> Void
    let onSelectCapture: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: MaplogSpacing.small),
        GridItem(.flexible(), spacing: MaplogSpacing.small)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("내 맵로그")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.maplogInk)

                Text("\(logs.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.maplogOlive)

                Spacer()
            }

            if logs.isEmpty {
                ProfileEmptyLogState(
                    onSelectCapture: onSelectCapture
                )
            } else {
                LazyVGrid(
                    columns: columns,
                    spacing: 20
                ) {
                    ForEach(logs) { log in
                        ProfileLogCard(
                            log: log,
                            thumbnailData: thumbnailData(log.id),
                            isLoadingThumbnail: isLoadingThumbnail(log.id)
                        )
                    }
                }

                paginationFooter
            }
        }
    }

    @ViewBuilder
    private var paginationFooter: some View {
        if isLoadingNextPage {
            ProgressView()
                .tint(Color.maplogOlive)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        } else if let nextPageError {
            VStack(spacing: 8) {
                Text(nextPageError.message)
                    .font(.caption)
                    .foregroundStyle(Color.maplogMuted)
                    .multilineTextAlignment(.center)

                if nextPageError.recoveryAction == .retry {
                    Button("더 불러오기", action: onRetryNextPage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.maplogOlive)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        } else if hasNextPage {
            Color.clear
                .frame(height: 1)
                .onAppear(perform: onLoadNextPage)
        }
    }
}

private struct ProfileLogCard: View {
    let log: ProfileLogCardViewData
    let thumbnailData: Data?
    let isLoadingThumbnail: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                thumbnail

                Text(log.durationText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.56), in: Capsule())
                    .padding(8)
            }
            .frame(height: 164)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
            )

            Text(log.addressText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.maplogInk)
                .lineLimit(2)

            HStack(spacing: 5) {
                Label(
                    log.viewCountText,
                    systemImage: "eye"
                )
                Text("·")
                Text(log.createdAtText)
            }
            .font(.caption2)
            .foregroundStyle(Color.maplogMuted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(log.addressText), 영상 길이 \(log.durationText), 조회 \(log.viewCountText)"
        )
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let thumbnailData,
           let image = UIImage(data: thumbnailData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            Color.maplogCanvas
                .overlay {
                    if isLoadingThumbnail {
                        ProgressView()
                            .tint(Color.maplogOlive)
                    } else {
                        Image(systemName: "photo")
                            .font(.title3)
                            .foregroundStyle(Color.maplogMuted)
                    }
                }
        }
    }
}

private struct ProfileEmptyLogState: View {
    let onSelectCapture: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "map.circle.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.maplogOlive)

            Text("아직 공개한 맵로그가 없어요")
                .font(.headline)
                .foregroundStyle(Color.maplogInk)

            Text("촬영한 여행 기록을 완성하면 여기에 모여요.")
                .font(.subheadline)
                .foregroundStyle(Color.maplogMuted)
                .multilineTextAlignment(.center)

            Button(action: onSelectCapture) {
                Label("새 맵로그 촬영하기", systemImage: "camera.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.maplogInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        Color.maplogLime,
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            Color.maplogCanvas,
            in: RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
    }
}
