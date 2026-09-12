import SwiftUI

struct ProfileSettingsFeatureView: View {
    @Environment(\.contentModerationRepository) private var moderationRepository
    @Environment(\.maplogLogout) private var performLogout
    @EnvironmentObject private var signOutViewModel: SignOutViewModel

    private let profile: ProfileHeaderViewData
    private let avatarImageData: Data?
    private let socialConnectionRepository: any SocialConnectionRepository
    private let followRepository: any FollowRepository
    private let profileRepository: any ProfileRepository
    private let onProfileSaved: () async -> Void

    @StateObject private var viewModel: ProfileSettingsViewModel
    @State private var showsLogoutConfirmation = false
    @State private var showsWithdrawalConfirmation = false

    init(
        profile: ProfileHeaderViewData,
        avatarImageData: Data?,
        profileRepository: any ProfileRepository,
        followRepository: any FollowRepository,
        socialConnectionRepository: any SocialConnectionRepository,
        onProfileSaved: @escaping () async -> Void
    ) {
        self.profile = profile
        self.avatarImageData = avatarImageData
        self.followRepository = followRepository
        self.profileRepository = profileRepository
        self.socialConnectionRepository = socialConnectionRepository
        self.onProfileSaved = onProfileSaved
        _viewModel = StateObject(
            wrappedValue: ProfileSettingsViewModel(
                profileRepository: profileRepository
            )
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                ProfileSettingsSection(title: "계정") {
                    NavigationLink {
                        ProfileEditFeatureView(
                            profile: profile,
                            avatarImageData: avatarImageData,
                            profileRepository: profileRepository,
                            onSaved: onProfileSaved
                        )
                    } label: {
                        ProfileSettingsNavigationRow(
                            title: "프로필 편집"
                        )
                    }
                    .buttonStyle(.plain)
                }

                ProfileSettingsSection(title: "로그인 방법") {
                    NavigationLink {
                        SocialConnectionsView(repository: socialConnectionRepository)
                    } label: {
                        ProfileSettingsNavigationRow(title: "소셜 계정 관리")
                    }
                }

                if let moderationRepository {
                    ProfileSettingsSection(title: "개인정보 및 안전") {
                        NavigationLink {
                            BlockedUsersView(repository: moderationRepository,
                                             profileRepository: profileRepository, followRepository: followRepository)
                        } label: {
                            ProfileSettingsNavigationRow(title: "차단 목록")
                        }
                    }
                }

                ProfileSettingsSection(title: "서비스 정보") {
                    Link(destination: MaplogLegalLinks.terms) {
                        ProfileSettingsNavigationRow(title: "이용약관")
                    }
                    ProfileSettingsDivider()
                    Link(destination: MaplogLegalLinks.privacy) {
                        ProfileSettingsNavigationRow(title: "개인정보 처리방침")
                    }
                    ProfileSettingsDivider()
                    Link(destination: MaplogLegalLinks.support) {
                        ProfileSettingsNavigationRow(title: "문의하기")
                    }
                }

                ProfileSettingsSection(title: "앱 정보") {
                    ProfileSettingsValueRow(
                        title: "현재 버전",
                        value: appVersion
                    )
                }

                ProfileSettingsSection(title: "기타") {
                    Button(action: requestLogout) {
                        ProfileSettingsActionRow(
                            title: signOutViewModel.isLoading
                                ? "로그아웃 중..."
                                : "로그아웃"
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(signOutViewModel.isLoading)

                    ProfileSettingsDivider()

                    Button(action: requestWithdrawal) {
                        ProfileSettingsActionRow(
                            title: viewModel.isDeletingAccount
                                ? "탈퇴 처리 중..."
                                : "회원 탈퇴",
                            tint: .red
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isDeletingAccount)
                }

                if let errorMessage = signOutViewModel.errorMessage ?? viewModel.deleteErrorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, MaplogSpacing.page)
            .padding(.top, 24)
            .maplogListBottomPadding()
        }
        .background(Color.maplogSurface)
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .maplogTabBarHidden()
        .confirmationDialog(
            "로그아웃할까요?",
            isPresented: $showsLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("로그아웃", action: signOut)
            Button("취소", role: .cancel) {}
        } message: {
            Text("현재 계정으로 다시 로그인할 수 있습니다.")
        }
        .confirmationDialog(
            "정말 회원 탈퇴할까요?",
            isPresented: $showsWithdrawalConfirmation,
            titleVisibility: .visible
        ) {
            Button("회원 탈퇴", role: .destructive, action: deleteAccount)
            Button("취소", role: .cancel) {}
        } message: {
            Text("계정과 연결된 데이터는 복구할 수 없습니다.")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "-"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String

        guard let build, !build.isEmpty else {
            return "v\(version)"
        }

        return "v\(version) (\(build))"
    }

    private func requestLogout() {
        showsLogoutConfirmation = true
    }

    private func requestWithdrawal() {
        showsWithdrawalConfirmation = true
    }

    private func signOut() {
        Task {
            await signOutViewModel.signOut()
        }
    }

    private func deleteAccount() {
        Task {
            guard await viewModel.deleteAccount() else {
                return
            }

            performLogout()
        }
    }
}

private struct ProfileSettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.maplogMuted)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 16)
            .background(
                Color.maplogCanvas,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
        }
    }
}

private struct ProfileSettingsNavigationRow: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundStyle(Color.maplogInk)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.maplogMuted)
        }
        .frame(minHeight: 54)
    }
}

private struct ProfileSettingsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Color.maplogInk)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.maplogMuted)
            }
            .padding(.vertical, 12)
        }
        .tint(Color.maplogLime)
    }
}

private struct ProfileSettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundStyle(Color.maplogInk)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundStyle(Color.maplogMuted)
        }
        .frame(minHeight: 54)
    }
}

private struct ProfileSettingsActionRow: View {
    let title: String
    var tint: Color = .maplogInk

    var body: some View {
        Text(title)
            .font(.body.weight(.semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 54)
    }
}

private struct ProfileSettingsDivider: View {
    var body: some View {
        Divider()
            .overlay(Color.maplogLine)
    }
}
