import SwiftUI

struct LogDetailFeatureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.maplogLogout) private var performLogout

    private let initialCommentID: Int64?
    private let commentRepository: (any LogCommentRepository)?
    @State private var showsNotificationComment = false
    @State private var didOpenNotificationComment = false

    private let allowsManagement: Bool
    private let onLogRemoved: () async -> Void
    private let followRepository: any FollowRepository
    private let profileRepository: any ProfileRepository

    @StateObject private var viewModel: LogDetailViewModel
    @State private var showsCaptionEditor = false
    @State private var showsDeletionConfirmation = false

    private var captionBinding: Binding<String> {
        Binding(
            get: { viewModel.captionDraft },
            set: viewModel.updateCaptionDraft
        )
    }

    init(
        logID: Int64,
        allowsManagement: Bool,
        logDetailRepository: any LogDetailRepository,
        logMediaRepository: any LogMediaRepository,
        followRepository: any FollowRepository,
        profileRepository: any ProfileRepository,
        playbackService: any VideoPlaybackService,
        onLogRemoved: @escaping () async -> Void,
        initialCommentID: Int64? = nil,
        commentRepository: (any LogCommentRepository)? = nil
    ) {
        self.initialCommentID = initialCommentID
        self.commentRepository = commentRepository
        self.allowsManagement = allowsManagement
        self.onLogRemoved = onLogRemoved
        self.followRepository = followRepository
        self.profileRepository = profileRepository

        _viewModel = StateObject(
            wrappedValue: LogDetailViewModel(
                logID: logID,
                logDetailRepository: logDetailRepository,
                logMediaRepository: logMediaRepository,
                playbackService: playbackService,
                automaticallyPlays: initialCommentID == nil,
                profileRepository: profileRepository
            )
        )
    }

    var body: some View {
        LogDetailView(
            state: viewModel.state,
            detail: viewModel.detail,
            player: viewModel.player,
            isLoadingPlayback: viewModel.isLoadingPlayback,
            playbackErrorMessage: viewModel.playbackErrorMessage,
            clipThumbnailDataByID: viewModel.clipThumbnailDataByID,
            loadingClipThumbnailIDs: viewModel.loadingClipThumbnailIDs,
            playbackProgress: viewModel.playbackProgress,
            isPlaying: viewModel.isPlaying,
            onRetryDetail: retryDetail,
            onRetryPlayback: retryPlayback,
            onPlaybackToggle: viewModel.togglePlayback,
            onSeekPlayback: viewModel.seekPlayback,
            onSignIn: performLogout
        )
        .navigationBarTitleDisplayMode(.inline)
        .maplogTabBarHidden()
        .overlay {
            if showsDeletionConfirmation {
                LogDeleteConfirmationOverlay(
                    isDeleting: viewModel.isDeleting,
                    onCancel: dismissDeletionConfirmation,
                    onConfirm: confirmDeletion
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: showsDeletionConfirmation)
        .toolbar {
            ToolbarItem(placement: .principal) {
                LogDetailNavigationAuthor(
                    detail: viewModel.detail,
                    imageData: viewModel.authorImageData,
                    followRepository: followRepository,
                    profileRepository: profileRepository
                )
            }

            if allowsManagement,
               viewModel.detail != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: presentCaptionEditor) {
                            Label("게시물 수정", systemImage: "pencil")
                        }
                        .accessibilityIdentifier("log.detail.edit")

                        Button(role: .destructive, action: presentDeletionConfirmation) {
                            Label("맵로그 삭제", systemImage: "trash")
                        }
                        .accessibilityIdentifier("log.detail.delete")
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: MaplogSize.iconMedium, weight: .semibold))
                            .foregroundStyle(Color.maplogInk)
                            .frame(
                                width: MaplogSize.minimumTapTarget,
                                height: MaplogSize.minimumTapTarget
                            )
                            // 보이는 점 세 개보다 넓은 44pt 사각 영역 전체를 메뉴의 터치 대상으로 만듭니다.
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityLabel("맵로그 관리")
                    .accessibilityHint("게시물 수정 또는 맵로그 삭제 메뉴를 엽니다")
                    .accessibilityIdentifier("log.detail.management")
                }
            }
        }
        .task {
            await loadDetail()
        }
        .onChange(of: viewModel.detail != nil) { _, isLoaded in
            guard isLoaded, initialCommentID != nil, commentRepository != nil,
                  !didOpenNotificationComment else { return }
            didOpenNotificationComment = true
            showsNotificationComment = true
            viewModel.pausePlayback()
        }
        .sheet(isPresented: $showsNotificationComment) {
            if let detail = viewModel.detail, let commentRepository {
                LogCommentsFeatureSheet(
                    logID: detail.id,
                    commentRepository: commentRepository,
                    profileRepository: profileRepository,
                    followRepository: followRepository,
                    onCommentCountChange: { _ in },
                    initialCommentID: initialCommentID
                )
            }
        }
        .onDisappear {
            guard !showsCaptionEditor else {
                return
            }

            viewModel.stopPlayback()
        }
        .fullScreenCover(
            isPresented: $showsCaptionEditor,
            onDismiss: finishCaptionEditing
        ) {
            captionEditScreen
        }
        .alert(
            "맵로그를 삭제하지 못했어요",
            isPresented: deletionErrorPresented
        ) {
            deletionErrorActions
        } message: {
            Text(viewModel.deletionError?.message ?? "")
        }
    }

    @ViewBuilder
    private var captionEditScreen: some View {
        if let detail = viewModel.detail {
            NavigationStack {
                LogCaptionEditView(
                    caption: captionBinding,
                    thumbnailData: viewModel.thumbnailData,
                    address: detail.address,
                    isSaving: viewModel.isSavingCaption,
                    formMessage: viewModel.captionFormMessage,
                    captionMessage: viewModel.captionMessage,
                    recoveryAction: viewModel.captionRecoveryAction,
                    onSave: saveCaption,
                    onCancel: cancelCaptionEditing,
                    onSignIn: performLogout
                )
            }
        }
    }

    private var deletionErrorPresented: Binding<Bool> {
        Binding(
            get: { viewModel.deletionError != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissDeletionError()
                }
            }
        )
    }

    @ViewBuilder
    private var deletionErrorActions: some View {
        if viewModel.deletionError?.recoveryAction == .retry {
            Button("다시 시도", action: deleteLog)
        }

        if viewModel.deletionError?.recoveryAction == .signIn {
            Button("다시 로그인", action: performLogout)
        }

        Button("확인", role: .cancel) {
            viewModel.dismissDeletionError()
        }
    }

    private func loadDetail() async {
        await viewModel.loadIfNeeded()
        await dismissIfLogIsUnavailable()
    }

    private func retryDetail() {
        Task {
            await viewModel.retryInitialLoad()
            await dismissIfLogIsUnavailable()
        }
    }

    private func retryPlayback() {
        Task {
            await viewModel.loadPlayback()
        }
    }

    private func presentCaptionEditor() {
        viewModel.beginCaptionEditing()
        viewModel.pausePlayback()
        showsCaptionEditor = true
    }

    private func cancelCaptionEditing() {
        viewModel.cancelCaptionEditing()
        viewModel.resumePlayback()
    }

    private func finishCaptionEditing() {
        // 버튼이 아닌 시스템 제스처로 닫혀도 초안과 영상 재생 상태를 복구합니다.
        cancelCaptionEditing()
    }

    private func presentDeletionConfirmation() {
        showsDeletionConfirmation = true
    }

    private func dismissDeletionConfirmation() {
        guard !viewModel.isDeleting else {
            return
        }

        showsDeletionConfirmation = false
    }

    private func confirmDeletion() {
        guard !viewModel.isDeleting else {
            return
        }

        showsDeletionConfirmation = false
        deleteLog()
    }

    private func saveCaption() {
        Task {
            guard await viewModel.saveCaption() else {
                return
            }

            viewModel.resumePlayback()
            showsCaptionEditor = false
        }
    }

    private func deleteLog() {
        Task {
            guard await viewModel.deleteLog() else {
                return
            }

            await removeLogAndDismiss()
        }
    }

    private func dismissIfLogIsUnavailable() async {
        guard viewModel.shouldRemoveFromSourceList else {
            return
        }

        await removeLogAndDismiss()
    }

    private func removeLogAndDismiss() async {
        await onLogRemoved()
        dismiss()
    }
}

