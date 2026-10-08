import Foundation
import XCTest
@testable import Maplog

@MainActor
final class ProfileViewModelTests: XCTestCase {
    func testLoadThenLoadNextPageAppendsLogs() async {
        let repository = ProfileRepositoryStub(
            profile: MyProfile(
                id: UUID(),
                nickname: "채림",
                profileImageURL: nil,
                bio: "여행을 기록합니다.",
                followerCount: 12,
                followingCount: 8,
                logCount: 2
            ),
            pages: [
                ProfileLogPage(
                    logs: [
                        makeLog(id: 1, address: "서울 성수동")
                    ],
                    hasNext: true,
                    nextCursor: "next-page"
                ),
                ProfileLogPage(
                    logs: [
                        makeLog(id: 2, address: "서울 연남동")
                    ],
                    hasNext: false,
                    nextCursor: nil
                )
            ]
        )
        let viewModel = ProfileTabViewModel(
            profileRepository: repository,
            logReelRepository: LogReelRepositoryStub()
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.state, .content)
        XCTAssertEqual(viewModel.profile?.nickname, "채림")
        XCTAssertEqual(viewModel.logs.map(\.id), [1])
        XCTAssertTrue(viewModel.hasNextPage)
        XCTAssertEqual(repository.requestedCursors, [nil])

        await viewModel.loadNextPage()

        XCTAssertEqual(viewModel.logs.map(\.id), [1, 2])
        XCTAssertFalse(viewModel.hasNextPage)
        XCTAssertEqual(repository.requestedCursors, [nil, "next-page"])
    }

    func testLoadSavedLogsThenLoadNextPageAppendsLogs() async {
        let profileRepository = ProfileRepositoryStub(
            profile: MyProfile(
                id: UUID(),
                nickname: "채림",
                profileImageURL: nil,
                bio: "",
                followerCount: 0,
                followingCount: 0,
                logCount: 0
            ),
            pages: []
        )
        let savedLogsRepository = LogReelRepositoryStub(
            savedPages: [
                LogReelPage(
                    reels: [makeSavedLog(id: 41, address: "서울 연남동")],
                    hasNext: true,
                    nextCursor: "saved-next-page"
                ),
                LogReelPage(
                    reels: [makeSavedLog(id: 42, address: "서울 성수동")],
                    hasNext: false,
                    nextCursor: nil
                )
            ]
        )
        let viewModel = ProfileTabViewModel(
            profileRepository: profileRepository,
            logReelRepository: savedLogsRepository
        )

        await viewModel.loadSavedLogsIfNeeded()

        XCTAssertEqual(viewModel.savedLogsState, .content)
        XCTAssertEqual(viewModel.savedLogs.map(\.id), [41])
        XCTAssertTrue(viewModel.hasNextSavedLogsPage)
        XCTAssertEqual(savedLogsRepository.requestedSavedCursors, [nil])

        await viewModel.loadNextSavedLogsPage()

        XCTAssertEqual(viewModel.savedLogs.map(\.id), [41, 42])
        XCTAssertFalse(viewModel.hasNextSavedLogsPage)
        XCTAssertEqual(
            savedLogsRepository.requestedSavedCursors,
            [nil, "saved-next-page"]
        )
    }

    func testReloadKeepsVisibleProfileWhenRequestIsCancelled() async {
        let repository = ProfileRepositoryStub(
            profile: MyProfile(
                id: UUID(),
                nickname: "채림",
                profileImageURL: nil,
                bio: "여행을 기록합니다.",
                followerCount: 12,
                followingCount: 8,
                logCount: 1
            ),
            pages: [
                ProfileLogPage(
                    logs: [makeLog(id: 1, address: "서울 성수동")],
                    hasNext: false,
                    nextCursor: nil
                )
            ]
        )
        let viewModel = ProfileTabViewModel(
            profileRepository: repository,
            logReelRepository: LogReelRepositoryStub()
        )

        await viewModel.loadIfNeeded()
        repository.shouldCancelProfileFetch = true

        await viewModel.reload()

        XCTAssertEqual(viewModel.state, .content)
        XCTAssertEqual(viewModel.profile?.nickname, "채림")
        XCTAssertEqual(viewModel.logs.map(\.id), [1])
    }

