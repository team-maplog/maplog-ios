import SwiftUI

struct FollowUserListFeatureView: View {
    @Environment(\.maplogLogout) private var performLogout

    private let kind: FollowListKind
    private let followRepository: any FollowRepository
    private let profileRepository: any ProfileRepository
    @StateObject private var viewModel: FollowUserListViewModel

    init(
        kind: FollowListKind,
        followRepository: any FollowRepository,
        profileRepository: any ProfileRepository
    ) {
        self.kind = kind
        self.followRepository = followRepository
        self.profileRepository = profileRepository
        _viewModel = StateObject(
            wrappedValue: FollowUserListViewModel(
                kind: kind,
                followRepository: followRepository,
                profileRepository: profileRepository
            )
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            content
                .padding(.horizontal, MaplogSpacing.page)
                .padding(.top, MaplogSpacing.medium)
                .maplogListBottomPadding()
        }
        .background(Color.maplogSurface)
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .maplogTabBarHidden()
        .task {
            await viewModel.loadIfNeeded()
        }
        .refreshable {
            await viewModel.reload()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .initialLoading:
            FollowUserListLoadingState(title: kind.title)

        case .empty:
            FollowUserListEmptyState(kind: kind)

        case .content:
            LazyVStack(spacing: 0) {
                ForEach(viewModel.users) { user in
                    NavigationLink {
                        PublicProfileFeatureView(
                            user: user,
                            followRepository: followRepository,
                            profileRepository: profileRepository,
                            onFollowStateChanged: viewModel.apply
                        )
                    } label: {
                        FollowUserRow(
                            user: user,
                            imageData: viewModel.profileImageData(for: user)
                        )
                    }
                    .buttonStyle(.plain)
                    .task(id: user.profileImageURL) {
                        await viewModel.loadProfileImage(for: user)
                    }

                    if user.id != viewModel.users.last?.id {
                        Divider()
                            .overlay(Color.maplogLine)
                            .padding(.leading, 58)
                    }
                }

                paginationFooter
            }

        case let .failed(presentation):
            FollowUserListFailureState(
                presentation: presentation,
                onRetry: retryInitialLoad,
                onSignIn: performLogout
            )
        }
    }

    @ViewBuilder
    private var paginationFooter: some View {
        if viewModel.isLoadingNextPage {
            ProgressView()
                .tint(Color.maplogOlive)
                .frame(maxWidth: .infinity)
                .padding(.vertical, MaplogSpacing.medium)
        } else if let error = viewModel.nextPageError {
            VStack(spacing: MaplogSpacing.xSmall) {
                Text(error.message)
                    .font(.caption)
                    .foregroundStyle(Color.maplogMuted)
                    .multilineTextAlignment(.center)

                if error.recoveryAction == .retry {
                    Button("더 불러오기", action: retryNextPage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.maplogOlive)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, MaplogSpacing.medium)
        } else if viewModel.hasNextPage {
            Color.clear
                .frame(height: 1)
                .onAppear(perform: loadNextPage)
        }
    }

    private func retryInitialLoad() {
        Task {
            await viewModel.retryInitialLoad()
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
}

private struct FollowUserRow: View {
    let user: FollowUser
    let imageData: Data?

    var body: some View {
        HStack(spacing: MaplogSpacing.small) {
            MaplogProfileAvatar(
                imageData: imageData,
                nickname: user.nickname,
                size: 44,
                fallbackBackground: Color.maplogCanvas,
                fallbackForeground: Color.maplogOlive,
                borderColor: Color.maplogLine
            )

            Text(user.nickname)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.maplogInk)
                .lineLimit(1)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.maplogMuted)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityLabel("\(user.nickname) 프로필 보기")
    }
}

private struct FollowUserListLoadingState: View {
    let title: String

    var body: some View {
        VStack(spacing: MaplogSpacing.small) {
            ProgressView()
                .tint(Color.maplogOlive)

            Text("\(title) 목록을 불러오는 중이에요")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.maplogMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 96)
    }
}

private struct FollowUserListEmptyState: View {
    let kind: FollowListKind

    private var message: String {
        switch kind {
        case .followers:
            return "아직 팔로워가 없어요.\n첫 여행 기록을 공유해 보세요."
        case .following:
            return "아직 팔로우한 사용자가 없어요.\n마음에 드는 여행자를 팔로우해 보세요."
        }
    }

    var body: some View {
        VStack(spacing: MaplogSpacing.small) {
            Image(systemName: kind == .followers ? "person.2" : "person.badge.plus")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Color.maplogMuted)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.maplogMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 96)
    }
}

private struct FollowUserListFailureState: View {
    let presentation: ErrorPresentation
    let onRetry: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: MaplogSpacing.medium) {
            Image(systemName: "person.2.badge.gearshape")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Color.maplogMuted)

            Text(presentation.message)
                .font(.subheadline)
                .foregroundStyle(Color.maplogMuted)
                .multilineTextAlignment(.center)

            switch presentation.recoveryAction {
            case .retry:
                Button("다시 시도", action: onRetry)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.maplogOnPrimary)
                    .padding(.horizontal, 18)
                    .frame(height: 40)
                    .background(Color.maplogLime, in: Capsule())

            case .signIn:
                Button("로그인으로 이동", action: onSignIn)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.maplogOnPrimary)
                    .padding(.horizontal, 18)
                    .frame(height: 40)
                    .background(Color.maplogLime, in: Capsule())

            case .none:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
}