private struct LogDetailNavigationAuthor: View {
    let detail: LogDetail?
    let imageData: Data?
    let followRepository: any FollowRepository
    let profileRepository: any ProfileRepository

    var body: some View {
        Group {
            if let author = detail?.author {
                NavigationLink {
                    PublicProfileFeatureView(
                        user: FollowUser(
                            id: author.id,
                            nickname: author.nickname,
                            profileImageURL: author.profileImageURL
                        ),
                        followRepository: followRepository,
                        profileRepository: profileRepository
                    )
                } label: {
                    authorLabel
                }
                .buttonStyle(.plain)
                .accessibilityHint("작성자 프로필을 엽니다")
            } else {
                authorLabel
            }
        }
        .accessibilityLabel("\(nickname)의 맵로그")
    }

    private var authorLabel: some View {
        HStack(spacing: MaplogSpacing.xSmall) {
            MaplogProfileAvatar(
                imageData: imageData,
                nickname: nickname,
                size: 28
            )

            Text(nickname)
                .font(MaplogFont.calloutStrong)
                .foregroundStyle(Color.maplogInk)
                .lineLimit(1)
        }
    }

    private var nickname: String {
        detail?.author.nickname ?? "맵로그"
    }

    private var initial: String {
        String(nickname.prefix(1))
    }
}