    func testReloadSavedLogsKeepsVisibleContentWhenRequestIsCancelled() async {
        let savedLogsRepository = LogReelRepositoryStub(
            savedPages: [
                LogReelPage(
                    reels: [makeSavedLog(id: 41, address: "서울 연남동")],
                    hasNext: false,
                    nextCursor: nil
                )
            ]
        )
        let viewModel = ProfileTabViewModel(
            profileRepository: ProfileRepositoryStub(
                profile: MyProfile(
                    id: UUID(),
                    nickname: "채림",
                    profileImageURL: nil,
                    bio: "",
                    followerCount: 0,
                    followingCount: 0,
                    logCount: 0
                ),
                pages: []
            ),
            logReelRepository: savedLogsRepository
        )

        await viewModel.loadSavedLogsIfNeeded()
        savedLogsRepository.shouldCancelSavedLogsFetch = true

        await viewModel.reloadSavedLogs()

        XCTAssertEqual(viewModel.savedLogsState, .content)
        XCTAssertEqual(viewModel.savedLogs.map(\.id), [41])
    }

    func testFollowCountRefreshUpdatesHeaderWithoutReloadingLogPages() async {
        let repository = ProfileRepositoryStub(profile: followProfile(8), pages: [
            .init(logs: [makeLog(id: 1, address: "서울")], hasNext: true, nextCursor: "next")
        ])
        let model = ProfileTabViewModel(profileRepository: repository, logReelRepository: LogReelRepositoryStub())
        await model.loadIfNeeded()
        repository.profile = followProfile(9, id: repository.profile.id)
        await model.refreshAfterFollowChange()
        XCTAssertEqual(model.profile?.followingCountText, "9")
        XCTAssertEqual(model.profile?.followerCountText, "12")
        XCTAssertEqual(model.logs.map(\.id), [1])
        XCTAssertTrue(model.hasNextPage)
        XCTAssertEqual(repository.requestedCursors.count, 1)
        repository.profile = followProfile(8, id: repository.profile.id)
        await model.refreshAfterFollowChange()
        XCTAssertEqual(model.profile?.followingCountText, "8")
        XCTAssertEqual(repository.profileRequests, 3)
    }

    func testFailedHeaderRefreshKeepsContentAndRetriesOnNextAppearance() async {
        let repository = ProfileRepositoryStub(profile: followProfile(8), pages: [])
        let model = ProfileTabViewModel(profileRepository: repository, logReelRepository: LogReelRepositoryStub())
        await model.loadIfNeeded()
        repository.profileError = APIError.invalidResponse
        await model.refreshAfterFollowChange()
        XCTAssertEqual(model.state, .content)
        XCTAssertEqual(model.profile?.followingCountText, "8")
        repository.profileError = nil
        repository.profile = followProfile(9, id: repository.profile.id)
        await model.refreshProfileHeaderIfNeeded()
        XCTAssertEqual(model.profile?.followingCountText, "9")
    }

    func testFollowBeforeInitialProfileLoadUsesFirstLoadWithoutExtraRequest() async {
        let repository = ProfileRepositoryStub(profile: followProfile(9), pages: [])
        let model = ProfileTabViewModel(profileRepository: repository, logReelRepository: LogReelRepositoryStub())
        await model.refreshAfterFollowChange()
        XCTAssertEqual(repository.profileRequests, 0)
        await model.loadIfNeeded()
        XCTAssertEqual(model.profile?.followingCountText, "9")
        XCTAssertEqual(repository.profileRequests, 1)
    }

    func testOldFullReloadCannotOverwriteRefreshedFollowCount() async {
        let repository = ProfileRepositoryStub(profile: followProfile(8), pages: [])
        let model = ProfileTabViewModel(profileRepository: repository, logReelRepository: LogReelRepositoryStub())
        await model.loadIfNeeded()
        let started = expectation(description: "old profile request started")
        var continuation: CheckedContinuation<MyProfile, Never>?
        repository.profileHandler = {
            await withCheckedContinuation { continuation = $0; started.fulfill() }
        }
        let oldReload = Task { await model.reload() }
        await fulfillment(of: [started], timeout: 2)
        repository.profileHandler = nil
        repository.profile = followProfile(9, id: repository.profile.id)
        await model.refreshAfterFollowChange()
        continuation?.resume(returning: followProfile(8, id: repository.profile.id))
        await oldReload.value
        XCTAssertEqual(model.profile?.followingCountText, "9")
    }

