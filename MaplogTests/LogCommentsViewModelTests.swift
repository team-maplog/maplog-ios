import Foundation
import XCTest
@testable import Maplog

@MainActor
final class LogCommentsViewModelTests: XCTestCase {
    func testReplyToReplyUsesTopLevelParentAndRejectsDeletedThread() async {
        let parent = makeComment(id: 1)
        let reply = makeComment(id: 2, parentCommentID: 1)
        let deletedParent = makeComment(id: 3, isDeleted: true)
        let replyToDeletedParent = makeComment(id: 4, parentCommentID: 3)
        let orphan = makeComment(id: 5, parentCommentID: 99)
        let model = makeViewModel(comments: [parent, reply, deletedParent, replyToDeletedParent, orphan])
        await model.loadInitialComments()
        XCTAssertEqual(model.replyParentID(for: parent), 1)
        XCTAssertEqual(model.replyParentID(for: reply), 1)
        XCTAssertNil(model.replyParentID(for: deletedParent))
        XCTAssertNil(model.replyParentID(for: replyToDeletedParent))
        XCTAssertNil(model.replyParentID(for: orphan))
    }

    func testOwnOrDeletedCommentCannotBeReportedAndSelfCannotBeBlocked() async {
        let profile = CommentProfileRepositoryStub()
        let own = makeComment(id: 1, authorID: profile.userID)
        let deleted = makeComment(id: 2, isDeleted: true)
        let repository = LogCommentRepositoryStub(comments: [own, deleted])
        let model = LogCommentsViewModel(logID: 10, commentRepository: repository,
            profileRepository: profile, onCommentCountChange: { _ in })
        XCTAssertFalse(model.canModerate(own))
        await model.loadInitialComments()
        XCTAssertTrue(model.isOwnedByViewer(own))
        XCTAssertFalse(model.canModerate(own))
        XCTAssertFalse(model.canModerate(deleted))
        await model.reportComment(commentID: own.id, reason: "test")
        await model.blockAuthor(userID: profile.userID)
        XCTAssertTrue(repository.reportedIDs.isEmpty)
        XCTAssertTrue(repository.blockedIDs.isEmpty)
    }

    func testBlockHidesAuthorAndThreadOnlyAfterServerSuccess() async {
        let parent = makeComment(id: 1)
        let reply = makeComment(id: 2, parentCommentID: 1)
        let unrelated = makeComment(id: 3)
        let repository = LogCommentRepositoryStub(comments: [parent, reply, unrelated])
        var deltas: [Int64] = []
        let model = LogCommentsViewModel(logID: 10, commentRepository: repository,
            profileRepository: CommentProfileRepositoryStub(), onCommentCountChange: { deltas.append($0) })
        await model.loadInitialComments()
        repository.moderationError = APIError.network(URLError(.notConnectedToInternet))
        await model.blockAuthor(userID: parent.author.id)
        XCTAssertEqual(model.comments.map(\.id), [1, 2, 3])
        XCTAssertNotNil(model.actionError)
        repository.moderationError = nil
        await model.retryLastAction()
        XCTAssertEqual(model.comments.map(\.id), [3])
        XCTAssertEqual(repository.blockedIDs, [parent.author.id])
        XCTAssertTrue(deltas.isEmpty, "차단은 댓글 삭제가 아닙니다")
    }

    func testReportSuccessKeepsCommentAndFailureDoesNotClaimSuccess() async {
        let comment = makeComment(id: 1)
        let repository = LogCommentRepositoryStub(comments: [comment])
        let model = LogCommentsViewModel(logID: 10, commentRepository: repository,
            profileRepository: CommentProfileRepositoryStub(), onCommentCountChange: { _ in })
        await model.loadInitialComments()
        repository.moderationError = APIError.network(URLError(.notConnectedToInternet))
        await model.reportComment(commentID: 1, reason: "괴롭힘")
        XCTAssertNil(model.moderationMessage)
        XCTAssertNotNil(model.actionError)
        repository.moderationError = nil
        model.dismissActionError()
        await model.retryLastAction()
        XCTAssertEqual(repository.reportedIDs, [1])
        XCTAssertNotNil(model.moderationMessage)
        XCTAssertEqual(model.comments.map(\.id), [1])
    }

