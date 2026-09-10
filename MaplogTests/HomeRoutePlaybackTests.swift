import AVFoundation
import XCTest
@testable import Maplog

@MainActor
final class HomeRoutePlaybackTests: XCTestCase {
    func testCancelledDownloadCanReloadSameReelAtSelectedTime() async {
        let dependencies = RoutePlaybackDependencies()
        dependencies.cancelsFirstDownload = true
        let model = makeModel(dependencies)
        await model.playReel(withID: 2, from: 0)
        await model.playReel(withID: 2, from: 12_000)
        XCTAssertEqual(dependencies.downloadCount, 2)
        XCTAssertEqual(dependencies.loadCount, 1)
        XCTAssertEqual(dependencies.seekTimes.last, 12)
    }

    func testFailedSeekShowsRetryInsteadOfFrozenPreview() async {
        let dependencies = RoutePlaybackDependencies()
        let model = makeModel(dependencies)
        await model.playReel(withID: 2, from: 12_000)
        dependencies.seekCompletions.last?(false)
        await Task.yield()
        XCTAssertTrue(model.hasPlaybackFailed(for: 2))
        XCTAssertEqual(dependencies.playCount, 0)
    }

    func testOldSeekCannotRestartSameReelAfterStopAndReload() async {
        let dependencies = RoutePlaybackDependencies()
        let model = makeModel(dependencies)
        await model.playReel(withID: 2, from: 12_000)
        let oldCompletion = dependencies.seekCompletions[0]
        model.stopPlayback()
        await model.playReel(withID: 2, from: 12_000)
        oldCompletion(true)
        await Task.yield()
        XCTAssertEqual(dependencies.playCount, 0)
        dependencies.seekCompletions.last?(true)
        await Task.yield()
        XCTAssertEqual(dependencies.playCount, 1)
    }

    func testLatestRoutePointWinsAndSuccessfulSeekStartsPlayback() async {
        let dependencies = RoutePlaybackDependencies()
        let model = makeModel(dependencies)
        await model.playReel(withID: 2, from: 12_000)
        await model.playReel(withID: 2, from: 24_000)
        XCTAssertEqual(dependencies.downloadCount, 1)
        XCTAssertEqual(dependencies.seekTimes, [12, 24])
        dependencies.seekCompletions[0](false)
        await Task.yield()
        XCTAssertFalse(model.hasPlaybackFailed(for: 2))
        dependencies.seekCompletions[1](true)
        await Task.yield()
        XCTAssertEqual(dependencies.playCount, 1)
    }

    func testCancelledOldDownloadDoesNotClearNewPlaybackForSameReel() async {
        let dependencies = RoutePlaybackDependencies()
        dependencies.delaysFirstDownload = true
        let model = makeModel(dependencies)
        let oldRequest = Task { await model.playReel(withID: 2, from: 0) }
        for _ in 0..<100 where dependencies.firstDownloadContinuation == nil { await Task.yield() }
        guard let continuation = dependencies.firstDownloadContinuation else {
            oldRequest.cancel()
            return XCTFail("Download did not begin")
        }
        model.stopPlayback()
        await model.playReel(withID: 2, from: 12_000)
        continuation.resume(throwing: CancellationError())
        await oldRequest.value
        XCTAssertNotNil(model.player(for: 2))
        XCTAssertFalse(model.hasPlaybackFailed(for: 2))
        XCTAssertEqual(dependencies.loadCount, 1)
        dependencies.seekCompletions.last?(true)
        await Task.yield()
        XCTAssertEqual(dependencies.playCount, 1)
    }

    private func makeModel(_ dependencies: RoutePlaybackDependencies) -> HomeViewModel {
        HomeViewModel(
            tourismRepository: RoutePlaybackTourismStub(),
            logReelRepository: dependencies, logInteractionRepository: dependencies,
            logMediaRepository: dependencies, profileRepository: dependencies,
            playbackService: dependencies
        )
    }
}

