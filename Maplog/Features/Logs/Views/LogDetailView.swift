import AVFoundation
import Foundation
import SwiftUI

struct LogDetailView: View {
    let state: LogDetailScreenState
    let detail: LogDetail?
    let player: AVPlayer
    let isLoadingPlayback: Bool
    let playbackErrorMessage: String?
    let clipThumbnailDataByID: [Int64: Data]
    let loadingClipThumbnailIDs: Set<Int64>
    let playbackProgress: Double
    let isPlaying: Bool
    let onRetryDetail: () -> Void
    let onRetryPlayback: () -> Void
    let onPlaybackToggle: () -> Void
    let onSeekPlayback: (Double) -> Void
    let onSignIn: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            screenContent
                .maplogListBottomPadding()
        }
        .background(Color.maplogSurface)
    }

    @ViewBuilder
    private var screenContent: some View {
        switch state {
        case .idle, .initialLoading:
            ProgressView()
                .tint(Color.maplogOlive)
                .frame(maxWidth: .infinity, minHeight: 420)

        case .content:
            if let detail {
                LogDetailContent(
                    detail: detail,
                    player: player,
                    isLoadingPlayback: isLoadingPlayback,
                    playbackErrorMessage: playbackErrorMessage,
                    clipThumbnailDataByID: clipThumbnailDataByID,
                    loadingClipThumbnailIDs: loadingClipThumbnailIDs,
                    playbackProgress: playbackProgress,
                    isPlaying: isPlaying,
                    onRetryPlayback: onRetryPlayback,
                    onPlaybackToggle: onPlaybackToggle,
                    onSeekPlayback: onSeekPlayback
                )
            }

        case .failed(let presentation):
            LogDetailFailureState(
                presentation: presentation,
                onRetry: onRetryDetail,
                onSignIn: onSignIn
            )
            .frame(maxWidth: .infinity, minHeight: 420)
            .padding(.horizontal, MaplogSpacing.page)
        }
    }
}

private struct LogDetailContent: View {
    let detail: LogDetail
    let player: AVPlayer
    let isLoadingPlayback: Bool
    let playbackErrorMessage: String?
    let clipThumbnailDataByID: [Int64: Data]
    let loadingClipThumbnailIDs: Set<Int64>
    let playbackProgress: Double
    let isPlaying: Bool
    let onRetryPlayback: () -> Void
    let onPlaybackToggle: () -> Void
    let onSeekPlayback: (Double) -> Void

    var body: some View {
        VStack(spacing: MaplogSpacing.large) {
            LogDetailVideoSection(
                player: player,
                isLoading: isLoadingPlayback,
                errorMessage: playbackErrorMessage,
                playbackProgress: playbackProgress,
                isPlaying: isPlaying,
                onRetry: onRetryPlayback,
                onPlaybackToggle: onPlaybackToggle,
                onSeek: onSeekPlayback
            )
            .padding(.horizontal, MaplogSpacing.xSmall)
            .padding(.top, MaplogSpacing.xSmall)

            VStack(alignment: .leading, spacing: MaplogSpacing.large) {
                LogDetailCaptionSection(detail: detail)

                if !detail.clips.isEmpty {
                    LogDetailPlacesSection(
                        clips: detail.clips,
                        thumbnailDataByClipID: clipThumbnailDataByID,
                        loadingClipThumbnailIDs: loadingClipThumbnailIDs
                    )
                }
            }
            .maplogPagePadding()
        }
    }
}

private struct LogDetailCaptionSection: View {
    let detail: LogDetail

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            Text(detail.caption)
                .font(MaplogFont.body)
                .foregroundStyle(Color.maplogInk)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !detail.tags.isEmpty {
                Text(detail.tags.map(\.title).map { "#\($0)" }.joined(separator: "  "))
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogOlive)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: MaplogSpacing.xSmall) {
                HStack(spacing: MaplogSpacing.xxSmall) {
                    MaplogPinGlyphIcon(size: 12)

                    Text(detail.address)
                }

                Text("·")

                Text(detail.publishedAt, format: .dateTime.year().month().day())

                Text("·")

                Label(
                    detail.viewCount.formatted(.number.notation(.compactName)),
                    systemImage: "eye"
                )
            }
            .font(MaplogFont.caption)
            .foregroundStyle(Color.maplogMuted)
            .lineLimit(1)
        }
    }
}

private struct LogDetailFailureState: View {
    let presentation: ErrorPresentation
    let onRetry: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: MaplogSpacing.small) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.maplogOlive)

            Text(presentation.message)
                .font(MaplogFont.callout)
                .foregroundStyle(Color.maplogMuted)
                .multilineTextAlignment(.center)

            switch presentation.recoveryAction {
            case .retry:
                Button("다시 시도", action: onRetry)
                    .font(MaplogFont.calloutStrong)
                    .foregroundStyle(Color.maplogOnPrimary)
                    .padding(.horizontal, 18)
                    .frame(height: MaplogSize.compactControlHeight)
                    .background(Color.maplogLime, in: Capsule())

            case .signIn:
                Button("다시 로그인", action: onSignIn)
                    .font(MaplogFont.calloutStrong)
                    .foregroundStyle(Color.maplogOlive)

            case .none:
                EmptyView()
            }
        }
    }
}