    func testLoadHidesDeletedStandaloneCommentsAndDeletedReplies() async {
        let activeParent = makeComment(id: 1)
        let activeReply = makeComment(id: 2, parentCommentID: activeParent.id)
        let deletedStandalone = makeComment(id: 3, isDeleted: true)
        let deletedParent = makeComment(id: 4, isDeleted: true)
        let replyOfDeletedParent = makeComment(
            id: 5,
            parentCommentID: deletedParent.id
        )
        let deletedReply = makeComment(
            id: 6,
            parentCommentID: activeParent.id,
            isDeleted: true
        )
        let viewModel = makeViewModel(
            comments: [
                activeParent,
                activeReply,
                deletedStandalone,
                deletedParent,
                replyOfDeletedParent,
                deletedReply
            ]
        )

        await viewModel.loadInitialComments()

        XCTAssertEqual(viewModel.comments.map(\.id), [1, 2, 4, 5])
        XCTAssertEqual(viewModel.activeCommentCount, 3)
    }

    func testDeletingParentWithActiveReplyKeepsDeletedParentAsContext() async {
        let parent = makeComment(id: 1)
        let reply = makeComment(id: 2, parentCommentID: parent.id)
        var commentCountChanges: [Int64] = []
        let viewModel = makeViewModel(
            comments: [parent, reply],
            onCommentCountChange: { commentCountChanges.append($0) }
        )

        await viewModel.loadInitialComments()
        await viewModel.deleteComment(commentID: parent.id)

        XCTAssertEqual(viewModel.comments.map(\.id), [1, 2])
        XCTAssertTrue(viewModel.comments[0].isDeleted)
        XCTAssertEqual(viewModel.activeCommentCount, 1)
        XCTAssertEqual(commentCountChanges, [-1])
    }

    func testDeletingReplyOrStandaloneCommentRemovesItImmediately() async {
        let parent = makeComment(id: 1)
        let reply = makeComment(id: 2, parentCommentID: parent.id)
        let standalone = makeComment(id: 3)
        let viewModel = makeViewModel(
            comments: [parent, reply, standalone]
        )

        await viewModel.loadInitialComments()
        await viewModel.deleteComment(commentID: reply.id)
        XCTAssertEqual(viewModel.comments.map(\.id), [1, 3])

        await viewModel.deleteComment(commentID: standalone.id)
        XCTAssertEqual(viewModel.comments.map(\.id), [1])
    }

    func testNotificationTargetsReplyAndReportsMissingOrDeletedComment() async {
        let model = makeViewModel(comments: [
            makeComment(id: 1), makeComment(id: 2, parentCommentID: 1),
            makeComment(id: 3, isDeleted: true)
        ])
        XCTAssertFalse(model.isRequestedCommentUnavailable(2))
        await model.loadInitialComments()
        XCTAssertEqual(model.notificationScrollTarget(2), 2)
        XCTAssertFalse(model.isRequestedCommentUnavailable(2))
        XCTAssertTrue(model.isRequestedCommentUnavailable(3))
        XCTAssertTrue(model.isRequestedCommentUnavailable(99))
        XCTAssertFalse(model.isRequestedCommentUnavailable(nil))
    }

    func testComposerLoadsViewerAvatarThroughProfileRepository() async {
        let viewModel = makeViewModel(comments: [])
        await viewModel.loadInitialComments()
        XCTAssertEqual(viewModel.viewerNickname, "나")
        XCTAssertEqual(viewModel.viewerImageData, Data([1, 2, 3]))
    }

