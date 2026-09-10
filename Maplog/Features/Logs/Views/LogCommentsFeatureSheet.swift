import SwiftUI

/// 홈 릴스의 댓글 버튼에서 여는 실제 API 기반 댓글 시트입니다.
/// 기존 VlogCommentsSheet는 목업 데이터 전용이므로 이 화면과 분리합니다.
struct LogCommentsFeatureSheet: View {
    @Environment(\.maplogLogout) private var performLogout
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isComposerFocused: Bool
    @StateObject private var viewModel: LogCommentsViewModel
    @State private var draft = ""
    @State private var composerMode: ComposerMode = .new
    @State private var commentPendingDeletion: LogComment?
    @State private var selectedAuthor: FollowUser?
    private let initialCommentID: Int64?
    @State private var didScrollToComment = false
    private let followRepository: any FollowRepository
    private let profileRepository: any ProfileRepository

    init(
        logID: Int64,
        commentRepository: any LogCommentRepository,
        profileRepository: any ProfileRepository,
        followRepository: any FollowRepository,
        onCommentCountChange: @escaping (Int64) -> Void,
        initialCommentID: Int64? = nil
    ) {
        self.initialCommentID = initialCommentID
        self.followRepository = followRepository
        self.profileRepository = profileRepository
        _viewModel = StateObject(
            wrappedValue: LogCommentsViewModel(
                logID: logID,
                commentRepository: commentRepository,
                profileRepository: profileRepository,
                onCommentCountChange: onCommentCountChange
            )
        )
    }

    private enum ComposerMode: Equatable {
        case new
        case reply(LogComment)
        case edit(LogComment)

        var parentCommentID: Int64? {
            if case let .reply(comment) = self {
                return comment.id
            }

            return nil
        }

        var title: String? {
            switch self {
            case .new:
                return nil

            case let .reply(comment):
                return "@\(comment.author.nickname)님에게 답글 작성 중"

            case .edit:
                return "댓글 수정 중"
            }
        }

        var sendAccessibilityLabel: String {
            switch self {
            case .new:
                return "댓글 등록"
            case .reply:
                return "답글 등록"
            case .edit:
                return "댓글 수정 완료"
            }
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

    private var deleteConfirmationPresented: Binding<Bool> {
        Binding(
            get: { commentPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    commentPendingDeletion = nil
                }
            }
        )
    }