    func testSecondFollowDuringHeaderFetchRequestsNewerCount() async {
        let repository = ProfileRepositoryStub(profile: followProfile(8), pages: [])
        let model = ProfileTabViewModel(profileRepository: repository, logReelRepository: LogReelRepositoryStub())
        await model.loadIfNeeded()
        let started = expectation(description: "first header refresh started")
        var continuation: CheckedContinuation<MyProfile, Never>?
        repository.profileHandler = {
            await withCheckedContinuation { continuation = $0; started.fulfill() }
        }
        let firstChange = Task { await model.refreshAfterFollowChange() }
        await fulfillment(of: [started], timeout: 2)
        repository.profileHandler = nil
        repository.profile = followProfile(10, id: repository.profile.id)
        await model.refreshAfterFollowChange()
        continuation?.resume(returning: followProfile(9, id: repository.profile.id))
        await firstChange.value
        XCTAssertEqual(model.profile?.followingCountText, "10")
        XCTAssertEqual(repository.profileRequests, 3)
    }

    private func followProfile(_ following: Int64, id: UUID = UUID()) -> MyProfile {
        MyProfile(id: id, nickname: "fixture", profileImageURL: nil, bio: "", followerCount: 12, followingCount: following, logCount: 1)
    }

    private func makeLog(
        id: Int64,
        address: String
    ) -> ProfileLog {
        ProfileLog(
            id: id,
            thumbnailURL: nil,
            address: address,
            videoDurationMillis: 65_000,
            viewCount: 42,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func makeSavedLog(
        id: Int64,
        address: String
    ) -> LogReel {
        LogReel(
            id: id,
            author: LogReelAuthor(
                id: UUID(),
                nickname: "여행자",
                profileImageURL: nil
            ),
            caption: "저장한 여행 기록",
            tags: [],
            address: address,
            thumbnailURL: nil,
            playbackURL: nil,
            publishedAt: Date(timeIntervalSince1970: 0),
            viewCount: 42,
            clips: [],
            likeCount: 0,
            commentCount: 0,
            isLikedByViewer: false,
            isSavedByViewer: true
        )
    }
}

private final class ProfileRepositoryStub: ProfileRepository {
    var profile: MyProfile
    var profileError: Error?
    var profileRequests = 0
    var profileHandler: (() async -> MyProfile)?
    private var pages: [ProfileLogPage]
    private(set) var requestedCursors: [String?] = []
    var shouldCancelProfileFetch = false

    init(
        profile: MyProfile,
        pages: [ProfileLogPage]
    ) {
        self.profile = profile
        self.pages = pages
    }

    func fetchMyProfile() async throws -> MyProfile {
        profileRequests += 1
        if let profileError { throw profileError }
        if let profileHandler { return await profileHandler() }
        if shouldCancelProfileFetch {
            throw CancellationError()
        }

        return profile
    }

    func fetchPublicProfile(
        nickname: String
    ) async throws -> PublicProfile {
        fatalError("This test does not request a public profile.")
    }

    func fetchMyLogs(
        cursor: String?,
        size: Int
    ) async throws -> ProfileLogPage {
        requestedCursors.append(cursor)

        guard !pages.isEmpty else {
            return ProfileLogPage(
                logs: [],
                hasNext: false,
                nextCursor: nil
            )
        }

        return pages.removeFirst()
    }

    func fetchPublicProfileLogs(
        nickname: String,
        cursor: String?,
        size: Int
    ) async throws -> ProfileLogPage {
        fatalError("This test does not request public profile logs.")
    }

    func updateMyProfile(
        _ update: ProfileUpdate
    ) async throws -> MyProfile {
        profile
    }

    func deleteMyProfile() async throws {}

    func fetchImageData(
        from url: URL,
        cacheKey: String,
        targetSize: MaplogImageTargetSize
    ) async throws -> Data {
        Data()
    }
}

private final class LogReelRepositoryStub: LogReelRepository {
    private var savedPages: [LogReelPage]
    private(set) var requestedSavedCursors: [String?] = []
    var shouldCancelSavedLogsFetch = false

    init(savedPages: [LogReelPage] = []) {
        self.savedPages = savedPages
    }

    func fetchReels(
        cursor: String?,
        size: Int
    ) async throws -> LogReelPage {
        LogReelPage(
            reels: [],
            hasNext: false,
            nextCursor: nil
        )
    }

    func fetchSavedLogs(
        cursor: String?,
        size: Int
    ) async throws -> LogReelPage {
        if shouldCancelSavedLogsFetch {
            throw CancellationError()
        }

        requestedSavedCursors.append(cursor)

        guard !savedPages.isEmpty else {
            return LogReelPage(
                reels: [],
                hasNext: false,
                nextCursor: nil
            )
        }

        return savedPages.removeFirst()
    }
}