    private func makeViewModel(
        comments: [LogComment],
        onCommentCountChange: @escaping (Int64) -> Void = { _ in }
    ) -> LogCommentsViewModel {
        LogCommentsViewModel(
            logID: 10,
            commentRepository: LogCommentRepositoryStub(comments: comments),
            profileRepository: CommentProfileRepositoryStub(),
            onCommentCountChange: onCommentCountChange
        )
    }

    func testPendingCommentAppearsBeforeResponseAndKeepsRowIdentity() async {
        let repository = LogCommentRepositoryStub(comments: [])
        let serverComment = makeComment(id: 50)
        var deltas: [Int64] = []
        let model = LogCommentsViewModel(logID: 10, commentRepository: repository,
            profileRepository: CommentProfileRepositoryStub(), onCommentCountChange: { deltas.append($0) })
        await model.loadInitialComments()
        let localID = model.enqueueComment(draft: LogCommentDraft(content: "  새 댓글  ", parentCommentID: nil))!
        XCTAssertEqual(model.comments.first?.content, "새 댓글")
        XCTAssertTrue(model.isSending)
        XCTAssertEqual(model.activeCommentCount, 0)
        XCTAssertNil(model.replyParentID(for: model.comments[0]))
        XCTAssertNil(model.enqueueComment(draft: LogCommentDraft(content: "중복", parentCommentID: nil)))
        repository.createdComment = serverComment
        let succeeded = await model.sendPendingComment(localID: localID)
        XCTAssertTrue(succeeded)
        XCTAssertEqual(model.comments.map(\.id), [50])
        XCTAssertEqual(model.rowID(for: model.comments[0]), localID)
        XCTAssertEqual(deltas, [1])
        XCTAssertEqual(model.activeCommentCount, 1)
        let duplicate = await model.sendPendingComment(localID: localID)
        XCTAssertFalse(duplicate)
        XCTAssertEqual(repository.createCallCount, 1)
    }

    func testSlowRequestShowsPendingRowAndRejectsDuplicateSendUntilResponse() async {
        let repository = LogCommentRepositoryStub(comments: [])
        let response = makeComment(id: 80)
        let started = expectation(description: "request started")
        var continuation: CheckedContinuation<LogComment, Error>?
        repository.createOperation = { _ in
            try await withCheckedThrowingContinuation { pending in
                continuation = pending
                started.fulfill()
            }
        }
        let model = LogCommentsViewModel(logID: 10, commentRepository: repository,
            profileRepository: CommentProfileRepositoryStub(), onCommentCountChange: { _ in })
        await model.loadInitialComments()
        let localID = model.enqueueComment(draft: LogCommentDraft(content: "느린 요청", parentCommentID: nil))!
        let request = Task { await model.sendPendingComment(localID: localID) }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertEqual(model.comments.first?.content, "느린 요청")
        XCTAssertTrue(model.isSending)
        let duplicate = await model.sendPendingComment(localID: localID)
        XCTAssertFalse(duplicate)
        XCTAssertEqual(repository.createCallCount, 1)
        continuation?.resume(returning: response)
        let result = await request.value
        XCTAssertTrue(result)
        XCTAssertEqual(model.comments.map(\.id), [80])
    }

    func testFailedReplyIsPreservedAndRetryReplacesTheSameRow() async {
        let repository = LogCommentRepositoryStub(comments: [makeComment(id: 1)])
        var deltas: [Int64] = []
        let model = LogCommentsViewModel(logID: 10, commentRepository: repository,
            profileRepository: CommentProfileRepositoryStub(), onCommentCountChange: { deltas.append($0) })
        await model.loadInitialComments()
        repository.createError = APIError.network(URLError(.notConnectedToInternet))
        let success = await model.createComment(draft: LogCommentDraft(content: "답글", parentCommentID: 1))
        XCTAssertFalse(success)
        let localID = model.comments.last!.id
        XCTAssertTrue(model.failedSendIDs.contains(localID))
        XCTAssertEqual(model.comments.last?.content, "답글")
        XCTAssertEqual(model.comments.last?.parentCommentID, 1)
        XCTAssertEqual(model.activeCommentCount, 1)
        XCTAssertTrue(deltas.isEmpty)
        repository.createError = nil
        repository.createdComment = makeComment(id: 2, parentCommentID: 1)
        model.dismissActionError()
        await model.retryLastAction()
        XCTAssertEqual(model.comments.map(\.id), [1, 2])
        XCTAssertEqual(model.rowID(for: model.comments.last!), localID)
        XCTAssertEqual(deltas, [1])
        XCTAssertTrue(model.pendingDrafts.isEmpty)
        XCTAssertFalse(model.isSending)
    }

