import Foundation

enum LogCommentsState {
    case idle
    case loading
    case content([LogComment])
    case empty
    case failed(ErrorPresentation)
}

@MainActor
final class LogCommentsViewModel: ObservableObject {
    @Published private(set) var state: LogCommentsState = .idle
    @Published private(set) var actionError: ErrorPresentation?
    @Published private(set) var isSending = false
    @Published private(set) var isModerating = false
    @Published var moderationMessage: String?
    @Published private(set) var updatingCommentIDs = Set<Int64>()
    @Published private var profileImageDataByAuthorID: [UUID: Data] = [:]
    @Published private var profileImageLoadingAuthorIDs = Set<UUID>()

    private let logID: Int64
    private let commentRepository: any LogCommentRepository
    private let profileRepository: any ProfileRepository
    private let onCommentCountChange: (Int64) -> Void

    @Published private(set) var viewerNickname = "나"
    @Published private(set) var viewerImageData: Data?
    private var viewerID: UUID?
    private var lastAction: RetryAction?

    private enum RetryAction {
        case load
        case create(LogCommentDraft)
        case update(commentID: Int64, content: String)
        case delete(commentID: Int64)
        case like(commentID: Int64, isLiked: Bool)
        case report(commentID: Int64, reason: String)
        case block(userID: UUID)
    }

    init(
        logID: Int64,
        commentRepository: any LogCommentRepository,
        profileRepository: any ProfileRepository,
        onCommentCountChange: @escaping (Int64) -> Void
    ) {
        self.logID = logID
        self.commentRepository = commentRepository
        self.profileRepository = profileRepository
        self.onCommentCountChange = onCommentCountChange
    }

    var comments: [LogComment] {
        guard case let .content(comments) = state else {
            return []
        }

        return comments
    }

    func notificationScrollTarget(_ commentID: Int64?) -> Int64? {
        guard let commentID, let comment = comments.first(where: { $0.id == commentID }),
              !comment.isDeleted else { return nil }
        return comment.id
    }

    func isRequestedCommentUnavailable(_ commentID: Int64?) -> Bool {
        guard commentID != nil else { return false }
        switch state {
        case .content, .empty:
            return notificationScrollTarget(commentID) == nil
        default:
            return false
        }
    }

    /// 삭제된 부모 댓글은 답글의 문맥을 위해 남겨둘 수 있지만 댓글 수에는 포함하지 않습니다.
    var activeCommentCount: Int {
        comments.filter { !$0.isDeleted }.count
    }

    func loadInitialComments() async {
        guard case .idle = state else {
            return
        }

        await loadComments()
    }

    func retryLastAction() async {
        guard let lastAction else {
            return
        }

        switch lastAction {
        case let .report(commentID, reason):
            await reportComment(commentID: commentID, reason: reason)
        case let .block(userID):
            await blockAuthor(userID: userID)
        case .load:
            await reloadComments()

        case let .create(draft):
            await createComment(draft: draft)

        case let .update(commentID, content):
            await updateComment(
                commentID: commentID,
                content: content
            )

        case let .delete(commentID):
            await deleteComment(commentID: commentID)

        case let .like(commentID, isLiked):
            await setLike(
                commentID: commentID,
                isLiked: isLiked
            )
        }
    }

    func dismissActionError() {
        actionError = nil
        // 알림창이 먼저 닫혀도 그 버튼에서 시작한 비동기 재시도가 작업을 읽을 수 있게 둡니다.
    }

    func isOwnedByViewer(
        _ comment: LogComment
    ) -> Bool {
        comment.author.id == viewerID
    }

    func canModerate(_ comment: LogComment) -> Bool {
        viewerID != nil && !isOwnedByViewer(comment) && !comment.isDeleted
    }

    func reportComment(commentID: Int64, reason: String) async {
        guard !isModerating,
              let comment = comments.first(where: { $0.id == commentID }),
              canModerate(comment) else { return }
        isModerating = true
        actionError = nil
        defer { isModerating = false }
        do {
            try await commentRepository.reportComment(commentID: commentID, reason: reason)
            lastAction = nil
            moderationMessage = "신고가 접수됐어요. 검토 후 필요한 조치를 진행합니다."
        } catch is CancellationError {
            return
        } catch {
            lastAction = .report(commentID: commentID, reason: reason)
            actionError = LogCommentErrorPolicy.actionPresentation(for: error, actionName: "댓글 신고")
        }
    }