    private var topLevelComments: [LogComment] {
        viewModel.comments.filter { $0.parentCommentID == nil }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                if viewModel.isRequestedCommentUnavailable(initialCommentID) {
                    Text("알림의 댓글이 삭제되었거나 더 이상 표시되지 않아요.")
                        .font(.subheadline)
                        .foregroundStyle(Color.maplogMuted)
                        .padding(MaplogSpacing.medium)
                }
                commentsContent
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composer
            }
            .background(Color.maplogSurface)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.loadInitialComments()
            }
            .alert(
                "작업을 완료하지 못했어요",
                isPresented: actionErrorPresented
            ) {
                switch viewModel.actionError?.recoveryAction {
                case .retry:
                    Button("다시 시도") {
                        Task {
                            await viewModel.retryLastAction()
                        }
                    }

                case .signIn:
                    Button("다시 로그인", action: performLogout)

                case .some(.none), nil:
                    EmptyView()
                }

                Button("확인", role: .cancel) {
                    viewModel.dismissActionError()
                }
            } message: {
                Text(viewModel.actionError?.message ?? "")
            }
            .confirmationDialog(
                "댓글을 삭제할까요?",
                isPresented: deleteConfirmationPresented,
                titleVisibility: .visible
            ) {
                if let comment = commentPendingDeletion {
                    Button("삭제", role: .destructive) {
                        Task {
                            await viewModel.deleteComment(commentID: comment.id)
                        }
                    }
                }

                Button("취소", role: .cancel) {}
            } message: {
                Text("삭제한 댓글은 되돌릴 수 없어요.")
            }
            .navigationDestination(item: $selectedAuthor) { author in
                PublicProfileFeatureView(
                    user: author,
                    followRepository: followRepository,
                    profileRepository: profileRepository
                )
            }
        }
    }

    private var header: some View {
        VStack(spacing: MaplogSpacing.small) {
            Capsule()
                .fill(Color.maplogMuted.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, MaplogSpacing.xSmall)
                .accessibilityHidden(true)

            Text("댓글 \(viewModel.activeCommentCount)")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.maplogInk)
                .padding(.bottom, MaplogSpacing.xSmall)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var commentsContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .tint(Color.maplogLime)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .empty:
            VStack(spacing: MaplogSpacing.small) {
                Image(systemName: "message")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(Color.maplogMuted)
                Text("첫 댓글을 남겨보세요")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.maplogInk)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case let .failed(presentation):
            VStack(spacing: MaplogSpacing.medium) {
                Image(systemName: "exclamationmark.bubble")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(Color.maplogMuted)
                Text(presentation.message)
                    .font(.subheadline)
                    .foregroundStyle(Color.maplogMuted)
                    .multilineTextAlignment(.center)
                if presentation.recoveryAction == .retry {
                    Button("다시 시도") {
                        Task {
                            await viewModel.retryLastAction()
                        }
                    }
                    .buttonStyle(MaplogPressFeedbackStyle())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.maplogOnPrimary)
                    .padding(.horizontal, MaplogSpacing.medium)
                    .frame(height: MaplogSize.controlHeight)
                    .background(Color.maplogLime, in: Capsule())
                }
            }
            .padding(MaplogSpacing.xLarge)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .content:
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    Group {
                        if initialCommentID != nil {
                            // 알림의 답글이 화면 밖에 있어도 정확한 위치를 계산하도록 배치합니다.
                            VStack(alignment: .leading, spacing: MaplogSpacing.large) {
                                commentThreads
                            }
                        } else {
                            LazyVStack(alignment: .leading, spacing: MaplogSpacing.large) {
                                commentThreads
                            }
                        }
                    }
                    .padding(.horizontal, MaplogSpacing.page)
                    .padding(.top, MaplogSpacing.small)
                    .padding(.bottom, MaplogSpacing.xLarge)
                }
                .scrollDismissesKeyboard(.interactively)
                .task(id: viewModel.comments.map(\.id)) {
                    guard !didScrollToComment,
                          let target = viewModel.notificationScrollTarget(initialCommentID) else { return }
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    proxy.scrollTo(target, anchor: .center)
                    didScrollToComment = true
                }
            }
        }
    }

    private var commentThreads: some View {
        ForEach(topLevelComments) { comment in
            commentThread(comment)
        }
    }

    private func commentThread(
        _ comment: LogComment
    ) -> some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.medium) {
            commentRow(comment)

            let replies = replies(for: comment)
            if !replies.isEmpty {
                VStack(alignment: .leading, spacing: MaplogSpacing.medium) {
                    ForEach(replies) { reply in
                        commentRow(reply, isReply: true)
                    }
                }
                .padding(.leading, 44)
            }
        }
    }

    private func commentRow(
        _ comment: LogComment,
        isReply: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: MaplogSpacing.small) {
            Button {
                selectedAuthor = FollowUser(
                    id: comment.author.id,
                    nickname: comment.author.nickname,
                    profileImageURL: comment.author.profileImageURL
                )
            } label: {
                CommentAvatar(
                    imageData: viewModel.profileImageData(for: comment.author),
                    nickname: comment.author.nickname,
                    size: isReply ? 30 : 38
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(comment.author.nickname) 프로필 보기")

            VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                HStack(alignment: .firstTextBaseline, spacing: MaplogSpacing.xxSmall) {
                    Text(comment.author.nickname)
                        .font((isReply ? Font.subheadline : Font.body).weight(.semibold))
                        .foregroundStyle(Color.maplogInk)

                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(
                            LogCommentRelativeTimeFormatter.text(
                                for: comment.createdAt,
                                relativeTo: context.date
                            )
                        )
                    }
                    .font(.caption)
                    .foregroundStyle(Color.maplogMuted)

                    Spacer(minLength: 0)

                    if viewModel.isOwnedByViewer(comment), !comment.isDeleted {
                        commentMenu(for: comment)
                    }
                }

                if comment.isDeleted {
                    Text("삭제된 댓글입니다.")
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(Color.maplogMuted)
                        .padding(.vertical, MaplogSpacing.xxxSmall)
                } else {
                    Text(comment.content)
                        .font(isReply ? .subheadline : .body)
                        .foregroundStyle(Color.maplogInk)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: MaplogSpacing.small) {
                        if !isReply {
                            Button("답글 달기") {
                                startReply(to: comment)
                            }
                            .buttonStyle(MaplogPressFeedbackStyle())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.maplogMuted)
                            .frame(minHeight: 32)
                        }

                        Spacer(minLength: 0)

                        commentLikeButton(for: comment)
                    }
                }
            }
        }
        .padding(.vertical, comment.id == initialCommentID ? MaplogSpacing.xSmall : 0)
        .background {
            if comment.id == initialCommentID {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.maplogLime.opacity(0.18))
            }
        }
        .id(comment.id)
        .opacity(viewModel.isUpdating(commentID: comment.id) ? 0.58 : 1)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.18),
            value: viewModel.isUpdating(commentID: comment.id)
        )
        .task(id: comment.author.profileImageURL) {
            await viewModel.loadProfileImage(for: comment.author)
        }
    }

    private func commentMenu(
        for comment: LogComment
    ) -> some View {
        Menu {
            Button("수정") {
                startEditing(comment)
            }

            Button("삭제", role: .destructive) {
                commentPendingDeletion = comment
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.maplogMuted)
                .frame(width: MaplogSize.minimumTapTarget, height: 28)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("내 댓글 메뉴")
    }

    private func commentLikeButton(
        for comment: LogComment
    ) -> some View {
        Button {
            Task {
                await viewModel.toggleLike(for: comment)
            }
        } label: {
            HStack(spacing: 4) {
                if viewModel.isUpdating(commentID: comment.id) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.maplogMuted)
                } else {
                    Image(
                        systemName: comment.isLikedByViewer
                            ? "heart.fill"
                            : "heart"
                    )
                    .font(.system(size: 15, weight: .semibold))
                }

                if comment.likeCount > 0 {
                    Text("\(comment.likeCount)")
                        .font(.caption.weight(.semibold))
                }
            }
            .foregroundStyle(
                comment.isLikedByViewer
                    ? Color.maplogLime
                    : Color.maplogMuted
            )
            .frame(minWidth: MaplogSize.minimumTapTarget, minHeight: 32)
        }
        .buttonStyle(MaplogPressFeedbackStyle())
        .disabled(viewModel.isUpdating(commentID: comment.id))
        .accessibilityLabel(
            comment.isLikedByViewer
                ? "댓글 좋아요 취소"
                : "댓글 좋아요"
        )
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
            if let title = composerMode.title {
                HStack(spacing: MaplogSpacing.xSmall) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.maplogMuted)

                    Spacer(minLength: 0)

                    Button("취소") {
                        resetComposer()
                    }
                    .buttonStyle(MaplogPressFeedbackStyle())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.maplogMuted)
                }
            }

            HStack(spacing: MaplogSpacing.xSmall) {
                HStack(spacing: MaplogSpacing.xSmall) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 25))
                        .foregroundStyle(Color.maplogMuted)

                    TextField(
                        "",
                        text: $draft,
                        prompt: Text(composerPrompt)
                            .foregroundStyle(Color.maplogMuted)
                    )
                    .font(.body)
                    .foregroundStyle(Color.maplogInk)
                    .tint(Color.maplogLime)
                    .focused($isComposerFocused)
                    .submitLabel(.send)
                    .onSubmit(submitComposer)
                    .accessibilityLabel(composerMode.sendAccessibilityLabel)
                }
                .padding(.horizontal, MaplogSpacing.small)
                .frame(maxWidth: .infinity, minHeight: MaplogSize.controlHeight)
                .background(Color.maplogCanvas, in: Capsule())

                Button(action: submitComposer) {
                    if viewModel.isSending {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color.maplogInk)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 17, weight: .bold))
                    }
                }
                .buttonStyle(MaplogPressFeedbackStyle())
                .foregroundStyle(Color.maplogOnPrimary)
                .frame(
                    width: MaplogSize.controlHeight,
                    height: MaplogSize.controlHeight
                )
                .background(Color.maplogLime, in: Circle())
                .disabled(!canSubmit || viewModel.isSending)
                .opacity(canSubmit ? 1 : 0.46)
                .accessibilityLabel(composerMode.sendAccessibilityLabel)
            }
        }
        .padding(.horizontal, MaplogSpacing.page)
        .padding(.top, MaplogSpacing.small)
        .padding(.bottom, MaplogSpacing.small)
        .background(Color.maplogSurface)
    }

    private var composerPrompt: String {
        switch composerMode {
        case .new:
            return "댓글을 입력하세요"
        case .reply:
            return "답글을 입력하세요"
        case .edit:
            return "댓글을 수정하세요"
        }
    }

    private var canSubmit: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func replies(
        for comment: LogComment
    ) -> [LogComment] {
        viewModel.comments.filter { $0.parentCommentID == comment.id }
    }

    private func startReply(
        to comment: LogComment
    ) {
        composerMode = .reply(comment)
        isComposerFocused = true
    }

    private func startEditing(
        _ comment: LogComment
    ) {
        draft = comment.content
        composerMode = .edit(comment)
        isComposerFocused = true
    }

    private func resetComposer() {
        draft = ""
        composerMode = .new
        isComposerFocused = false
    }

    private func submitComposer() {
        guard canSubmit,
              !viewModel.isSending
        else {
            return
        }

        Task {
            let didSucceed: Bool

            switch composerMode {
            case .new, .reply:
                didSucceed = await viewModel.createComment(
                    draft: LogCommentDraft(
                        content: draft,
                        parentCommentID: composerMode.parentCommentID
                    )
                )

            case let .edit(comment):
                didSucceed = await viewModel.updateComment(
                    commentID: comment.id,
                    content: draft
                )
            }

            if didSucceed {
                resetComposer()
            }
        }
    }
}

private struct CommentAvatar: View {
    let imageData: Data?
    let nickname: String
    let size: CGFloat

    var body: some View {
        MaplogProfileAvatar(
            imageData: imageData,
            nickname: nickname,
            size: size
        )
    }
}
