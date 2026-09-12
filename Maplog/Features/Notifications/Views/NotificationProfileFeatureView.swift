import SwiftUI

struct NotificationProfileFeatureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.maplogLogout) private var performLogout
    @StateObject private var viewModel: NotificationProfileViewModel
    private let profileRepository: any ProfileRepository
    private let followRepository: any FollowRepository

    init(
        userID: UUID,
        notificationRepository: any NotificationRepository,
        profileRepository: any ProfileRepository,
        followRepository: any FollowRepository
    ) {
        _viewModel = StateObject(wrappedValue: NotificationProfileViewModel(
            userID: userID,
            repository: notificationRepository
        ))
        self.profileRepository = profileRepository
        self.followRepository = followRepository
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("프로필을 찾고 있어요")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .content(user):
                PublicProfileFeatureView(
                    user: user,
                    followRepository: followRepository,
                    profileRepository: profileRepository
                )
            case let .failed(error):
                VStack(spacing: MaplogSpacing.medium) {
                    Text(error.message)
                        .multilineTextAlignment(.center)
                    if error.recoveryAction == .retry {
                        Button("다시 시도") { Task { await viewModel.load() } }
                    } else if error.recoveryAction == .signIn {
                        Button("다시 로그인", action: performLogout)
                    }
                    Button("알림 목록으로") { dismiss() }
                }
                .padding(MaplogSpacing.page)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.maplogCanvas)
        .toolbar(.visible, for: .navigationBar)
        .maplogTabBarHidden()
        .task {
            if viewModel.state == .idle { await viewModel.load() }
        }
    }
}
