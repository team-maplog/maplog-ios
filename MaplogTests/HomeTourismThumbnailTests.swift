import AVFoundation
import XCTest
@testable import Maplog

@MainActor
final class HomeTourismThumbnailTests: XCTestCase {
    func testTourismReadinessWaitsForResponseAndDoesNotRequireReels() async {
        let repository = ThumbnailRepositoryStub()
        let started = expectation(description: "Tourism request started")
        var response: CheckedContinuation<Void, Never>?
        repository.beforePageResponse = {
            await withCheckedContinuation { continuation in
                response = continuation
                started.fulfill()
            }
        }
        let model = makeViewModel(repository)
        XCTAssertFalse(model.hasResolvedInitialTourisms)
        let task = Task { await model.loadInitialTourisms() }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertEqual(model.tourismState, .loading)
        XCTAssertFalse(model.hasResolvedInitialTourisms)
        response?.resume()
        await task.value
        XCTAssertTrue(model.hasResolvedInitialTourisms)
        XCTAssertFalse(model.hasPreparedInitialContent)
        guard case .content = model.tourismState else { return XCTFail("Expected cards") }
    }

    func testSplashPreparationLoadsBothSectionsAndHomeReusesResults() async {
        let repository = ThumbnailRepositoryStub()
        let dependencies = UnusedHomeDependencies()
        let model = HomeViewModel(tourismRepository: repository, logReelRepository: dependencies,
                                  logInteractionRepository: dependencies, logMediaRepository: dependencies,
                                  profileRepository: dependencies, playbackService: dependencies)
        await model.prepareInitialContent()
        XCTAssertTrue(model.hasPreparedInitialContent)
        XCTAssertEqual(model.reelState, .empty)
        guard case .content = model.tourismState else { return XCTFail("Expected tourism cards") }
        await model.prepareInitialContent()
        await model.loadInitialTourisms()
        await model.loadInitialReels()
        XCTAssertEqual(repository.pageRequests, 1)
        XCTAssertEqual(dependencies.reelRequests, 1)
    }

    func testFailedTourismPreparationStillCompletesWithRetryState() async {
        let repository = ThumbnailRepositoryStub()
        repository.failingIDs = [1, 2]
        let model = makeViewModel(repository)
        await model.prepareInitialContent()
        XCTAssertTrue(model.hasPreparedInitialContent)
        XCTAssertEqual(model.reelState, .empty)
        guard case let .failed(error) = model.tourismState else { return XCTFail("Expected failure") }
        XCTAssertTrue(model.hasResolvedInitialTourisms)
        XCTAssertEqual(error.recoveryAction, .retry)
        await model.prepareInitialContent()
        XCTAssertEqual(repository.pageRequests, 1)
    }

    func testCancelledPreparationDoesNotPublishCompletion() async {
        let repository = ThumbnailRepositoryStub()
        let model = makeViewModel(repository)
        let task = Task { await model.prepareInitialContent() }
        task.cancel()
        await task.value
        XCTAssertFalse(model.hasPreparedInitialContent)
        XCTAssertEqual(model.tourismState, .idle)
        XCTAssertEqual(model.reelState, .idle)
    }

    func testReturningHomeKeepsCardsAndDoesNotRescanImages() async {
        let repository = ThumbnailRepositoryStub()
        let viewModel = makeViewModel(repository)
        await viewModel.loadInitialTourisms()
        let initialState = viewModel.tourismState
        await viewModel.loadInitialTourisms()
        await viewModel.refreshHome()
        XCTAssertEqual(viewModel.tourismState, initialState)
        XCTAssertEqual(repository.pageRequests, 1)
        XCTAssertEqual(repository.imageRequests.sorted(), [1, 2])
    }

    func testEmptyHomeResultIsAlsoReused() async {
        let repository = ThumbnailRepositoryStub()
        repository.approvedIDs = []
        let viewModel = makeViewModel(repository)
        await viewModel.loadInitialTourisms()
        await viewModel.loadInitialTourisms()
        XCTAssertEqual(viewModel.tourismState, .empty)
        XCTAssertEqual(repository.pageRequests, 1)
        XCTAssertTrue(viewModel.hasResolvedInitialTourisms)
    }

    func testHomeRefreshesAfterTenMinutes() async {
        let repository = ThumbnailRepositoryStub()
        var instant = Date(timeIntervalSince1970: 1_790_000_000)
        let viewModel = makeViewModel(repository, now: { instant })
        await viewModel.loadInitialTourisms()
        instant.addTimeInterval(599)
        await viewModel.loadInitialTourisms()
        XCTAssertEqual(repository.pageRequests, 1)
        instant.addTimeInterval(1)
        await viewModel.loadInitialTourisms()
        XCTAssertEqual(repository.pageRequests, 2)
    }

