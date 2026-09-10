import AVFoundation
import XCTest
@testable import Maplog

@MainActor
final class HomeTourismPosterTests: XCTestCase {
    func testHomeUsesSameOriginalAsDetailAndReusesResolvedURL() async {
        let repository = PosterRepositoryStub()
        let viewModel = makeViewModel(repository)
        let card = makeCard()
        XCTAssertNil(viewModel.tourismPosterURL(for: card))

        await viewModel.loadTourismPoster(for: card)
        await viewModel.loadTourismPoster(for: card)

        XCTAssertEqual(viewModel.tourismPosterURL(for: card), repository.detail.representativeImageURL)
        XCTAssertNotEqual(viewModel.tourismPosterURL(for: card), card.thumbnailURL)
        XCTAssertEqual(repository.detailRequests, 1)
    }

    func testDetailFailureKeepsListAndFallsBackThenRetries() async {
        let repository = PosterRepositoryStub()
        repository.error = URLError(.notConnectedToInternet)
        let viewModel = makeViewModel(repository)
        await viewModel.loadInitialTourisms()
        let stateBefore = viewModel.tourismState
        let card = makeCard()

        await viewModel.loadTourismPoster(for: card)
        XCTAssertEqual(viewModel.tourismPosterURL(for: card), card.thumbnailURL)
        XCTAssertEqual(viewModel.tourismState, stateBefore)

        repository.error = nil
        await viewModel.loadTourismPoster(for: card)
        XCTAssertEqual(viewModel.tourismPosterURL(for: card), repository.detail.representativeImageURL)
        XCTAssertEqual(repository.detailRequests, 2)
    }

    func testCancelledResolutionCanRetryWithoutMarkingFallback() async {
        let repository = PosterRepositoryStub()
        repository.error = CancellationError()
        let viewModel = makeViewModel(repository)
        let card = makeCard()
        await viewModel.loadTourismPoster(for: card)
        XCTAssertNil(viewModel.tourismPosterURL(for: card))
        repository.error = nil
        await viewModel.loadTourismPoster(for: card)
        XCTAssertEqual(viewModel.tourismPosterURL(for: card), repository.detail.representativeImageURL)
    }

    func testRepresentativeImageFallsBackToAdditionalImageThenThumbnail() {
        let original = URL(string: "https://example.invalid/additional-original.jpg")!
        let image = TourismDetailImage(originalURL: original, smallURL: nil, name: nil, copyrightCode: nil, serialNumber: nil)
        XCTAssertEqual(makeDetail(original: nil, images: [image]).representativeImageURL, original)
        XCTAssertEqual(makeDetail(original: nil).representativeImageURL, URL(string: "https://example.invalid/detail-thumbnail.jpg"))
    }

    private func makeViewModel(_ repository: PosterRepositoryStub) -> HomeViewModel {
        let unused = UnusedHomeDependencies()
        return HomeViewModel(tourismRepository: repository, logReelRepository: unused,
                             logInteractionRepository: unused, logMediaRepository: unused,
                             profileRepository: unused, playbackService: unused)
    }

    private func makeCard() -> HomeTourismCardViewData {
        HomeTourismCardViewData(id: 1, title: "포스터", locationText: "서울",
                               periodText: "09.09 – 09.10", dDayText: nil,
                               thumbnailURL: URL(string: "https://example.invalid/list-thumbnail.jpg"))
    }
}

private func makeDetail(original: URL? = URL(string: "https://example.invalid/original.jpg"), images: [TourismDetailImage] = []) -> TourismDetail {
    TourismDetail(id: 1, category: .events, common: TourismDetailCommonInfo(
        name: "포스터", createdAt: nil, modifiedAt: nil, tel: nil, telName: nil,
        homepageURL: nil, thumbnailURL: URL(string: "https://example.invalid/detail-thumbnail.jpg"),
        originalImageURL: original, copyrightCode: nil, regionCode: nil, districtCode: nil,
        classification1: nil, classification2: nil, classification3: nil, region: "서울",
        address: nil, zipCode: nil, longitude: nil, latitude: nil, mapLevel: nil, overview: nil
    ), introduction: nil, repeatInfo: [], images: images, petTour: nil)
}

private final class PosterRepositoryStub: TourismRepository {
    var detail = makeDetail()
    var error: Error?
    var detailRequests = 0
    func fetchTourisms(category: TourismCategory, cursor: String?, size: Int) async throws -> TourismPage {
        TourismPage(tourisms: [Tourism(id: 1, name: "포스터", region: "서울", address: nil,
                                     thumbnailURL: URL(string: "https://example.invalid/list-thumbnail.jpg"),
                                     startDate: nil, endDate: nil, category: .events)], hasNext: false, nextCursor: nil)
    }
    func fetchTourismDetail(tourismID: Int64) async throws -> TourismDetail {
        detailRequests += 1
        if let error { throw error }
        return detail
    }
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
