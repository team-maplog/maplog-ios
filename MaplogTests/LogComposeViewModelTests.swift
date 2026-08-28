import AVFoundation
import Foundation
import XCTest
@testable import Maplog

@MainActor
final class LogComposeViewModelTests: XCTestCase {
    func testPrepareResolvesLocationAndAllowsPublicationWithEmptyCaption() async {
        let locationRepository = LogLocationRepositoryStub()
        let viewModel = LogComposeViewModel(
            input: makeInput(),
            videoPlaybackService: VideoPlaybackServiceStub(),
            videoThumbnailService: VideoThumbnailServiceStub(),
            logLocationRepository: locationRepository,
            logPublishingRepository: LogPublishingRepositoryStub(),
            photoLibraryVideoSaveService: PhotoLibraryVideoSaveServiceStub()
        )

        XCTAssertNil(viewModel.makePublishDraft())

        await viewModel.prepare()

        XCTAssertEqual(locationRepository.requestedCoordinates.count, 1)
        XCTAssertEqual(
            viewModel.clipLocations.first?.location?.address,
            "서울 성동구 성수이로 7길"
        )
        XCTAssertEqual(viewModel.makePublishDraft()?.caption, "")
        XCTAssertEqual(viewModel.makePublishDraft()?.tags, [])
        XCTAssertTrue(viewModel.canPublishToMaplog)
    }

    func testCaptionHashtagsBecomeUniqueTagsForPublication() async {
        let viewModel = LogComposeViewModel(
            input: makeInput(),
            videoPlaybackService: VideoPlaybackServiceStub(),
            videoThumbnailService: VideoThumbnailServiceStub(),
            logLocationRepository: LogLocationRepositoryStub(),
            logPublishingRepository: LogPublishingRepositoryStub(),
            photoLibraryVideoSaveService: PhotoLibraryVideoSaveServiceStub()
        )
        viewModel.caption = "성수에서 보낸 주말 #성수카페 #한강산책 #성수카페"

        await viewModel.prepare()

        let draft = viewModel.makePublishDraft()

        XCTAssertEqual(viewModel.hashtags, ["성수카페", "한강산책"])
        XCTAssertEqual(draft?.tags, ["성수카페", "한강산책"])
    }

    func testMoreThanTenHashtagsBlocksMaplogPublication() async {
        let viewModel = LogComposeViewModel(
            input: makeInput(),
            videoPlaybackService: VideoPlaybackServiceStub(),
            videoThumbnailService: VideoThumbnailServiceStub(),
            logLocationRepository: LogLocationRepositoryStub(),
            logPublishingRepository: LogPublishingRepositoryStub(),
            photoLibraryVideoSaveService: PhotoLibraryVideoSaveServiceStub()
        )
        viewModel.caption = (1...11)
            .map { "#태그\($0)" }
            .joined(separator: " ")

        await viewModel.prepare()

        XCTAssertEqual(viewModel.hashtags.count, 11)
        XCTAssertEqual(
            viewModel.hashtagValidationMessage,
            "해시태그는 최대 10개까지 입력할 수 있어요."
        )
        XCTAssertFalse(viewModel.canPublishToMaplog)
    }

    func testLocationResolutionFailureBlocksPublicationUntilRetrySucceeds() async {
        let locationRepository = LogLocationRepositoryStub()
        locationRepository.error = APIError.server(
            statusCode: 400,
            response: APIErrorResponse(
                successFlag: false,
                code: "LOCATION-002",
                message: "주소를 찾을 수 없습니다.",
                data: nil
            )
        )
        let viewModel = LogComposeViewModel(
            input: makeInput(),
            videoPlaybackService: VideoPlaybackServiceStub(),
            videoThumbnailService: VideoThumbnailServiceStub(),
            logLocationRepository: locationRepository,
            logPublishingRepository: LogPublishingRepositoryStub(),
            photoLibraryVideoSaveService: PhotoLibraryVideoSaveServiceStub()
        )

        await viewModel.prepare()

        XCTAssertFalse(viewModel.canPublishToMaplog)
        XCTAssertTrue(viewModel.canRetryLocationResolution)
        XCTAssertEqual(
            viewModel.maplogPublicationBlockMessage,
            "현재 좌표의 주소를 찾지 못했어요. 다시 조회해 주세요."
        )

        locationRepository.error = nil
        await viewModel.retryLocationResolution()

        XCTAssertTrue(viewModel.canPublishToMaplog)
        XCTAssertNil(viewModel.locationResolutionError)
        XCTAssertEqual(locationRepository.requestedCoordinates.count, 2)
    }

    func testSplitLayoutPublishesSequentialClipTimeRanges() async throws {
        let viewModel = LogComposeViewModel(
            input: makeInput(
                clipDurations: [3, 3, 3],
                finalVideoDuration: 3,
                compositionConfiguration: .init(layout: .splitThree)
            ),
            videoPlaybackService: VideoPlaybackServiceStub(),
            videoThumbnailService: VideoThumbnailServiceStub(),
            logLocationRepository: LogLocationRepositoryStub(),
            logPublishingRepository: LogPublishingRepositoryStub(),
            photoLibraryVideoSaveService: PhotoLibraryVideoSaveServiceStub()
        )

        await viewModel.prepare()

        let draft = try XCTUnwrap(viewModel.makePublishDraft())

        XCTAssertEqual(
            draft.clips.map(\.startTimeMillis),
            [0, 1_000, 2_000]
        )
        XCTAssertEqual(
            draft.clips.map(\.endTimeMillis),
            [1_000, 2_000, 3_000]
        )
    }

