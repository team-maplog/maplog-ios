import XCTest
@testable import Maplog

@MainActor
final class RestrictedProfileTests: XCTestCase {
    func testRestrictedProfileShowsIdentityWithoutRequestingContentOrBlockList() async {
        let repository = RestrictedProfileStub()
        let moderation = RestrictedModerationStub()
        let model = makeModel(repository, moderation)
        await model.loadIfNeeded(moderationRepository: moderation)
        await model.loadNextPage()
        let follow = await model.toggleFollow()
        XCTAssertEqual(model.state, .blocked)
        XCTAssertEqual(model.profile?.nickname, "slow.seoul")
        XCTAssertEqual(model.profile?.id, repository.id)
        XCTAssertTrue(model.logs.isEmpty)
        XCTAssertFalse(model.hasNextPage)
        XCTAssertNil(follow)
        XCTAssertEqual(repository.logRequests, 0)
        XCTAssertEqual(repository.viewerRequests, 0)
        XCTAssertEqual(moderation.listRequests, 0)
    }

    func testUnblockInvalidatesCacheAndReloadsProfileBeforeLogs() async {
        let repository = RestrictedProfileStub()
        let moderation = RestrictedModerationStub()
        moderation.onUnblock = { repository.blocked = false }
        let model = makeModel(repository, moderation)
        await model.loadIfNeeded(moderationRepository: moderation)
        let invalidated = expectation(forNotification: .maplogUserBlockCacheDidChange, object: nil)
        await model.unblock()
        await fulfillment(of: [invalidated], timeout: 1)
        XCTAssertEqual(moderation.unblockedIDs, [repository.id])
        XCTAssertEqual(repository.events, ["profile", "profile", "logs"])
        XCTAssertEqual(model.state, .content)
        XCTAssertFalse(model.isUnblocking)
    }

    func testUnblockWithRemainingRestrictionShowsNeutralFailureAndNeverLoadsLogs() async {
        let repository = RestrictedProfileStub()
        let moderation = RestrictedModerationStub()
        moderation.onUnblock = { repository.unavailable = true }
        let model = makeModel(repository, moderation)
        await model.loadIfNeeded(moderationRepository: moderation)
        await model.unblock()
        XCTAssertEqual(model.state, .failed(ErrorPresentation(message: "프로필을 볼 수 없습니다.", recoveryAction: .none)))
        XCTAssertNil(model.profile)
        XCTAssertTrue(model.logs.isEmpty)
        XCTAssertEqual(repository.logRequests, 0)
    }

    func testUnblockFailureKeepsRestrictedIdentityAndAllowsRetry() async {
        let repository = RestrictedProfileStub()
        let moderation = RestrictedModerationStub()
        moderation.shouldFail = true
        let model = makeModel(repository, moderation)
        await model.loadIfNeeded(moderationRepository: moderation)
        await model.unblock()
        XCTAssertEqual(model.state, .blocked)
        XCTAssertEqual(model.profile?.id, repository.id)
        XCTAssertNotNil(model.actionError)
        XCTAssertFalse(model.isUnblocking)
        XCTAssertEqual(repository.events, ["profile"])
    }

    func testDuplicateUnblockAndLeavingDuringRequest() async {
        let repository = RestrictedProfileStub()
        let moderation = RestrictedModerationStub()
        moderation.pauses = true
        let model = makeModel(repository, moderation)
        await model.loadIfNeeded(moderationRepository: moderation)
        let first = Task { await model.unblock() }
        while moderation.continuation == nil { await Task.yield() }
        await model.unblock()
        XCTAssertEqual(moderation.unblockedIDs.count, 1)
        let refreshed = expectation(forNotification: .maplogUserBlockDidChange, object: nil)
        model.finishManagingBlocks()
        moderation.continuation?.resume()
        await first.value
        await fulfillment(of: [refreshed], timeout: 1)
        XCTAssertFalse(model.isUnblocking)
    }

    func testRefreshRemovesPreviouslyVisibleLogsWhenProfileBecomesRestricted() async {
        let repository = RestrictedProfileStub()
        repository.blocked = false
        let moderation = RestrictedModerationStub()
        let model = makeModel(repository, moderation)
        await model.loadIfNeeded(moderationRepository: moderation)
        XCTAssertEqual(model.logs.count, 1)
        repository.blocked = true
        await model.reload()
        XCTAssertEqual(model.state, .blocked)
        XCTAssertTrue(model.logs.isEmpty)
        XCTAssertTrue(model.thumbnailDataByLogID.isEmpty)
        XCTAssertEqual(repository.logRequests, 1)
    }

