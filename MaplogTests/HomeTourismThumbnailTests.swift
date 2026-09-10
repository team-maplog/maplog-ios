import AVFoundation
import XCTest
@testable import Maplog

@MainActor
final class HomeTourismThumbnailTests: XCTestCase {
    func testHomeUsesListThumbnailWithoutFetchingDetail() async {
        let repository = ThumbnailRepositoryStub()
        let viewModel = makeViewModel(repository)
        await viewModel.loadInitialTourisms()
        guard case let .content(cards) = viewModel.tourismState else {
            return XCTFail("Expected thumbnail card")
        }
        XCTAssertEqual(cards.first?.thumbnailURL, repository.thumbnailURL)
        XCTAssertEqual(cards.first?.id, 1)
        XCTAssertEqual(repository.detailRequests, 0)
    }

    func testMissingThumbnailKeepsFestivalWithPlaceholder() async {
        let repository = ThumbnailRepositoryStub()
        repository.thumbnailURL = nil
        let viewModel = makeViewModel(repository)
        await viewModel.loadInitialTourisms()
        guard case let .content(cards) = viewModel.tourismState else {
            return XCTFail("Festival should remain available")
        }
        XCTAssertEqual(cards.count, 1)
        XCTAssertNil(cards.first?.thumbnailURL)
    }

    func testEmptyListProducesEmptyState() async {
        let repository = ThumbnailRepositoryStub()
        repository.isEmpty = true
        let viewModel = makeViewModel(repository)
        await viewModel.loadInitialTourisms()
        XCTAssertEqual(viewModel.tourismState, .empty)
    }

    private func makeViewModel(_ repository: ThumbnailRepositoryStub) -> HomeViewModel {
        let unused = UnusedHomeDependencies()
        return HomeViewModel(tourismRepository: repository, logReelRepository: unused,
                             logInteractionRepository: unused, logMediaRepository: unused,
                             profileRepository: unused, playbackService: unused)
    }
}

private final class ThumbnailRepositoryStub: TourismRepository {
    var thumbnailURL = URL(string: "https://example.invalid/list-thumbnail.jpg")
    var detailRequests = 0
    var isEmpty = false
    func fetchTourisms(category: TourismCategory, cursor: String?, size: Int) async throws -> TourismPage {
        let items = isEmpty ? [] : [Tourism(id: 1, name: "축제", region: "서울", address: nil,
            thumbnailURL: thumbnailURL, startDate: nil, endDate: nil, category: .events)]
        return TourismPage(tourisms: items, hasNext: false, nextCursor: nil)
    }
    func fetchTourismDetail(tourismID: Int64) async throws -> TourismDetail {
        detailRequests += 1
        throw URLError(.unsupportedURL)
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
