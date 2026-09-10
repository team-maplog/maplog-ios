import SwiftUI
import UIKit

struct ProfileLogEmptyConfiguration {
    let iconName: String
    let title: String
    let message: String
    let actionTitle: String?
}

struct ProfileLogSection: View {
    let logs: [ProfileLogCardViewData]
    let thumbnailData: (Int64) -> Data?
    let isLoadingThumbnail: (Int64) -> Bool
    let logDetailRepository: any LogDetailRepository
    let logMediaRepository: any LogMediaRepository
    let followRepository: any FollowRepository
    let profileRepository: any ProfileRepository
    let playbackService: any VideoPlaybackService
    let hasNextPage: Bool
    let isLoadingNextPage: Bool
    let nextPageError: ErrorPresentation?
    let onLoadNextPage: () -> Void
    let onRetryNextPage: () -> Void
    let allowsManagement: Bool
    let emptyConfiguration: ProfileLogEmptyConfiguration
    let onSelectCapture: () -> Void
    let onLogUnavailable: (Int64) async -> Void

    @State private var selectedLogID: Int64?
    @State private var showsLogDetail = false

    private let columns = [
        GridItem(.flexible(), spacing: MaplogSpacing.small),
        GridItem(.flexible(), spacing: MaplogSpacing.small)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if logs.isEmpty {
                ProfileEmptyLogState(
                    configuration: emptyConfiguration,
                    onSelectCapture: onSelectCapture
                )
            } else {
                LazyVGrid(
                    columns: columns,
                    spacing: 20
                ) {
                    ForEach(logs) { log in
                        Button {
                            selectedLogID = log.id
                            showsLogDetail = true
                        } label: {
                            ProfileLogCard(
                                log: log,
                                thumbnailData: thumbnailData(log.id),
                                isLoadingThumbnail: isLoadingThumbnail(log.id)
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .accessibilityHint("맵로그 상세를 엽니다")
                    }
                }

                paginationFooter
            }
        }
        .navigationDestination(isPresented: $showsLogDetail) {
            if let selectedLogID {
                LogDetailFeatureView(
                    logID: selectedLogID,
                    allowsManagement: allowsManagement,
                    logDetailRepository: logDetailRepository,
                    logMediaRepository: logMediaRepository,
                    followRepository: followRepository,
                    profileRepository: profileRepository,
                    playbackService: playbackService,
                    onLogRemoved: {
                        await onLogUnavailable(selectedLogID)
                    }
                )
                .id(selectedLogID)
            } else {
                EmptyView()
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
            thumbnail
                .aspectRatio(ProfileLayout.thumbnailAspectRatio, contentMode: .fit)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous
                    )
                )
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: MaplogSpacing.xxxSmall) {
                        MaplogViewCountGlyphIcon(size: 14)
                        Text(log.viewCountText)
                    }
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.64), radius: 2, x: 0, y: 1)
                        .padding(8)
                }
                .overlay(alignment: .bottomTrailing) {
                    Text(log.durationText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.64), radius: 2, x: 0, y: 1)
                        .padding(8)
                }

            Text(log.addressText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.maplogInk)
                .lineLimit(2, reservesSpace: true)

            Text(log.createdAtText)
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
    let configuration: ProfileLogEmptyConfiguration
    let onSelectCapture: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: configuration.iconName)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.maplogOlive)

            Text(configuration.title)
                .font(.headline)
                .foregroundStyle(Color.maplogInk)

            Text(configuration.message)
                .font(.subheadline)
                .foregroundStyle(Color.maplogMuted)
                .multilineTextAlignment(.center)

            if let actionTitle = configuration.actionTitle {
                Button(action: onSelectCapture) {
                    Label(actionTitle, systemImage: "camera.fill")
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