    func blockAuthor(userID: UUID) async {
        guard !isModerating, let viewerID, userID != viewerID else { return }
        isModerating = true
        actionError = nil
        defer { isModerating = false }
        do {
            try await commentRepository.blockAuthor(userID: userID)
            // 차단은 삭제가 아니므로 댓글 삭제 집계를 호출하지 않습니다.
            let blockedParentIDs = Set(comments.filter { $0.author.id == userID }.map(\.id))
            let remaining = comments.filter {
                $0.author.id != userID && !blockedParentIDs.contains($0.parentCommentID ?? 0)
            }
            updateContentState(with: remaining)
            profileImageDataByAuthorID[userID] = nil
            lastAction = nil
            // 다른 탭의 기존 콘텐츠도 새 차단 정책으로 다시 조회하게 합니다.
            NotificationCenter.default.post(name: .maplogUserBlockDidChange, object: nil)
        } catch is CancellationError {
            return
        } catch {
            lastAction = .block(userID: userID)
            actionError = LogCommentErrorPolicy.actionPresentation(for: error, actionName: "사용자 차단")
        }
    }

    func isUpdating(
        commentID: Int64
    ) -> Bool {
        updatingCommentIDs.contains(commentID)
    }

    func profileImageData(
        for author: LogCommentAuthor
    ) -> Data? {
        profileImageDataByAuthorID[author.id]
    }

    func loadProfileImage(
        for author: LogCommentAuthor
    ) async {
        guard let profileImageURL = author.profileImageURL,
              profileImageDataByAuthorID[author.id] == nil,
              !profileImageLoadingAuthorIDs.contains(author.id)
        else {
            return
        }

        profileImageLoadingAuthorIDs.insert(author.id)

        defer {
            profileImageLoadingAuthorIDs.remove(author.id)
        }

        do {
            let data = try await profileRepository.fetchImageData(
                from: profileImageURL
            )

            guard !Task.isCancelled else {
                return
            }

            profileImageDataByAuthorID[author.id] = data
        } catch {
            // 이미지 하나의 실패는 댓글 조회 실패가 아니므로 fallback을 유지한다.
            return
        }
    }

    @discardableResult
    func createComment(
        draft: LogCommentDraft
    ) async -> Bool {
        let trimmedContent = trimmed(draft.content)
        guard !trimmedContent.isEmpty,
              !isSending
        else {
            return false
        }

        let normalizedDraft = LogCommentDraft(
            content: trimmedContent,
            parentCommentID: draft.parentCommentID
        )

        isSending = true
        actionError = nil

        defer {
            isSending = false
        }

        do {
            let createdComment = try await commentRepository.createComment(
                logID: logID,
                draft: normalizedDraft
            )

            guard !Task.isCancelled else {
                return false
            }

            append(createdComment)
            onCommentCountChange(1)
            lastAction = nil
            return true

        } catch is CancellationError {
            return false

        } catch {
            guard !Task.isCancelled else {
                return false
            }

            lastAction = .create(normalizedDraft)
            actionError = LogCommentErrorPolicy.actionPresentation(
                for: error,
                actionName: "댓글 등록"
            )
            return false
        }
    }

    @discardableResult
    func updateComment(
        commentID: Int64,
        content: String
    ) async -> Bool {
        let trimmedContent = trimmed(content)
        guard !trimmedContent.isEmpty,
              !updatingCommentIDs.contains(commentID)
        else {
            return false
        }

        updatingCommentIDs.insert(commentID)
        actionError = nil

        defer {
            updatingCommentIDs.remove(commentID)
        }

        do {
            let updatedComment = try await commentRepository.updateComment(
                commentID: commentID,
                content: trimmedContent
            )

            guard !Task.isCancelled else {
                return false
            }

            replace(updatedComment)
            lastAction = nil
            return true

        } catch is CancellationError {
            return false

        } catch {
            guard !Task.isCancelled else {
                return false
            }

            lastAction = .update(
                commentID: commentID,
                content: trimmedContent
            )
            actionError = LogCommentErrorPolicy.actionPresentation(
                for: error,
                actionName: "댓글 수정"
            )
            return false
        }
    }

    func deleteComment(
        commentID: Int64
    ) async {
        guard !updatingCommentIDs.contains(commentID) else {
            return
        }

        updatingCommentIDs.insert(commentID)
        actionError = nil

        defer {
            updatingCommentIDs.remove(commentID)
        }

        do {
            try await commentRepository.deleteComment(commentID: commentID)

            guard !Task.isCancelled else {
                return
            }

            applyDeletedComment(commentID: commentID)
            onCommentCountChange(-1)
            lastAction = nil

        } catch is CancellationError {
            return

        } catch {
            guard !Task.isCancelled else {
                return
            }

            lastAction = .delete(commentID: commentID)
            actionError = LogCommentErrorPolicy.actionPresentation(
                for: error,
                actionName: "댓글 삭제"
            )
        }
    }