private struct RoutePlaybackTourismStub: TourismRepository {
    func fetchPortraitImage(tourismID: Int64) async throws -> TourismPortraitImage? { fatalError("Unused") }
    func fetchTourisms(category: TourismCategory, cursor: String?, size: Int) async throws -> TourismPage { fatalError("Unused") }
    func fetchTourismDetail(tourismID: Int64) async throws -> TourismDetail { fatalError("Unused") }
}

@MainActor
private final class RoutePlaybackDependencies: LogReelRepository, LogInteractionRepository, LogMediaRepository, ProfileRepository, VideoPlaybackService {
    let player = AVPlayer()
    let isMuted = true
    func fetchReels(cursor: String?, size: Int) async throws -> LogReelPage { fatalError("Unused") }
    func fetchSavedLogs(cursor: String?, size: Int) async throws -> LogReelPage { fatalError("Unused") }
    func setLike(logID: Int64, isLiked: Bool) async throws -> LogLikeInteractionResult { fatalError("Unused") }
    func setSaved(logID: Int64, isSaved: Bool) async throws -> LogSaveInteractionResult { fatalError("Unused") }
    func fetchThumbnailData(logID: Int64, targetSize: MaplogImageTargetSize) async throws -> Data { fatalError("Unused") }
    var downloadCount = 0
    var cancelsFirstDownload = false
    var delaysFirstDownload = false
    var firstDownloadContinuation: CheckedContinuation<URL, Error>?
    func fetchPlaybackFileURL(logID: Int64) async throws -> URL {
        downloadCount += 1
        if cancelsFirstDownload && downloadCount == 1 { throw CancellationError() }
        if delaysFirstDownload && downloadCount == 1 {
            return try await withCheckedThrowingContinuation { firstDownloadContinuation = $0 }
        }
        return URL(fileURLWithPath: "/tmp/route-playback-fixture.mov")
    }
    func fetchRoutePointThumbnailData(from url: URL, targetSize: MaplogImageTargetSize) async throws -> Data { fatalError("Unused") }
    func fetchMyProfile() async throws -> MyProfile { fatalError("Unused") }
    func fetchPublicProfile(nickname: String) async throws -> PublicProfile { fatalError("Unused") }
    func fetchMyLogs(cursor: String?, size: Int) async throws -> ProfileLogPage { fatalError("Unused") }
    func fetchPublicProfileLogs(nickname: String, cursor: String?, size: Int) async throws -> ProfileLogPage { fatalError("Unused") }
    func updateMyProfile(_ update: ProfileUpdate) async throws -> MyProfile { fatalError("Unused") }
    func deleteMyProfile() async throws { fatalError("Unused") }
    func fetchImageData(from url: URL, cacheKey: String, targetSize: MaplogImageTargetSize) async throws -> Data { fatalError("Unused") }
    var loadCount = 0
    func loadVideo(at url: URL) { loadCount += 1; player.replaceCurrentItem(with: AVPlayerItem(url: url)) }
    func loadVideoSequence(from urls: [URL]) async throws { fatalError("Unused") }
    func loadVideoComposition(from clips: [CaptureDraftClip], configuration: VideoCompositionConfiguration) async throws { fatalError("Unused") }
    func seek(to seconds: TimeInterval) { fatalError("Unused") }
    var seekCompletions: [@Sendable (Bool) -> Void] = []
    var seekTimes: [TimeInterval] = []
    func seek(to seconds: TimeInterval, completion: @escaping @Sendable (Bool) -> Void) { seekTimes.append(seconds); seekCompletions.append(completion) }
    func toggleMute() { fatalError("Unused") }
    var playCount = 0
    func play() { playCount += 1 }
    func pause() {}
    func stop() { player.replaceCurrentItem(with: nil) }
    func observeProgress(_ handler: @escaping (Double) -> Void) {}
}
