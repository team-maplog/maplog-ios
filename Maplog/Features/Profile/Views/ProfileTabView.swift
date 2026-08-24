import SwiftUI
import UIKit

struct ProfileTabView: View {
    @Environment(\.maplogLogout) private var performLogout
    @Environment(\.maplogSelectTab) private var selectTab

    let profileRepository: any ProfileRepository
    @ObservedObject var viewModel: ProfileTabViewModel

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
        .refreshable {
            await viewModel.reload()
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

                ProfileLogSection(
                    logs: viewModel.logs,
                    thumbnailData: viewModel.thumbnailData(for:),
                    isLoadingThumbnail: viewModel.isLoadingThumbnail(for:),
                    hasNextPage: viewModel.hasNextPage,
                    isLoadingNextPage: viewModel.isLoadingNextPage,
                    nextPageError: viewModel.nextPageError,
                    onLoadNextPage: loadNextPage,
                    onRetryNextPage: retryNextPage,
                    onSelectCapture: selectCaptureTab
                )
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

    private func selectCaptureTab() {
        selectTab(.capture)
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