    func testUserRefreshBypassesFreshHomeCards() async {
        let repository = ThumbnailRepositoryStub()
        let viewModel = makeViewModel(repository)
        await viewModel.loadInitialTourisms()
        await viewModel.refreshHome(tourismPolicy: .reload)
        XCTAssertEqual(repository.pagePolicies, [.cached, .reload])
    }

    func testAutomaticHomeRefreshUsesCachePolicy() async {
        let repository = ThumbnailRepositoryStub()
        await makeViewModel(repository).refreshHome()
        XCTAssertEqual(repository.pagePolicies, [.cached])
        XCTAssertEqual(repository.imagePolicies, [.cached, .cached])
    }

    func testUserRefreshReloadsBothPagesAndPortraitMetadata() async {
        let repository = ThumbnailRepositoryStub()
        await makeViewModel(repository).refreshHome(tourismPolicy: .reload)
        XCTAssertEqual(repository.pagePolicies, [.reload])
        XCTAssertEqual(repository.imagePolicies, [.reload, .reload])
    }

    func testHomeUsesApprovedOriginalInsteadOfListThumbnail() async throws {
        let repository = ThumbnailRepositoryStub()
        let viewModel = makeViewModel(repository)
        await viewModel.loadInitialTourisms()
        guard case let .content(cards) = viewModel.tourismState else { return XCTFail("Expected original card") }
        XCTAssertEqual(cards.map(\.id), [1])
        XCTAssertEqual(cards.first?.poster.url, repository.original.url)
        XCTAssertEqual(repository.imageRequests.sorted(), [1, 2])
    }

    func testNoPortraitImagesProducesEmptyState() async {
        let repository = ThumbnailRepositoryStub()
        repository.approvedIDs = []
        let viewModel = makeViewModel(repository)
        await viewModel.loadInitialTourisms()
        XCTAssertEqual(viewModel.tourismState, .empty)
    }

    func testFilteredFirstPageContinuesToNextPage() async {
        let repository = ThumbnailRepositoryStub()
        repository.pages = [[1, 2], [3]]
        repository.approvedIDs = [3]
        let viewModel = makeViewModel(repository)
        await viewModel.loadInitialTourisms()
        guard case let .content(cards) = viewModel.tourismState else { return XCTFail("Expected second-page poster") }
        XCTAssertEqual(cards.map(\.id), [3])
        XCTAssertEqual(repository.pageRequests, 2)
    }

    func testCandidateScanStopsAfterThreePages() async {
        let repository = ThumbnailRepositoryStub()
        repository.pages = [[1], [2], [3], [4]]
        repository.approvedIDs = [4]
        let viewModel = makeViewModel(repository)
        await viewModel.loadInitialTourisms()
        XCTAssertEqual(viewModel.tourismState, .empty)
        XCTAssertEqual(repository.pageRequests, 3)
    }

    func testOneFailedImageDoesNotRemoveSuccessfulCard() async {
        let repository = ThumbnailRepositoryStub()
        repository.failingIDs = [2]
        let viewModel = makeViewModel(repository)
        await viewModel.loadInitialTourisms()
        guard case let .content(cards) = viewModel.tourismState else { return XCTFail("Expected surviving card") }
        XCTAssertEqual(cards.map(\.id), [1])
    }

    func testAllImageRequestsFailShowsRetryInsteadOfEmpty() async {
        let repository = ThumbnailRepositoryStub()
        repository.failingIDs = [1, 2]
        let viewModel = makeViewModel(repository)
        await viewModel.loadInitialTourisms()
        guard case let .failed(error) = viewModel.tourismState else { return XCTFail("Expected failure") }
        XCTAssertEqual(error.recoveryAction, .retry)
    }

    func testCancellationRestoresIdleState() async {
        let repository = ThumbnailRepositoryStub()
        repository.error = CancellationError()
        repository.failingIDs = [1, 2]
        let viewModel = makeViewModel(repository)
        await viewModel.loadInitialTourisms()
        XCTAssertEqual(viewModel.tourismState, .idle)
    }

    func testAuthenticationFailureIsNotHiddenBySuccessfulCard() async {
        let repository = ThumbnailRepositoryStub()
        repository.error = APIError.missingAccessToken
        repository.failingIDs = [2]
        let viewModel = makeViewModel(repository)
        await viewModel.loadInitialTourisms()
        guard case let .failed(error) = viewModel.tourismState else { return XCTFail("Expected sign-in") }
        XCTAssertEqual(error.recoveryAction, .signIn)
    }

    private func makeViewModel(_ repository: ThumbnailRepositoryStub, now: @escaping () -> Date = { Date() }) -> HomeViewModel {
        let unused = UnusedHomeDependencies()
        return HomeViewModel(tourismRepository: repository, logReelRepository: unused,
                             logInteractionRepository: unused, logMediaRepository: unused,
                             profileRepository: unused, playbackService: unused, now: now)
    }
}