    func testOnlyUnavailableProfileDoesNotRevealBlockingOrFetchContent() async {
        let repository = RestrictedProfileStub()
        repository.unavailable = true
        let model = makeModel(repository, RestrictedModerationStub())
        await model.loadIfNeeded()
        guard case let .failed(error) = model.state else { return XCTFail("Expected unavailable profile") }
        XCTAssertEqual(error.message, "프로필을 볼 수 없습니다.")
        XCTAssertEqual(repository.logRequests, 0)
    }

    func testDeletedBlockEntryCannotNavigate() {
        XCTAssertFalse(BlockedUser(id: UUID(), nickname: "탈퇴한 사용자").canOpenProfile)
        XCTAssertTrue(BlockedUser(id: UUID(), nickname: "slow.seoul").canOpenProfile)
    }

    private func makeModel(_ repository: RestrictedProfileStub, _ moderation: RestrictedModerationStub) -> PublicProfileViewModel {
        PublicProfileViewModel(
            user: FollowUser(id: repository.id, nickname: "slow.seoul", profileImageURL: nil),
            followRepository: RestrictedFollowStub(), profileRepository: repository
        )
    }
}

private final class RestrictedProfileStub: ProfileRepository {
    let id = UUID()
    var blocked = true
    var unavailable = false
    var events: [String] = []
    var logRequests = 0
    var viewerRequests = 0

    func fetchPublicProfile(nickname: String) async throws -> PublicProfile {
        events.append("profile")
        if unavailable {
            throw APIError.server(statusCode: 404, response: APIErrorResponse(
                successFlag: false, code: "COMMON-003", message: "User not found", data: nil
            ))
        }
        return PublicProfile(id: id, nickname: nickname, profileImageURL: nil, bio: "",
                             followerCount: 0, followingCount: 0, logCount: blocked ? 0 : 1,
                             isFollowedByViewer: false, createdAt: nil, isBlockedByViewer: blocked)
    }
    func fetchPublicProfileLogs(nickname: String, cursor: String?, size: Int) async throws -> ProfileLogPage {
        events.append("logs")
        logRequests += 1
        return ProfileLogPage(logs: [ProfileLog(id: 1, thumbnailURL: nil, address: "서울",
            videoDurationMillis: 1000, viewCount: 1, createdAt: .now)], hasNext: false, nextCursor: nil)
    }
    func fetchMyProfile() async throws -> MyProfile {
        viewerRequests += 1
        return MyProfile(id: UUID(), nickname: "viewer", profileImageURL: nil, bio: "",
                         followerCount: 0, followingCount: 0, logCount: 0)
    }
    func fetchMyLogs(cursor: String?, size: Int) async throws -> ProfileLogPage { throw APIError.invalidResponse }
    func updateMyProfile(_ update: ProfileUpdate) async throws -> MyProfile { throw APIError.invalidResponse }
    func deleteMyProfile() async throws { throw APIError.invalidResponse }
    func fetchImageData(from url: URL, cacheKey: String, targetSize: MaplogImageTargetSize) async throws -> Data {
        throw APIError.network(URLError(.notConnectedToInternet))
    }
}

private final class RestrictedModerationStub: ContentModerationRepository {
    var listRequests = 0
    var unblockedIDs: [UUID] = []
    var onUnblock: (() -> Void)?
    var shouldFail = false
    var pauses = false
    var continuation: CheckedContinuation<Void, Never>?
    func fetchBlockedUsers(page: Int) async throws -> BlockedUserPage {
        listRequests += 1
        throw APIError.invalidResponse
    }
    func unblockUser(id: UUID) async throws {
        unblockedIDs.append(id)
        if shouldFail { throw APIError.network(URLError(.notConnectedToInternet)) }
        if pauses { await withCheckedContinuation { continuation = $0 } }
        onUnblock?()
    }
    func reportLog(id: Int64, reason: String) async throws { throw APIError.invalidResponse }
    func blockUser(id: UUID) async throws { throw APIError.invalidResponse }
}

private struct RestrictedFollowStub: FollowRepository {
    func fetchUsers(kind: FollowListKind, cursor: String?, size: Int) async throws -> FollowUserPage { throw APIError.invalidResponse }
    func isFollowing(userID: UUID) async throws -> Bool { throw APIError.invalidResponse }
    func setFollowing(userID: UUID, isFollowing: Bool) async throws -> FollowState {
        XCTFail("Restricted profile must not request follow changes")
        throw APIError.invalidResponse
    }
}
