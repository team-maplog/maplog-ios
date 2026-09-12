import SwiftUI

/// 홈 릴스의 댓글 버튼에서 여는 실제 API 기반 댓글 시트입니다.
/// 기존 VlogCommentsSheet는 목업 데이터 전용이므로 이 화면과 분리합니다.
struct LogCommentsFeatureSheet: View {
    @Environment(\.maplogLogout) private var performLogout
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isComposerFocused: Bool
    @ScaledMetric(relativeTo: .subheadline) private var commentTextSize = 15
    @ScaledMetric(relativeTo: .subheadline) private var replyTextSize = 14
    @StateObject private var viewModel: LogCommentsViewModel
    @State private var draft = ""
    @State private var composerMode: ComposerMode = .new
    @State private var commentPendingDeletion: LogComment?
    @State private var commentPendingReport: LogComment?
    @State private var commentPendingBlock: LogComment?
    @State private var reportReason = ""
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
        case reply(target: LogComment, parentCommentID: Int64)
        case edit(LogComment)

        var parentCommentID: Int64? {
            if case let .reply(_, parentCommentID) = self {
                return parentCommentID
            }

            return nil
        }

        var title: String? {
            switch self {
            case .new:
                return nil

            case let .reply(comment, _):
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
                if viewModel.isModerating {
                    ProgressView("처리 중…")
                        .font(.caption)
                        .padding(.bottom, MaplogSpacing.small)
                }
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
            .alert(
                "댓글을 삭제할까요?",
                isPresented: deleteConfirmationPresented,
                presenting: commentPendingDeletion
            ) { comment in
                Button("취소", role: .cancel) {
                    commentPendingDeletion = nil
                }

                Button("삭제", role: .destructive) {
                    commentPendingDeletion = nil
                    Task {
                        await viewModel.deleteComment(commentID: comment.id)
                    }
                }
            } message: { _ in
                Text("삭제한 댓글은 되돌릴 수 없어요.")
            }
            .navigationDestination(item: $selectedAuthor) { author in
                PublicProfileFeatureView(
                    user: author,
                    followRepository: followRepository,
                    profileRepository: profileRepository
                )
            }
            .alert("댓글 신고", isPresented: Binding(
                get: { commentPendingReport != nil },
                set: { if !$0 { commentPendingReport = nil } }
            ), presenting: commentPendingReport) { comment in
                TextField("신고 사유 (최대 1,000자)", text: $reportReason)
                Button("취소", role: .cancel) { commentPendingReport = nil }
                Button("신고", role: .destructive) {
                    let reason = reportReason
                    Task { await viewModel.reportComment(commentID: comment.id, reason: reason) }
                }
                .disabled(reportReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || reportReason.utf16.count > 1000)
            } message: { _ in
                Text("이 댓글을 신고하는 이유를 알려주세요.")
            }
            .alert("사용자를 차단할까요?", isPresented: Binding(
                get: { commentPendingBlock != nil },
                set: { if !$0 { commentPendingBlock = nil } }
            ), presenting: commentPendingBlock) { comment in
                Button("취소", role: .cancel) { commentPendingBlock = nil }
                Button("차단", role: .destructive) {
                    Task { await viewModel.blockAuthor(userID: comment.author.id) }
                }
            } message: { comment in
                Text("\(comment.author.nickname)님과 서로의 로그와 댓글이 숨겨져요. 차단하면 홈으로 돌아갑니다.")
            }
            .alert("신고 접수", isPresented: Binding(
                get: { viewModel.moderationMessage != nil },
                set: { if !$0 { viewModel.moderationMessage = nil } }
            )) {
                Button("확인", role: .cancel) { viewModel.moderationMessage = nil }
            } message: {
                Text(viewModel.moderationMessage ?? "")
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
                            VStack(alignment: .leading, spacing: MaplogSpacing.medium) {
                                commentThreads
                            }
                        } else {
                            LazyVStack(alignment: .leading, spacing: MaplogSpacing.medium) {
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

    private struct CommentRowItem: Identifiable {
        let id: Int64
        let comment: LogComment
    }

    private var commentThreads: some View {
        ForEach(topLevelComments.map { CommentRowItem(id: viewModel.rowID(for: $0), comment: $0) }) { item in
            let comment = item.comment
            commentThread(comment)
        }
    }

    private func commentThread(
        _ comment: LogComment
    ) -> some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.small) {
            commentRow(comment)

            let replies = replies(for: comment)
            if !replies.isEmpty {
                VStack(alignment: .leading, spacing: MaplogSpacing.small) {
                    ForEach(replies.map { CommentRowItem(id: viewModel.rowID(for: $0), comment: $0) }) { item in
                        commentRow(item.comment, isReply: true)
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
            .disabled(viewModel.isLocal(comment))

            VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                HStack(alignment: .firstTextBaseline, spacing: MaplogSpacing.xxSmall) {
                    Text(comment.author.nickname)
                        .font(.system(size: isReply ? replyTextSize : commentTextSize, weight: .semibold))
                        .foregroundStyle(Color.maplogInk)

                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(
                            LogCommentRelativeTimeFormatter.text(
                                for: comment.createdAt,
                                relativeTo: context.date
                            )
                        )
                    }
                    .font(.caption2)
                    .foregroundStyle(Color.maplogMuted)

                    Spacer(minLength: 0)

                    if !comment.isDeleted, !viewModel.isLocal(comment),
                       viewModel.isOwnedByViewer(comment) || viewModel.canModerate(comment) {
                        commentMenu(for: comment)
                    }
                }

                if comment.isDeleted {
                    Text("삭제된 댓글입니다.")
                        .font(.system(size: isReply ? replyTextSize : commentTextSize))
                        .italic()
                        .foregroundStyle(Color.maplogMuted)
                        .padding(.vertical, MaplogSpacing.xxxSmall)
                } else {
                    HStack(alignment: .center, spacing: MaplogSpacing.small) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(comment.content)
                                .font(.system(size: isReply ? replyTextSize : commentTextSize))
                                .foregroundStyle(Color.maplogInk)
                                .fixedSize(horizontal: false, vertical: true)

                            if viewModel.isLocal(comment) {
                                HStack {
                                    Text(viewModel.failedSendIDs.contains(comment.id) ? "전송 실패" : "전송 중…")
                                    if viewModel.failedSendIDs.contains(comment.id) {
                                        Button("다시 시도") {
                                            Task { await viewModel.sendPendingComment(localID: comment.id) }
                                        }
                                        .disabled(viewModel.isSending)
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(Color.maplogMuted)
                                .padding(.top, 4)
                            }
                            if viewModel.replyParentID(for: comment) != nil {
                                Button("답글 달기") {
                                    startReply(to: comment)
                                }
                                .buttonStyle(MaplogPressFeedbackStyle())
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Color.maplogMuted)
                                .frame(minHeight: 28, alignment: .leading)
                                .contentShape(Rectangle())
                                .accessibilityLabel("\(comment.author.nickname)님에게 답글 달기")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if !viewModel.isLocal(comment) {
                            commentLikeButton(for: comment)
                        }
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
        .id(viewModel.rowID(for: comment))
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
            if viewModel.isOwnedByViewer(comment) {
                Button("수정") {
                    startEditing(comment)
                }

                Button("삭제", role: .destructive) {
                    isComposerFocused = false
                    commentPendingDeletion = comment
                }
            } else {
                Button("댓글 신고", systemImage: "flag") {
                    isComposerFocused = false
                    reportReason = ""
                    commentPendingReport = comment
                }
                Button("사용자 차단", systemImage: "person.crop.circle.badge.xmark", role: .destructive) {
                    isComposerFocused = false
                    commentPendingBlock = comment
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.maplogMuted)
                .frame(width: MaplogSize.minimumTapTarget, height: 28)
                .contentShape(Rectangle())
        }
        .disabled(viewModel.isModerating || viewModel.isUpdating(commentID: comment.id))
        .accessibilityLabel(viewModel.isOwnedByViewer(comment) ? "내 댓글 메뉴" : "댓글 신고 및 사용자 차단")
    }

    private func commentLikeButton(
        for comment: LogComment
    ) -> some View {
        Button {
            Task {
                await viewModel.toggleLike(for: comment)
            }
        } label: {
            VStack(spacing: 2) {
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
            .frame(minWidth: MaplogSize.minimumTapTarget, minHeight: MaplogSize.minimumTapTarget)
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
                    MaplogProfileAvatar(
                        imageData: viewModel.viewerImageData,
                        nickname: viewModel.viewerNickname,
                        size: 28
                    )

                    TextField(
                        "",
                        text: $draft,
                        prompt: Text(composerPrompt)
                            .foregroundStyle(Color.maplogMuted)
                    )
                    .font(.subheadline)
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
        guard let parentCommentID = viewModel.replyParentID(for: comment) else { return }
        // 답글의 답글도 같은 묶음에 저장하므로 수신 대상 이름은 본문으로 표시합니다.
        if comment.parentCommentID != nil, draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft = "@\(comment.author.nickname) "
        }
        composerMode = .reply(target: comment, parentCommentID: parentCommentID)
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

        let submittedMode = composerMode
        let submittedText = draft
        switch submittedMode {
        case .new, .reply:
            guard let localID = viewModel.enqueueComment(draft: LogCommentDraft(
                content: submittedText, parentCommentID: submittedMode.parentCommentID
            )) else { return }
            // 입력은 즉시 비우고 키보드는 유지한다. 늦게 온 응답이 새 입력을 지우지 않게 한다.
            draft = ""
            composerMode = .new
            Task { await viewModel.sendPendingComment(localID: localID) }
        case let .edit(comment):
            Task {
                let success = await viewModel.updateComment(commentID: comment.id, content: submittedText)
                if success, draft == submittedText, composerMode == submittedMode {
                    draft = ""
                    composerMode = .new
                }
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
