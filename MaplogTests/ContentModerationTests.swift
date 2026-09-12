import XCTest
@testable import Maplog

final class ContentModerationTests: XCTestCase {
    func testLogReportUsesLogTargetAndTrimmedReason() async throws {
        let api = ModerationAPIStub()
        let repository = DefaultContentModerationRepository(apiService: api)
        try await repository.reportLog(id: 12, reason: "  유해 콘텐츠  ")
        let request = try XCTUnwrap(api.request)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        XCTAssertEqual(json["targetType"] as? String, "LOG")
        XCTAssertEqual(request.targetId, 12)
        XCTAssertEqual(request.reason, "유해 콘텐츠")
    }

    func testInvalidReasonDoesNotReachServer() async {
        let api = ModerationAPIStub()
        let repository = DefaultContentModerationRepository(apiService: api)
        for reason in ["  ", String(repeating: "가", count: 1001)] {
            do { try await repository.reportLog(id: 12, reason: reason); XCTFail("Must reject input") }
            catch { XCTAssertNil(api.request) }
        }
    }

    func testBlockRejectsMismatchedResponse() async {
        let repository = DefaultContentModerationRepository(apiService: ModerationAPIStub())
        do { try await repository.blockUser(id: UUID()); XCTFail("Must reject mismatched user") }
        catch { guard case APIError.invalidResponse = error else { return XCTFail("Unexpected error") } }
    }

    @MainActor
    func testOwnProfileCannotBeReportedOrBlocked() async {
        let id = UUID()
        let repository = ModerationRepositoryStub()
        let model = ContentModerationViewModel(repository: repository,
                                              profileRepository: ModerationProfileStub(id: id), authorID: id)
        await model.prepare()
        await model.report(logID: 1, reason: "test")
        await model.block()
        XCTAssertFalse(model.canModerate)
        XCTAssertEqual(repository.calls, 0)
    }

    @MainActor
    func testSuccessfulBlockNotifiesExistingCacheAndNavigationReset() async {
        let notification = expectation(forNotification: .maplogUserBlockDidChange, object: nil)
        let repository = ModerationRepositoryStub()
        let model = ContentModerationViewModel(repository: repository,
                                              profileRepository: ModerationProfileStub(id: UUID()), authorID: UUID())
        await model.prepare()
        await model.block()
        await fulfillment(of: [notification], timeout: 1)
        XCTAssertEqual(repository.calls, 1)
        XCTAssertFalse(model.isBusy)
        XCTAssertNil(model.error)
    }
}

private final class ModerationAPIStub: ContentModerationAPIService {
    func fetchBlockedUsers(page: Int, size: Int) async throws -> BlockedUserPageDTO { throw APIError.invalidResponse }
    func unblockAuthor(userID: UUID) async throws -> CommentAuthorBlockStateDTO { throw APIError.invalidResponse }
    var request: ContentReportRequestDTO?
    func reportContent(request: ContentReportRequestDTO) async throws -> CommentReportReceiptDTO {
        self.request = request
        return .init(reportId: 1, status: "PENDING", createdAt: "2026-09-12")
    }
    func blockAuthor(userID: UUID) async throws -> CommentAuthorBlockStateDTO {
        .init(userId: UUID(), blocked: true)
    }
}

private final class ModerationRepositoryStub: ContentModerationRepository {
    func fetchBlockedUsers(page: Int) async throws -> BlockedUserPage { throw APIError.invalidResponse }
    func unblockUser(id: UUID) async throws { throw APIError.invalidResponse }
    var calls = 0
    func reportLog(id: Int64, reason: String) async throws { calls += 1 }
    func blockUser(id: UUID) async throws { calls += 1 }
}

