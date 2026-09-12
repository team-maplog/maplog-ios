import SwiftUI

struct BlockedUsersView: View {
    @Environment(\.maplogLogout) private var signIn
    @StateObject private var viewModel: BlockedUsersViewModel
    private let profileRepository: any ProfileRepository
    private let followRepository: any FollowRepository
    @State private var selectedProfile: BlockedUser?
    @State private var selectedUser: BlockedUser?

    init(repository: any ContentModerationRepository,
         profileRepository: any ProfileRepository, followRepository: any FollowRepository) {
        self.profileRepository = profileRepository
        self.followRepository = followRepository
        _viewModel = StateObject(wrappedValue: BlockedUsersViewModel(repository: repository))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("차단한 사용자의 로그는 표시되지 않아요. 여기에서 차단을 해제할 수 있어요.")
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogMuted)
                if let error = viewModel.error { errorContent(error, retry: { await viewModel.reload() }) }
                if viewModel.hasLoaded, viewModel.users.isEmpty, viewModel.error == nil {
                    Text("차단한 사용자가 없어요")
                        .frame(maxWidth: .infinity).padding(.vertical, 48)
                }
                ForEach(viewModel.users) { user in
                    HStack(spacing: 16) {
                        if user.canOpenProfile {
                            Button {
                                selectedProfile = user
                            } label: {
                                Text(user.nickname).font(MaplogFont.body)
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text(user.nickname).font(MaplogFont.body)
                        }
                        Spacer()
                        Button("차단 해제") { selectedUser = user }
                            .font(MaplogFont.caption)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .overlay(Capsule().stroke(Color.maplogLine, lineWidth: 1))
                            .disabled(viewModel.isLoading || viewModel.unblockingID != nil)
                    }
                }
                if viewModel.isLoading || viewModel.unblockingID != nil {
                    ProgressView().frame(maxWidth: .infinity)
                }
                if let error = viewModel.nextPageError {
                    errorContent(error, retry: { await viewModel.loadNextPage() })
                } else if viewModel.hasNext, !viewModel.isLoading {
                    Button("더 보기") { Task { await viewModel.loadNextPage() } }
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(MaplogSpacing.page)
        }
        .background(Color.maplogSurface)
        .foregroundStyle(Color.maplogInk)
        .navigationTitle("차단 목록")
        .navigationBarTitleDisplayMode(.inline)
        .task { if !viewModel.hasLoaded { await viewModel.reload() } }
        .refreshable { await viewModel.reload() }
        .navigationDestination(item: $selectedProfile) { user in
            PublicProfileFeatureView(
                user: FollowUser(id: user.id, nickname: user.nickname, profileImageURL: nil),
                followRepository: followRepository, profileRepository: profileRepository
            )
        }
        .onAppear { viewModel.beginManagingBlocks() }
        .onDisappear {
            if selectedProfile == nil { viewModel.finishManagingBlocks() }
        }
        .confirmationDialog("차단을 해제할까요?", isPresented: Binding(
            get: { selectedUser != nil }, set: { if !$0 { selectedUser = nil } }
        ), titleVisibility: .visible) {
            if let user = selectedUser {
                Button("차단 해제") { Task { await viewModel.unblock(user) } }
            }
            Button("취소", role: .cancel) { selectedUser = nil }
        } message: {
            Text("상대방이 나를 차단한 경우에는 내가 해제해도 로그를 볼 수 없어요.")
        }
    }

    private func errorContent(_ error: ErrorPresentation, retry: @escaping () async -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(error.message).font(MaplogFont.caption)
            if error.recoveryAction == .signIn {
                Button("다시 로그인", action: signIn)
            } else if error.recoveryAction == .retry {
                Button("다시 시도") { Task { await retry() } }.frame(minHeight: 44)
            }
        }
    }
}
