import Foundation
import XCTest
@testable import Maplog

@MainActor
final class LogCommentsViewModelTests: XCTestCase {
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

    private func makeComment(
        id: Int64,
        parentCommentID: Int64? = nil,
        isDeleted: Bool = false
    ) -> LogComment {
        LogComment(
            id: id,
            author: LogCommentAuthor(
                id: UUID(),
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
        fatalError("This test does not create comments.")
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
    func fetchMyProfile() async throws -> MyProfile {
        MyProfile(
            id: UUID(),
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