private struct ModerationProfileStub: ProfileRepository {
    let id: UUID
    func fetchMyProfile() async throws -> MyProfile {
        .init(id: id, nickname: "tester", profileImageURL: nil, bio: "", followerCount: 0, followingCount: 0, logCount: 0)
    }
    func fetchPublicProfile(nickname: String) async throws -> PublicProfile { throw APIError.invalidResponse }
    func fetchMyLogs(cursor: String?, size: Int) async throws -> ProfileLogPage { throw APIError.invalidResponse }
    func fetchPublicProfileLogs(nickname: String, cursor: String?, size: Int) async throws -> ProfileLogPage { throw APIError.invalidResponse }
    func updateMyProfile(_ update: ProfileUpdate) async throws -> MyProfile { throw APIError.invalidResponse }
    func deleteMyProfile() async throws { throw APIError.invalidResponse }
    func fetchImageData(from url: URL, cacheKey: String, targetSize: MaplogImageTargetSize) async throws -> Data { Data() }
}

@MainActor
final class BlockedUsersTests: XCTestCase {
    func testNextPageFailurePreservesVisibleUsers() async {
        let repository = BlockManagementStub()
        let model = BlockedUsersViewModel(repository: repository)
        await model.reload()
        repository.failPage = 2
        await model.loadNextPage()
        XCTAssertEqual(model.users, [repository.user])
        XCTAssertNotNil(model.nextPageError)
        XCTAssertEqual(repository.requestedPages, [1, 2])
    }

    func testUnblockFailurePreservesUser() async {
        let repository = BlockManagementStub()
        let model = BlockedUsersViewModel(repository: repository)
        await model.reload()
        repository.failUnblock = true
        await model.unblock(repository.user)
        XCTAssertEqual(model.users, [repository.user])
        XCTAssertNotNil(model.error)
        XCTAssertNil(model.unblockingID)
    }

    func testUnblockRestartsNumberedPagination() async {
        let repository = BlockManagementStub()
        let model = BlockedUsersViewModel(repository: repository)
        await model.reload()
        await model.loadNextPage()
        await model.unblock(repository.user)
        XCTAssertEqual(repository.requestedPages, [1, 2, 1])
        XCTAssertTrue(model.users.isEmpty)
        XCTAssertFalse(model.hasNext)
    }

    func testBlockedProfileOnSecondPageDoesNotLoadLogs() async {
        let repository = BlockManagementStub()
        repository.targetOnSecondPage = true
        let user = FollowUser(id: repository.user.id, nickname: "blocked", profileImageURL: nil)
        let model = PublicProfileViewModel(user: user, followRepository: BlockedProfileFollowStub(),
                                          profileRepository: ModerationProfileStub(id: UUID()))
        // The profile stub throws if profile/logs are requested: a blocked state proves these were skipped.
        await model.loadIfNeeded(moderationRepository: repository)
        XCTAssertEqual(model.state, .blocked)
        XCTAssertTrue(model.logs.isEmpty)
        XCTAssertNil(model.profile)
        XCTAssertEqual(repository.requestedPages, [1, 2])
    }
}

private final class BlockManagementStub: ContentModerationRepository {
    let user = BlockedUser(id: UUID(), nickname: "blocked")
    var requestedPages: [Int] = []
    var failPage: Int?
    var failUnblock = false
    var unblocked = false
    var targetOnSecondPage = false
    func fetchBlockedUsers(page: Int) async throws -> BlockedUserPage {
        requestedPages.append(page)
        if failPage == page { throw APIError.network(URLError(.notConnectedToInternet)) }
        if unblocked { return .init(users: [], page: page, hasNext: false) }
        let pageUser = targetOnSecondPage && page == 1 ? BlockedUser(id: UUID(), nickname: "another") : user
        return .init(users: [pageUser], page: page, hasNext: page == 1)
    }
    func unblockUser(id: UUID) async throws {
        if failUnblock { throw APIError.network(URLError(.notConnectedToInternet)) }
        unblocked = true
    }
    func reportLog(id: Int64, reason: String) async throws { throw APIError.invalidResponse }
    func blockUser(id: UUID) async throws { throw APIError.invalidResponse }
}

private struct BlockedProfileFollowStub: FollowRepository {
    func fetchUsers(kind: FollowListKind, cursor: String?, size: Int) async throws -> FollowUserPage { throw APIError.invalidResponse }
    func isFollowing(userID: UUID) async throws -> Bool { throw APIError.invalidResponse }
    func setFollowing(userID: UUID, isFollowing: Bool) async throws -> FollowState { throw APIError.invalidResponse }
}
