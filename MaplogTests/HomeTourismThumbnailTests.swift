import AVFoundation
import XCTest
@testable import Maplog

@MainActor
final class HomeTourismThumbnailTests: XCTestCase {
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

    private func makeViewModel(_ repository: ThumbnailRepositoryStub) -> HomeViewModel {
        let unused = UnusedHomeDependencies()
        return HomeViewModel(tourismRepository: repository, logReelRepository: unused,
                             logInteractionRepository: unused, logMediaRepository: unused,
                             profileRepository: unused, playbackService: unused)
    }
}

@MainActor
private final class ThumbnailRepositoryStub: TourismRepository {
    let original = TourismPortraitImage(url: URL(string: "https://example.invalid/original.jpg")!,
                                       data: Data([1]), width: 200, height: 300)!
    var approvedIDs: Set<Int64> = [1]
    var failingIDs: Set<Int64> = []
    var error: Error = APIError.network(URLError(.notConnectedToInternet))
    var imageRequests: [Int64] = []
    var pageRequests = 0
    var pages: [[Int64]] = [[1, 2]]
    func fetchPortraitImage(tourismID: Int64) async throws -> TourismPortraitImage? {
        imageRequests.append(tourismID)
        if failingIDs.contains(tourismID) { throw error }
        return approvedIDs.contains(tourismID) ? original : nil
    }
    func fetchTourisms(category: TourismCategory, cursor: String?, size: Int) async throws -> TourismPage {
        let index = cursor.flatMap(Int.init) ?? 0
        pageRequests += 1
        let items = pages[index].map { Tourism(id: $0, name: "축제", region: "서울", address: nil,
            thumbnailURL: URL(string: "https://example.invalid/thumbnail.jpg"), startDate: nil, endDate: nil, category: .events) }
        return TourismPage(tourisms: items, hasNext: index + 1 < pages.count, nextCursor: String(index + 1))
    }
    func fetchTourismDetail(tourismID: Int64) async throws -> TourismDetail { fatalError("Repository resolves original") }
}

/// 관광 이미지 테스트에서 다른 기능의 네트워크·재생을 사용하지 않도록 막는다.
@MainActor
private final class UnusedHomeDependencies: LogReelRepository, LogInteractionRepository, LogMediaRepository, ProfileRepository, VideoPlaybackService {
    let player = AVPlayer()
    let isMuted = true
    func fetchReels(cursor: String?, size: Int) async throws -> LogReelPage { fatalError("Unused") }
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