    func toggleLike(
        for comment: LogComment
    ) async {
        await setLike(
            commentID: comment.id,
            isLiked: !comment.isLikedByViewer
        )
    }

    private func loadComments() async {
        state = .loading
        actionError = nil

        do {
            let comments = try await commentRepository.fetchComments(logID: logID)

            guard !Task.isCancelled else {
                return
            }

            updateContentState(with: visibleComments(from: comments))
            lastAction = nil

            // 댓글 조회 실패와 내 프로필 조회 실패를 분리합니다.
            // 프로필을 못 받아도 댓글을 읽거나 작성하는 기능은 계속 사용할 수 있습니다.
            if let profile = try? await profileRepository.fetchMyProfile() {
                guard !Task.isCancelled else { return }
                viewerID = profile.id
                viewerNickname = profile.nickname
                if let url = profile.profileImageURL {
                    let data = try? await profileRepository.fetchImageData(from: url)
                    guard !Task.isCancelled else { return }
                    viewerImageData = data
                } else {
                    viewerImageData = nil
                }
            }

        } catch is CancellationError {
            state = .idle

        } catch {
            guard !Task.isCancelled else {
                return
            }

            lastAction = .load
            state = .failed(
                LogCommentErrorPolicy.loadPresentation(for: error)
            )
        }
    }

    private func reloadComments() async {
        state = .idle
        await loadComments()
    }

    private func setLike(
        commentID: Int64,
        isLiked: Bool
    ) async {
        guard !updatingCommentIDs.contains(commentID) else {
            return
        }

        updatingCommentIDs.insert(commentID)
        actionError = nil

        defer {
            updatingCommentIDs.remove(commentID)
        }

        do {
            let result = try await commentRepository.setLike(
                commentID: commentID,
                isLiked: isLiked
            )

            guard !Task.isCancelled else {
                return
            }

            replace(commentID: commentID) { comment in
                let countChange: Int64
                if comment.isLikedByViewer == result.isLiked {
                    countChange = 0
                } else {
                    countChange = result.isLiked ? 1 : -1
                }

                return comment.replacingLike(
                    isLikedByViewer: result.isLiked,
                    likeCount: max(0, comment.likeCount + countChange)
                )
            }
            lastAction = nil

        } catch is CancellationError {
            return

        } catch {
            guard !Task.isCancelled else {
                return
            }

            lastAction = .like(
                commentID: commentID,
                isLiked: isLiked
            )
            actionError = LogCommentErrorPolicy.actionPresentation(
                for: error,
                actionName: isLiked ? "댓글 좋아요" : "댓글 좋아요 취소"
            )
        }
    }

    private func append(
        _ comment: LogComment
    ) {
        guard case let .content(comments) = state else {
            state = .content([comment])
            return
        }

        if comment.parentCommentID == nil {
            state = .content([comment] + comments)
        } else {
            state = .content(comments + [comment])
        }
    }

    private func replace(
        _ updatedComment: LogComment
    ) {
        replace(commentID: updatedComment.id) { _ in
            updatedComment
        }
    }

    private func applyDeletedComment(
        commentID: Int64
    ) {
        guard case let .content(comments) = state else {
            return
        }

        let updatedComments = comments.map { comment in
            comment.id == commentID ? comment.markingDeleted() : comment
        }
        updateContentState(with: visibleComments(from: updatedComments))
    }

    /// 삭제된 답글은 바로 제거하고, 삭제된 부모 댓글은 활성 답글이 있을 때만 남깁니다.
    /// 답글의 작성 맥락을 보존하면서 삭제된 독립 댓글은 목록을 깔끔하게 정리합니다.
    private func visibleComments(
        from comments: [LogComment]
    ) -> [LogComment] {
        let parentIDsWithActiveReplies = Set<Int64>(
            comments.compactMap { comment in
                guard !comment.isDeleted,
                      let parentCommentID = comment.parentCommentID
                else {
                    return nil
                }

                return parentCommentID
            }
        )

        return comments.filter { comment in
            guard comment.isDeleted else {
                return true
            }

            return comment.parentCommentID == nil
                && parentIDsWithActiveReplies.contains(comment.id)
        }
    }

    private func updateContentState(
        with comments: [LogComment]
    ) {
        state = comments.isEmpty ? .empty : .content(comments)
    }

    private func replace(
        commentID: Int64,
        transform: (LogComment) -> LogComment
    ) {
        guard case let .content(comments) = state else {
            return
        }

        state = .content(
            comments.map { comment in
                comment.id == commentID ? transform(comment) : comment
            }
        )
    }

    private func trimmed(
        _ content: String
    ) -> String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
