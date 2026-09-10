import SwiftUI
import UIKit

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
                .padding(.top, MaplogSpacing.medium)
                .maplogListBottomPadding()
        }
        .background(Color.maplogSurface)
        .navigationTitle(viewModel.nickname)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .maplogTabBarHidden()
        .task {
            await viewModel.loadIfNeeded()
        }
        .refreshable {
            await viewModel.reload()
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
            if let profile = viewModel.profile {
                VStack(alignment: .leading, spacing: MaplogSpacing.section) {
                    profileHeader(profile)

                    Divider()
                        .overlay(Color.maplogLine)

                    PublicProfileLogSection(
                        nickname: profile.nickname,
                        logCountText: profile.logCountText,
                        logs: viewModel.logs,
                        thumbnailData: viewModel.thumbnailData(for:),
                        isLoadingThumbnail: viewModel.isLoadingThumbnail(for:),
                        hasNextPage: viewModel.hasNextPage,
                        isLoadingNextPage: viewModel.isLoadingNextPage,
                        nextPageError: viewModel.nextPageError,
                        onLoadNextPage: loadNextPage,
                        onRetryNextPage: retryNextPage
                    )
                }
            }

        case let .failed(presentation):
            PublicProfileFailureState(
                presentation: presentation,
                onRetry: retryInitialLoad,
                onSignIn: performLogout
            )
        }
    }

    private func profileHeader(
        _ profile: PublicProfileHeaderViewData
    ) -> some View {
        VStack(spacing: MaplogSpacing.medium) {
            HStack(spacing: MaplogSpacing.medium) {
                MaplogProfileAvatar(
                    imageData: viewModel.avatarImageData,
                    nickname: profile.nickname,
                    size: 84,
                    fallbackBackground: Color.maplogCanvas,
                    fallbackForeground: Color.maplogOlive,
                    borderColor: .white.opacity(0.64)
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(profile.nickname)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.maplogInk)

                    Text("(profile.joinedAtText)부터 Maplog 기록 중")
                        .font(.caption)
                        .foregroundStyle(Color.maplogMuted)
                }

                Spacer(minLength: 0)
            }

            if !profile.bio.isEmpty {
                Text(profile.bio)
                    .font(.subheadline)
                    .foregroundStyle(Color.maplogTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            PublicProfileStats(
                logCountText: profile.logCountText,
                followerCountText: profile.followerCountText,
                followingCountText: profile.followingCountText
            )

            followButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var followButton: some View {
        if viewModel.isOwnProfile {
            Text("내 프로필")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.maplogMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
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
                .frame(height: 44)
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

    private func toggleFollow() {
        Task {
            guard let state = await viewModel.toggleFollow() else {
                return
            }

            onFollowStateChanged(state)
        }
    }
}

private struct PublicProfileStats: View {
    let logCountText: String
    let followerCountText: String
    let followingCountText: String

    var body: some View {
        HStack(spacing: 0) {
            statistic(title: "맵로그", value: logCountText)
            statistic(title: "팔로워", value: followerCountText)
            statistic(title: "팔로잉", value: followingCountText)
        }
        .padding(.vertical, MaplogSpacing.medium)
        .background(
            Color.maplogCanvas,
            in: RoundedRectangle(
                cornerRadius: MaplogRadius.medium,
                style: .continuous
            )
        )
    }

    private func statistic(
        title: String,
        value: String
    ) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.maplogInk)

            Text(title)
                .font(.caption)
                .foregroundStyle(Color.maplogMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PublicProfileLogSection: View {
    let nickname: String
    let logCountText: String
    let logs: [ProfileLogCardViewData]
    let thumbnailData: (Int64) -> Data?
    let isLoadingThumbnail: (Int64) -> Bool
    let hasNextPage: Bool
    let isLoadingNextPage: Bool
    let nextPageError: ErrorPresentation?
    let onLoadNextPage: () -> Void
    let onRetryNextPage: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: MaplogSpacing.small),
        GridItem(.flexible(), spacing: MaplogSpacing.small)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(nickname)의 맵로그")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.maplogInk)

                Text(logCountText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.maplogMuted)
            }

            if logs.isEmpty {
                VStack(spacing: MaplogSpacing.small) {
                    Image(systemName: "map")
                        .font(.title2)
                        .foregroundStyle(Color.maplogOlive)

                    Text("아직 공개한 맵로그가 없어요")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.maplogInk)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 52)
                .background(
                    Color.maplogCanvas,
                    in: RoundedRectangle(
                        cornerRadius: MaplogRadius.medium,
                        style: .continuous
                    )
                )
            } else {
                LazyVGrid(columns: columns, spacing: MaplogSpacing.medium) {
                    ForEach(logs) { log in
                        PublicProfileLogCard(
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
                .padding(.vertical, MaplogSpacing.small)
        } else if let nextPageError {
            VStack(spacing: MaplogSpacing.xxSmall) {
                Text(nextPageError.message)
                    .font(.caption)
                    .foregroundStyle(Color.maplogMuted)
                    .multilineTextAlignment(.center)

                if nextPageError.recoveryAction == .retry {
                    Button("더 불러오기", action: onRetryNextPage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.maplogOlive)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, MaplogSpacing.small)
        } else if hasNextPage {
            Color.clear
                .frame(height: 1)
                .onAppear(perform: onLoadNextPage)
        }
    }
}

private struct PublicProfileLogCard: View {
    let log: ProfileLogCardViewData
    let thumbnailData: Data?
    let isLoadingThumbnail: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
            thumbnail
                .frame(height: 156)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: MaplogRadius.medium,
                        style: .continuous
                    )
                )
                .overlay(alignment: .bottomLeading) {
                    Label(log.viewCountText, systemImage: "eye.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.64), radius: 2, x: 0, y: 1)
                        .padding(MaplogSpacing.xSmall)
                }
                .overlay(alignment: .bottomTrailing) {
                    Text(log.durationText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.64), radius: 2, x: 0, y: 1)
                        .padding(MaplogSpacing.xSmall)
                }

            Text(log.addressText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.maplogInk)
                .lineLimit(1)

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
        .padding(.vertical, 110)
    }
}
