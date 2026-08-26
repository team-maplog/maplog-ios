import SwiftUI
import UIKit

private enum ProfileLogTab: CaseIterable {
    case myLogs
    case savedLogs

    var title: String {
        switch self {
        case .myLogs:
            return "내 맵로그"
        case .savedLogs:
            return "저장됨"
        }
    }
}

struct ProfileTabView: View {
    @Environment(\.maplogLogout) private var performLogout
    @Environment(\.maplogSelectTab) private var selectTab

    let profileRepository: any ProfileRepository
    let logDetailRepository: any LogDetailRepository
    let logMediaRepository: any LogMediaRepository
    let playbackService: any VideoPlaybackService
    @ObservedObject var viewModel: ProfileTabViewModel
    @State private var selectedLogTab: ProfileLogTab = .myLogs

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                title
                screenContent
            }
            .padding(.horizontal, MaplogSpacing.page)
            .padding(.top, 24)
            .maplogListBottomPadding()
        }
        .background(Color.maplogSurface)
        .task {
            await viewModel.loadIfNeeded()
        }
        .task(id: selectedLogTab) {
            guard selectedLogTab == .savedLogs else {
                return
            }

            await viewModel.loadSavedLogsIfNeeded()
        }
        .refreshable {
            await refreshSelectedLogTab()
        }
    }

    private var title: some View {
        HStack(spacing: 12) {
            Text("마이 프로필")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.maplogInk)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 0)

            if let profile = viewModel.profile {
                NavigationLink {
                    ProfileSettingsFeatureView(
                        profile: profile,
                        avatarImageData: viewModel.avatarImageData,
                        profileRepository: profileRepository,
                        onProfileSaved: reloadProfile
                    )
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.maplogInk)
                        .frame(
                            width: MaplogSize.minimumTapTarget,
                            height: MaplogSize.minimumTapTarget
                        )
                }
                .accessibilityLabel("설정")
            }
        }
    }

    @ViewBuilder
    private var screenContent: some View {
        switch viewModel.state {
        case .idle, .initialLoading:
            ProfileLoadingState()

        case .content:
            if let profile = viewModel.profile {
                ProfileHeader(
                    profile: profile,
                    avatarImageData: viewModel.avatarImageData
                )

                ProfileActionButtons(
                    profile: profile,
                    avatarImageData: viewModel.avatarImageData,
                    profileRepository: profileRepository,
                    onProfileSaved: reloadProfile
                )

                ProfileLogTabPicker(
                    selection: $selectedLogTab,
                    myLogsCount: viewModel.logs.count,
                    savedLogsCount: viewModel.savedLogs.count
                )

                selectedLogContent
            }

        case .failed(let presentation):
            ProfileInitialFailureState(
                presentation: presentation,
                onRetry: retryInitialLoad,
                onSignIn: performLogout
            )
        }
    }

    private func loadNextPage() {
        Task {
            await viewModel.loadNextPage()
        }
    }

    private func retryNextPage() {
        Task {
            await viewModel.retryNextPage()
        }
    }

    private func retryInitialLoad() {
        Task {
            await viewModel.retryInitialLoad()
        }
    }

    private func reloadProfile() async {
        await viewModel.reload()
    }

    private func refreshSelectedLogTab() async {
        switch selectedLogTab {
        case .myLogs:
            await viewModel.reload()
        case .savedLogs:
            await viewModel.reloadSavedLogs()
        }
    }

    private func selectCaptureTab() {
        selectTab(.capture)
    }

    @ViewBuilder
    private var selectedLogContent: some View {
        switch selectedLogTab {
        case .myLogs:
            ProfileLogSection(
                logs: viewModel.logs,
                thumbnailData: viewModel.thumbnailData(for:),
                isLoadingThumbnail: viewModel.isLoadingThumbnail(for:),
                logDetailRepository: logDetailRepository,
                logMediaRepository: logMediaRepository,
                playbackService: playbackService,
                hasNextPage: viewModel.hasNextPage,
                isLoadingNextPage: viewModel.isLoadingNextPage,
                nextPageError: viewModel.nextPageError,
                onLoadNextPage: loadNextPage,
                onRetryNextPage: retryNextPage,
                allowsManagement: true,
                emptyConfiguration: ProfileLogEmptyConfiguration(
                    iconName: "map.circle.fill",
                    title: "아직 공개한 맵로그가 없어요",
                    message: "촬영한 여행 기록을 완성하면 여기에 모여요.",
                    actionTitle: "새 맵로그 촬영하기"
                ),
                onSelectCapture: selectCaptureTab,
                onLogUnavailable: { _ in
                    await viewModel.reload()
                }
            )

        case .savedLogs:
            switch viewModel.savedLogsState {
            case .idle, .initialLoading:
                ProfileSavedLogsLoadingState()

            case .content:
                ProfileLogSection(
                    logs: viewModel.savedLogs,
                    thumbnailData: viewModel.thumbnailData(for:),
                    isLoadingThumbnail: viewModel.isLoadingThumbnail(for:),
                    logDetailRepository: logDetailRepository,
                    logMediaRepository: logMediaRepository,
                    playbackService: playbackService,
                    hasNextPage: viewModel.hasNextSavedLogsPage,
                    isLoadingNextPage: viewModel.isLoadingNextSavedLogsPage,
                    nextPageError: viewModel.nextSavedLogsPageError,
                    onLoadNextPage: loadNextSavedLogsPage,
                    onRetryNextPage: retryNextSavedLogsPage,
                    allowsManagement: false,
                    emptyConfiguration: ProfileLogEmptyConfiguration(
                        iconName: "bookmark",
                        title: "저장한 맵로그가 없어요",
                        message: "마음에 드는 여행 영상을 저장하면 여기에 모여요.",
                        actionTitle: nil
                    ),
                    onSelectCapture: {},
                    onLogUnavailable: { logID in
                        viewModel.removeSavedLog(withID: logID)
                    }
                )

            case .failed(let presentation):
                ProfileSavedLogsFailureState(
                    presentation: presentation,
                    onRetry: retryInitialSavedLogsLoad,
                    onSignIn: performLogout
                )
            }
        }
    }

    private func loadNextSavedLogsPage() {
        Task {
            await viewModel.loadNextSavedLogsPage()
        }
    }

    private func retryNextSavedLogsPage() {
        Task {
            await viewModel.retryNextSavedLogsPage()
        }
    }

    private func retryInitialSavedLogsLoad() {
        Task {
            await viewModel.retryInitialSavedLogsLoad()
        }
    }
}