    private func makeComment(
        id: Int64,
        parentCommentID: Int64? = nil,
        isDeleted: Bool = false,
        authorID: UUID = UUID()
    ) -> LogComment {
        LogComment(
            id: id,
            author: LogCommentAuthor(
                id: authorID,
                nickname: "여행자\(id)",
                profileImageURL: nil
            ),
            parentCommentID: parentCommentID,
            content: "여행 댓글 \(id)",
            isDeleted: isDeleted,
            createdAt: .now,
            updatedAt: .now,
            likeCount: 0,
            isLikedByViewer: false
        )
    }
}

private final class LogCommentRepositoryStub: LogCommentRepository {
    var moderationError: Error?
    var createError: Error?
    var createdComment: LogComment?
    var createCallCount = 0
    var createOperation: ((LogCommentDraft) async throws -> LogComment)?
    var reportedIDs: [Int64] = []
    var blockedIDs: [UUID] = []
    func reportComment(commentID: Int64, reason: String) async throws {
        if let moderationError { throw moderationError }
        reportedIDs.append(commentID)
    }
    func blockAuthor(userID: UUID) async throws {
        if let moderationError { throw moderationError }
        blockedIDs.append(userID)
    }
    private let comments: [LogComment]

    init(comments: [LogComment]) {
        self.comments = comments
    }

    func fetchComments(logID: Int64) async throws -> [LogComment] {
        comments
    }

    func createComment(
        logID: Int64,
        draft: LogCommentDraft
    ) async throws -> LogComment {
        createCallCount += 1
        if let createOperation { return try await createOperation(draft) }
        if let createError { throw createError }
        return createdComment!
    }

    func updateComment(
        commentID: Int64,
        content: String
    ) async throws -> LogComment {
        fatalError("This test does not update comments.")
    }

    func deleteComment(commentID: Int64) async throws {}

    func setLike(
        commentID: Int64,
        isLiked: Bool
    ) async throws -> LogCommentLikeState {
        fatalError("This test does not set comment likes.")
    }
}

private final class CommentProfileRepositoryStub: ProfileRepository {
    let userID = UUID()
    func fetchMyProfile() async throws -> MyProfile {
        MyProfile(
            id: userID,
            nickname: "나",
            profileImageURL: URL(string: "https://example.com/avatar.png"),
            bio: "",
            followerCount: 0,
            followingCount: 0,
            logCount: 0
        )
    }

    func fetchPublicProfile(nickname: String) async throws -> PublicProfile {
        fatalError("This test does not fetch public profiles.")
    }

    func fetchMyLogs(
        cursor: String?,
        size: Int
    ) async throws -> ProfileLogPage {
        ProfileLogPage(logs: [], hasNext: false, nextCursor: nil)
    }

    func fetchPublicProfileLogs(
        nickname: String,
        cursor: String?,
        size: Int
    ) async throws -> ProfileLogPage {
        ProfileLogPage(logs: [], hasNext: false, nextCursor: nil)
    }

    func updateMyProfile(_ update: ProfileUpdate) async throws -> MyProfile {
        try await fetchMyProfile()
    }

    func deleteMyProfile() async throws {}

    func fetchImageData(
        from url: URL,
        cacheKey: String,
        targetSize: MaplogImageTargetSize
    ) async throws -> Data {
        Data([1, 2, 3])
    }
}
