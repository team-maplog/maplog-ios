import AVFoundation
import XCTest
@testable import Maplog

@MainActor
final class HomeTourismPosterTests: XCTestCase {
    func testHomeExcludesUnverifiedImageAndUsesRegisteredPoster() async {
        let repository = PosterRepositoryStub()
        let posterURL = URL(string: "https://example.invalid/verified-poster.jpg")!
        repository.tourisms = [makeTourism(id: 1, posterURL: posterURL), makeTourism(id: 2)]
        let viewModel = makeViewModel(repository)
        await viewModel.loadInitialTourisms()
        guard case let .content(cards) = viewModel.tourismState else {
            return XCTFail("Expected verified poster card")
        }
        XCTAssertEqual(cards.map(\.id), [1])
        XCTAssertEqual(cards.first?.thumbnailURL, posterURL)
        XCTAssertEqual(repository.detailRequests, 0)
    }

    func testNoVerifiedPosterProducesEmptyHome() async {
        let repository = PosterRepositoryStub()
        repository.tourisms = [makeTourism(id: 1)]
        let viewModel = makeViewModel(repository)
        await viewModel.loadInitialTourisms()
        XCTAssertEqual(viewModel.tourismState, .empty)
    }

    func testFailedPosterRemovesCardWithoutUsingOrdinaryPhoto() async {
        let repository = PosterRepositoryStub()
        repository.tourisms = [makeTourism(id: 1, posterURL: URL(string: "https://example.invalid/poster.jpg"))]
        let viewModel = makeViewModel(repository)
        await viewModel.loadInitialTourisms()
        guard case let .content(cards) = viewModel.tourismState, let card = cards.first else {
            return XCTFail("Expected poster card")
        }
        viewModel.hideFailedTourismPoster(card)
        XCTAssertEqual(viewModel.tourismState, .empty)
    }

    func testDetailShowsVerifiedPosterFirstThenUniqueRelatedPhotos() async {
        let poster = URL(string: "https://example.invalid/verified-poster.jpg")!
        let related = URL(string: "https://example.invalid/related.jpg")!
        let original = URL(string: "https://example.invalid/original.jpg")!
        let repository = PosterRepositoryStub()
        repository.detail = makeDetail(original: original, images: [poster, related, related].map {
            TourismDetailImage(originalURL: $0, smallURL: nil, name: nil, copyrightCode: nil, serialNumber: nil)
        })
        repository.detail.verifiedPosterURL = poster
        let viewModel = TourismDetailViewModel(tourismID: 1, tourismRepository: repository)
        await viewModel.load()
        guard case let .content(data) = viewModel.state else { return XCTFail("Expected detail") }
        XCTAssertEqual(data.heroImageURL, poster)
        XCTAssertEqual(data.images.map(\.imageURL), [original, related])
    }

    func testUnverifiedDetailStillShowsRelatedPhotosFromFullList() async {
        let repository = PosterRepositoryStub()
        let viewModel = TourismDetailViewModel(tourismID: 1, tourismRepository: repository)
        await viewModel.load()
        guard case let .content(data) = viewModel.state else { return XCTFail("Expected detail") }
        XCTAssertEqual(data.heroImageURL, repository.detail.common.originalImageURL)
    }

    private func makeTourism(id: Int64, posterURL: URL? = nil) -> Tourism {
        Tourism(id: id, name: "축제", region: "서울", address: nil,
                thumbnailURL: URL(string: "https://example.invalid/ordinary-photo.jpg"),
                startDate: nil, endDate: nil, category: .events, verifiedPosterURL: posterURL)
    }

    private func makeViewModel(_ repository: PosterRepositoryStub) -> HomeViewModel {
        let unused = UnusedHomeDependencies()
        return HomeViewModel(tourismRepository: repository, logReelRepository: unused,
                             logInteractionRepository: unused, logMediaRepository: unused,
                             profileRepository: unused, playbackService: unused)
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
    var tourisms: [Tourism] = []
    func fetchTourismsWithVerifiedPosters(size: Int) async throws -> [Tourism] {
        if let error { throw error }
        return tourisms
    }
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