private struct ProfileLogTabPicker: View {
    @Binding var selection: ProfileLogTab
    let myLogsCount: Int
    let savedLogsCount: Int

    var body: some View {
        HStack(spacing: 0) {
            tabButton(
                for: .myLogs,
                count: myLogsCount
            )
            tabButton(
                for: .savedLogs,
                count: savedLogsCount
            )
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.maplogLine)
                .frame(height: 1)
        }
    }

    private func tabButton(
        for tab: ProfileLogTab,
        count: Int
    ) -> some View {
        Button {
            selection = tab
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 5) {
                    Text(tab.title)
                        .font(.subheadline.weight(
                            selection == tab ? .bold : .medium
                        ))

                    Text("\(count)")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(
                    selection == tab
                        ? Color.maplogInk
                        : Color.maplogMuted
                )

                Rectangle()
                    .fill(
                        selection == tab
                            ? Color.maplogLime
                            : Color.clear
                    )
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: MaplogSize.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
        .accessibilityLabel("\(tab.title) \(count)개")
    }
}

private struct ProfileSavedLogsLoadingState: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color.maplogOlive)

            Text("저장한 맵로그를 불러오는 중이에요")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.maplogMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }
}

private struct ProfileSavedLogsFailureState: View {
    let presentation: ErrorPresentation
    let onRetry: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.maplogMuted)

            Text(presentation.message)
                .font(.subheadline)
                .foregroundStyle(Color.maplogMuted)
                .multilineTextAlignment(.center)

            switch presentation.recoveryAction {
            case .retry:
                Button("다시 시도", action: onRetry)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 18)
                    .frame(height: 40)
                    .background(Color.maplogLime, in: Capsule())

            case .signIn:
                Button("로그인으로 이동", action: onSignIn)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 18)
                    .frame(height: 40)
                    .background(Color.maplogLime, in: Capsule())

            case .none:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

private struct ProfileActionButtons: View {
    let profile: ProfileHeaderViewData
    let avatarImageData: Data?
    let profileRepository: any ProfileRepository
    let onProfileSaved: () async -> Void

    var body: some View {
        NavigationLink {
            ProfileEditFeatureView(
                profile: profile,
                avatarImageData: avatarImageData,
                profileRepository: profileRepository,
                onSaved: onProfileSaved
            )
        } label: {
            Label("프로필 편집", systemImage: "pencil")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.maplogInk)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    Color.maplogCanvas,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileHeader: View {
    let profile: ProfileHeaderViewData
    let avatarImageData: Data?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                ProfileAvatar(
                    imageData: avatarImageData,
                    nickname: profile.nickname
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.nickname)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.maplogInk)

                    if !profile.bio.isEmpty {
                        Text(profile.bio)
                            .font(.subheadline)
                            .foregroundStyle(Color.maplogMuted)
                            .lineLimit(3)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 0) {
                ProfileMetric(
                    title: "팔로워",
                    value: profile.followerCountText
                )
                ProfileMetric(
                    title: "팔로잉",
                    value: profile.followingCountText
                )
                ProfileMetric(
                    title: "맵로그",
                    value: profile.logCountText
                )
            }
            .padding(.vertical, 14)
            .background(
                Color.maplogCanvas,
                in: RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
            )
        }
        .padding(18)
        .background(
            Color.maplogSurfaceRaised,
            in: RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .shadow(
            color: .black.opacity(0.04),
            radius: 14,
            y: 6
        )
    }
}

private struct ProfileAvatar: View {
    let imageData: Data?
    let nickname: String

    var body: some View {
        Group {
            if let imageData,
               let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.maplogOlive)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.maplogLime.opacity(0.35))
            }
        }
        .frame(width: 76, height: 76)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.maplogLime.opacity(0.85), lineWidth: 3)
        }
        .accessibilityLabel("\(nickname) 프로필 사진")
    }
}

private struct ProfileMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.maplogInk)

            Text(title)
                .font(.caption)
                .foregroundStyle(Color.maplogMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ProfileLoadingState: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(Color.maplogOlive)

            Text("프로필을 불러오는 중이에요")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.maplogMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 96)
    }
}

private struct ProfileInitialFailureState: View {
    let presentation: ErrorPresentation
    let onRetry: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Color.maplogMuted)

            Text(presentation.message)
                .font(.subheadline)
                .foregroundStyle(Color.maplogMuted)
                .multilineTextAlignment(.center)

            switch presentation.recoveryAction {
            case .retry:
                Button("다시 시도", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.maplogLime)
                    .foregroundStyle(Color.maplogInk)

            case .signIn:
                Button("로그인으로 이동", action: onSignIn)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.maplogLime)
                    .foregroundStyle(Color.maplogInk)

            case .none:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 88)
    }
}