@MainActor
private final class ThumbnailRepositoryStub: TourismRepository {
    func invalidateCache() async {}
    let original = TourismPortraitImage(url: URL(string: "https://example.invalid/original.jpg")!,
                                       data: Data([1]), width: 200, height: 300)!
    var approvedIDs: Set<Int64> = [1]
    var failingIDs: Set<Int64> = []
    var error: Error = APIError.network(URLError(.notConnectedToInternet))
    var imageRequests: [Int64] = []
    var pageRequests = 0
    var pagePolicies: [TourismFetchPolicy] = []
    var imagePolicies: [TourismFetchPolicy] = []
    var pages: [[Int64]] = [[1, 2]]
    var beforePageResponse: (() async -> Void)?
    func fetchPortraitImage(tourismID: Int64, policy: TourismFetchPolicy) async throws -> TourismPortraitImage? {
        imageRequests.append(tourismID)
        imagePolicies.append(policy)
        if failingIDs.contains(tourismID) { throw error }
        return approvedIDs.contains(tourismID) ? original : nil
    }
    func fetchTourisms(category: TourismCategory, cursor: String?, size: Int, policy: TourismFetchPolicy) async throws -> TourismPage {
        await beforePageResponse?()
        let index = cursor.flatMap(Int.init) ?? 0
        pageRequests += 1
        pagePolicies.append(policy)
        let items = pages[index].map { Tourism(id: $0, name: "축제", region: "서울", address: nil,
            thumbnailURL: URL(string: "https://example.invalid/thumbnail.jpg"), startDate: nil, endDate: nil, category: .events) }
        return TourismPage(tourisms: items, hasNext: index + 1 < pages.count, nextCursor: String(index + 1))
    }
    func fetchTourismDetail(tourismID: Int64, policy: TourismFetchPolicy) async throws -> TourismDetail { fatalError("Repository resolves original") }
}

/// 관광 이미지 테스트에서 다른 기능의 네트워크·재생을 사용하지 않도록 막는다.
@MainActor
private final class UnusedHomeDependencies: LogReelRepository, LogInteractionRepository, LogMediaRepository, ProfileRepository, VideoPlaybackService {
    let player = AVPlayer()
    let isMuted = true
    var reelRequests = 0
    func fetchReels(cursor: String?, size: Int) async throws -> LogReelPage {
        reelRequests += 1
        return LogReelPage(reels: [], hasNext: false, nextCursor: nil)
    }
    func fetchSavedLogs(cursor: String?, size: Int) async throws -> LogReelPage { fatalError("Unused") }
    func setLike(logID: Int64, isLiked: Bool) async throws -> LogLikeInteractionResult { fatalError("Unused") }
    func setSaved(logID: Int64, isSaved: Bool) async throws -> LogSaveInteractionResult { fatalError("Unused") }
    func fetchThumbnailData(logID: Int64, targetSize: MaplogImageTargetSize) async throws -> Data { fatalError("Unused") }
    func fetchPlaybackFileURL(logID: Int64) async throws -> URL { fatalError("Unused") }
    func fetchRoutePointThumbnailData(from url: URL, targetSize: MaplogImageTargetSize) async throws -> Data { fatalError("Unused") }
    func fetchMyProfile() async throws -> MyProfile { fatalError("Unused") }
    func fetchPublicProfile(nickname: String) async throws -> PublicProfile { fatalError("Unused") }
    func fetchMyLogs(cursor: String?, size: Int) async throws -> ProfileLogPage { fatalError("Unused") }
    func fetchPublicProfileLogs(nickname: String, cursor: String?, size: Int) async throws -> ProfileLogPage { fatalError("Unused") }
    func updateMyProfile(_ update: ProfileUpdate) async throws -> MyProfile { fatalError("Unused") }
    func deleteMyProfile() async throws { fatalError("Unused") }
    func fetchImageData(from url: URL, cacheKey: String, targetSize: MaplogImageTargetSize) async throws -> Data { fatalError("Unused") }
    func loadVideo(at url: URL) { fatalError("Unused") }
    func loadVideoSequence(from urls: [URL]) async throws { fatalError("Unused") }
    func loadVideoComposition(from clips: [CaptureDraftClip], configuration: VideoCompositionConfiguration) async throws { fatalError("Unused") }
    func seek(to seconds: TimeInterval) { fatalError("Unused") }
    func seek(to seconds: TimeInterval, completion: @escaping @Sendable (Bool) -> Void) { fatalError("Unused") }
    func toggleMute() { fatalError("Unused") }
    func play() { fatalError("Unused") }
    func pause() {}
    func stop() {}
    func observeProgress(_ handler: @escaping (Double) -> Void) {}
}