    func testMaplogPublicationCreatesOnlyMaplogCompletion() async {
        let viewModel = LogComposeViewModel(
            input: makeInput(),
            videoPlaybackService: VideoPlaybackServiceStub(),
            videoThumbnailService: VideoThumbnailServiceStub(),
            logLocationRepository: LogLocationRepositoryStub(),
            logPublishingRepository: LogPublishingRepositoryStub(),
            photoLibraryVideoSaveService: PhotoLibraryVideoSaveServiceStub()
        )

        viewModel.caption = "Maplog에 발행하는 영상입니다."
        await viewModel.prepare()
        await viewModel.publishToMaplog()

        XCTAssertEqual(viewModel.publicationCompletion?.publishedLog?.logID, 1)
        XCTAssertEqual(viewModel.publicationCompletion?.savedToPhotoLibrary, false)
    }

    func testPhotoLibrarySaveCreatesOnlySaveCompletion() async {
        let viewModel = LogComposeViewModel(
            input: makeInput(),
            videoPlaybackService: VideoPlaybackServiceStub(),
            videoThumbnailService: VideoThumbnailServiceStub(),
            logLocationRepository: LogLocationRepositoryStub(),
            logPublishingRepository: LogPublishingRepositoryStub(),
            photoLibraryVideoSaveService: PhotoLibraryVideoSaveServiceStub()
        )

        await viewModel.saveToPhotoLibrary()

        XCTAssertNil(viewModel.publicationCompletion?.publishedLog)
        XCTAssertEqual(viewModel.publicationCompletion?.savedToPhotoLibrary, true)
    }

    func testHashtagLongerThanThirtyCharactersIsRejected() {
        let longTag = String(repeating: "가", count: 31)
        let parsed = LogCustomTagParser.parse(caption: "#\(longTag)")

        XCTAssertEqual(parsed.tags, [])
        XCTAssertEqual(
            parsed.validationMessage,
            "해시태그는 30자 이내로 입력해 주세요."
        )
    }

    func testHashtagRangesIncludeOnlyValidTags() {
        let caption = "성수 #카페 산책 #한강_야경! #"
        let ranges = LogCustomTagParser.hashtagRanges(in: caption)
        let source = caption as NSString

        XCTAssertEqual(
            ranges.map { source.substring(with: $0) },
            ["#카페", "#한강_야경"]
        )
    }

    private func makeInput(
        clipDurations: [TimeInterval] = [3],
        finalVideoDuration: TimeInterval = 3,
        compositionConfiguration: VideoCompositionConfiguration = .init()
    ) -> LogComposeInput {
        let clips = clipDurations.enumerated().map { index, duration in
            CaptureDraftClip(
                id: UUID(),
                mediaType: .video,
                fileURL: URL(
                    fileURLWithPath: "/tmp/source-\(index).mov"
                ),
                capturedAt: .now,
                duration: duration,
                location: CaptureLocation(
                    latitude: 37.544 + Double(index) * 0.001,
                    longitude: 127.057,
                    placeName: "성수동"
                ),
                timestampStyle: .none
            )
        }

        return LogComposeInput(
            video: VideoExportResult(
                fileURL: URL(fileURLWithPath: "/tmp/result.mov"),
                duration: finalVideoDuration
            ),
            clips: clips,
            compositionConfiguration: compositionConfiguration
        )
    }
}

private final class LogLocationRepositoryStub: LogLocationRepository {
    private(set) var requestedCoordinates: [(Double, Double)] = []
    var error: Error?

    func resolveLocation(
        latitude: Double,
        longitude: Double
    ) async throws -> ResolvedLogLocation {
        requestedCoordinates.append((latitude, longitude))

        if let error {
            throw error
        }

        return ResolvedLogLocation(
            latitude: latitude,
            longitude: longitude,
            name: "성수동",
            address: "서울 성동구 성수이로 7길"
        )
    }
}

@MainActor
private final class VideoPlaybackServiceStub: VideoPlaybackService {
    let player = AVPlayer()
    var isMuted = false

    func loadVideo(at url: URL) {}

    func loadVideoSequence(from urls: [URL]) async throws {}

    func loadVideoComposition(
        from clips: [CaptureDraftClip],
        configuration: VideoCompositionConfiguration
    ) async throws {}

    func seek(to seconds: TimeInterval) {}

    func seek(
        to seconds: TimeInterval,
        completion: @escaping @Sendable (Bool) -> Void
    ) {
        completion(true)
    }

    func toggleMute() {
        isMuted.toggle()
    }

    func play() {}
    func pause() {}
    func stop() {}
    func observeProgress(_ handler: @escaping (Double) -> Void) {}
}

private struct VideoThumbnailServiceStub: VideoThumbnailService {
    func makeThumbnailData(for videoURL: URL) async throws -> Data {
        Data()
    }

    func makeThumbnailData(
        for videoURL: URL,
        at time: TimeInterval
    ) async throws -> Data {
        Data()
    }
}

private struct LogPublishingRepositoryStub: LogPublishingRepository {
    func publish(draft: LogPublishDraft) async throws -> LogPublishResult {
        LogPublishResult(logID: 1)
    }
}

private struct PhotoLibraryVideoSaveServiceStub: PhotoLibraryVideoSaving {
    func saveVideo(at fileURL: URL) async throws {}
}
