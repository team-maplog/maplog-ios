import SwiftUI

struct PublicProfileFeatureView: View {
    @Environment(\.maplogLogout) private var performLogout

    private let onFollowStateChanged: (FollowState) -> Void
    @StateObject private var viewModel: PublicProfileViewModel

    init(
        user: FollowUser,
        followRepository: any FollowRepository,
        profileRepository: any ProfileRepository,
        onFollowStateChanged: @escaping (FollowState) -> Void = { _ in }
    ) {
        self.onFollowStateChanged = onFollowStateChanged
        _viewModel = StateObject(
            wrappedValue: PublicProfileViewModel(
                user: user,
                followRepository: followRepository,
                profileRepository: profileRepository
            )
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            content
                .padding(.horizontal, MaplogSpacing.page)
                .padding(.top, 28)
                .maplogListBottomPadding()
        }
        .background(Color.maplogSurface)
        .navigationTitle("프로필")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .maplogTabBarHidden()
        .task {
            await viewModel.loadIfNeeded()
        }
        .alert(
            "팔로우 상태를 바꾸지 못했어요",
            isPresented: actionErrorPresented
        ) {
            if viewModel.actionError?.recoveryAction == .retry {
                Button("다시 시도") {
                    toggleFollow()
                }
            }

            if viewModel.actionError?.recoveryAction == .signIn {
                Button("다시 로그인", action: performLogout)
            }

            Button("확인", role: .cancel) {
                viewModel.dismissActionError()
            }
        } message: {
            Text(viewModel.actionError?.message ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            PublicProfileLoadingState()

        case .content:
            VStack(spacing: 22) {
                MaplogProfileAvatar(
                    imageData: viewModel.avatarImageData,
                    nickname: viewModel.user.nickname,
                    size: 96,
                    fallbackBackground: Color.maplogLime.opacity(0.28),
                    fallbackForeground: Color.maplogOlive,
                    borderColor: Color.maplogLime.opacity(0.8)
                )

                VStack(spacing: 8) {
                    Text(viewModel.user.nickname)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.maplogInk)

                    Text("Maplog 여행자")
                        .font(.subheadline)
                        .foregroundStyle(Color.maplogMuted)
                }

                if viewModel.isOwnProfile {
                    Text("내 프로필")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.maplogMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.maplogCanvas, in: Capsule())
                } else {
                    Button(action: toggleFollow) {
                        Group {
                            if viewModel.isUpdatingFollowState {
                                ProgressView()
                                    .tint(Color.maplogInk)
                            } else {
                                Text(viewModel.isFollowing ? "팔로잉" : "팔로우")
                                    .font(.subheadline.weight(.bold))
                            }
                        }
                        .foregroundStyle(Color.maplogInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            viewModel.isFollowing
                                ? Color.maplogCanvas
                                : Color.maplogLime,
                            in: Capsule()
                        )
                    }
                    .buttonStyle(MaplogPressFeedbackStyle())
                    .disabled(viewModel.isUpdatingFollowState)
                    .accessibilityLabel(
                        viewModel.isFollowing ? "팔로우 취소" : "팔로우"
                    )
                }

                Text("팔로우하고 새로운 여행 기록을 받아보세요.")
                    .font(.caption)
                    .foregroundStyle(Color.maplogMuted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)

        case let .failed(presentation):
            PublicProfileFailureState(
                presentation: presentation,
                onRetry: retryInitialLoad,
                onSignIn: performLogout
            )
        }
    }

    private var actionErrorPresented: Binding<Bool> {
        Binding(
            get: { viewModel.actionError != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissActionError()
                }
            }
        )
    }

    private func retryInitialLoad() {
        Task {
            await viewModel.retryInitialLoad()
        }
    }

    private func toggleFollow() {
        Task {
            await viewModel.toggleFollow()
            onFollowStateChanged(
                FollowState(
                    userID: viewModel.user.id,
                    isFollowing: viewModel.isFollowing
                )
            )
        }
    }
}

private struct PublicProfileLoadingState: View {
    var body: some View {
        VStack(spacing: MaplogSpacing.small) {
            ProgressView()
                .tint(Color.maplogOlive)

            Text("프로필을 불러오는 중이에요")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.maplogMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 120)
    }
}

private struct PublicProfileFailureState: View {
    let presentation: ErrorPresentation
    let onRetry: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: MaplogSpacing.medium) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 34, weight: .medium))
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
        .padding(.vertical, 110)
    }
}
