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
