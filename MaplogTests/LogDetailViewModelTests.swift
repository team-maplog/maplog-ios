import AVFoundation
import Foundation
import XCTest
@testable import Maplog

@MainActor
final class LogDetailViewModelTests: XCTestCase {
    func testLoadAndSaveCaptionUsesTrimmedValue() async {
        let repository = LogDetailRepositoryStub(detail: makeDetail())
        let mediaRepository = LogMediaRepositoryStub()
        let playbackService = VideoPlaybackServiceStub()
        let viewModel = LogDetailViewModel(
            logID: 501,
            logDetailRepository: repository,
            logMediaRepository: mediaRepository,
            playbackService: playbackService
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(viewModel.state, .content)
        XCTAssertEqual(viewModel.detail?.caption, "기존 캡션")
        XCTAssertEqual(playbackService.loadedURL?.path, "/tmp/log.mov")
        XCTAssertEqual(playbackService.playCallCount, 1)
        XCTAssertEqual(viewModel.thumbnailData, Data())

        viewModel.captionDraft = "  수정한 캡션  "

        let didSave = await viewModel.saveCaption()

        XCTAssertTrue(didSave)
        XCTAssertEqual(repository.updatedCaption, "수정한 캡션")
        XCTAssertEqual(repository.updatedTags, [])
        XCTAssertEqual(viewModel.detail?.caption, "수정한 캡션")
    }

    func testReturningToLoadedDetailPreparesStoppedVideoAgain() async {
        let playback = VideoPlaybackServiceStub()
        let model = LogDetailViewModel(
            logID: 501,
            logDetailRepository: LogDetailRepositoryStub(detail: makeDetail()),
            logMediaRepository: LogMediaRepositoryStub(),
            playbackService: playback
        )
        await model.loadIfNeeded()
        XCTAssertEqual(playback.loadCallCount, 1)
        await model.loadIfNeeded()
        XCTAssertEqual(playback.loadCallCount, 1)
        model.stopPlayback()
        await model.loadIfNeeded()
        XCTAssertEqual(playback.loadCallCount, 2)
        XCTAssertEqual(playback.playCallCount, 2)
        XCTAssertEqual(model.state, .content)
    }

    func testCommentNotificationDoesNotAutoplayButAllowsManualPlayback() async {
        let playback = VideoPlaybackServiceStub()
        let model = LogDetailViewModel(
            logID: 501,
            logDetailRepository: LogDetailRepositoryStub(detail: makeDetail()),
            logMediaRepository: LogMediaRepositoryStub(),
            playbackService: playback,
            automaticallyPlays: false
        )
        await model.loadIfNeeded()
        XCTAssertEqual(model.state, .content)
        XCTAssertEqual(playback.playCallCount, 0)
        XCTAssertFalse(model.isPlaying)
        model.togglePlayback()
        XCTAssertEqual(playback.playCallCount, 1)
        XCTAssertTrue(model.isPlaying)
    }

    func testSaveCaptionRejectsWhitespaceOnlyInput() async {
        let repository = LogDetailRepositoryStub(detail: makeDetail())
        let viewModel = LogDetailViewModel(
            logID: 501,
            logDetailRepository: repository,
            logMediaRepository: LogMediaRepositoryStub(),
            playbackService: VideoPlaybackServiceStub()
        )

        await viewModel.loadIfNeeded()
        viewModel.captionDraft = " \n "

        let didSave = await viewModel.saveCaption()

        XCTAssertFalse(didSave)
        XCTAssertEqual(viewModel.captionMessage, "캡션을 입력해 주세요.")
        XCTAssertNil(repository.updatedCaption)
    }

    func testTogglePlaybackUpdatesScreenState() async {
        let playbackService = VideoPlaybackServiceStub()
        let viewModel = LogDetailViewModel(
            logID: 501,
            logDetailRepository: LogDetailRepositoryStub(detail: makeDetail()),
            logMediaRepository: LogMediaRepositoryStub(),
            playbackService: playbackService
        )

        await viewModel.loadIfNeeded()
        viewModel.togglePlayback()

        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertEqual(playbackService.pauseCallCount, 1)

        viewModel.togglePlayback()

        XCTAssertTrue(viewModel.isPlaying)
        XCTAssertEqual(playbackService.playCallCount, 2)
    }

    func testLoadFetchesThumbnailForEachPlace() async {
        let thumbnailURL = URL(string: "https://example.com/clip-701.jpg")!
        let clip = LogReelClip(
            id: 701,
            displayOrder: 0,
            startTimeMillis: 0,
            endTimeMillis: 3_000,
            location: LogReelLocation(
                name: "서울숲",
                address: "서울 성동구 뚝섬로 273",
                latitude: 37.544,
                longitude: 127.037
            ),
            thumbnailURL: thumbnailURL
        )
        let mediaRepository = LogMediaRepositoryStub()
        let viewModel = LogDetailViewModel(
            logID: 501,
            logDetailRepository: LogDetailRepositoryStub(
                detail: makeDetail(clips: [clip])
            ),
            logMediaRepository: mediaRepository,
            playbackService: VideoPlaybackServiceStub()
        )

        await viewModel.loadIfNeeded()

        XCTAssertEqual(
            mediaRepository.requestedRoutePointThumbnailURLs,
            [thumbnailURL]
        )
        XCTAssertEqual(viewModel.clipThumbnailDataByID[clip.id], Data())
        XCTAssertFalse(viewModel.loadingClipThumbnailIDs.contains(clip.id))
    }

    func testSaveCaptionLocalizesServerValidationAndClearsItAfterEditing() async {
        let repository = LogDetailRepositoryStub(
            detail: makeDetail(),
            updateError: APIError.server(
                statusCode: 400,
                response: APIErrorResponse(
                    successFlag: false,
                    code: "COMMON-014",
                    message: "입력값이 올바르지 않습니다.",
                    data: [
                        FieldValidationError(
                            field: "caption",
                            rejectedValue: nil,
                            message: "Caption must not be blank when provided."
                        )
                    ]
                )
            )
        )
        let viewModel = LogDetailViewModel(
            logID: 501,
            logDetailRepository: repository,
            logMediaRepository: LogMediaRepositoryStub(),
            playbackService: VideoPlaybackServiceStub()
        )

        await viewModel.loadIfNeeded()
        viewModel.captionDraft = "수정한 캡션"

        let didSave = await viewModel.saveCaption()

        XCTAssertFalse(didSave)
        XCTAssertEqual(viewModel.captionMessage, "내용을 확인한 뒤 다시 저장해 주세요.")
        XCTAssertEqual(viewModel.captionDraft, "수정한 캡션")
        XCTAssertNil(viewModel.captionFormMessage)

        viewModel.updateCaptionDraft("다시 수정한 캡션")

        XCTAssertNil(viewModel.captionMessage)
        XCTAssertNil(viewModel.captionFormMessage)
    }

    func testUnrecognizedValidationFieldStillShowsUserFacingMessage() {
        let presentation = LogDetailErrorPolicy.captionPresentation(
            for: APIError.server(
                statusCode: 400,
                response: APIErrorResponse(
                    successFlag: false,
                    code: "COMMON-014",
                    message: "Invalid request payload",
                    data: [FieldValidationError(
                        field: "tags",
                        rejectedValue: nil,
                        message: "Unsupported tag value"
                    )]
                )
            )
        )

        XCTAssertEqual(presentation.formMessage, "수정한 내용을 확인한 뒤 다시 저장해 주세요.")
        XCTAssertNil(presentation.captionMessage)
        XCTAssertEqual(presentation.recoveryAction, .none)
    }

    func testUnavailableLogRequestsSourceListRemoval() async {
        let repository = LogDetailRepositoryStub(
            detail: makeDetail(),
            fetchError: APIError.server(
                statusCode: 404,
                response: APIErrorResponse(
                    successFlag: false,
                    code: "LOG-001",
                    message: "로그를 찾을 수 없습니다.",
                    data: nil
                )
            )
        )
        let viewModel = LogDetailViewModel(
            logID: 501,
            logDetailRepository: repository,
            logMediaRepository: LogMediaRepositoryStub(),
            playbackService: VideoPlaybackServiceStub()
        )

        await viewModel.loadIfNeeded()

        XCTAssertTrue(viewModel.shouldRemoveFromSourceList)
        XCTAssertEqual(
            viewModel.state,
            .failed(
                ErrorPresentation(
                    message: "이 맵로그를 더 이상 볼 수 없어요.",
                    recoveryAction: .none
                )
            )
        )
    }

    func testSavingLocationPreservesOtherClipsAndVideoTiming() async {
        let original = LogReelLocation(name: "서울숲", address: "서울 성동구", latitude: 37.54, longitude: 127.04)
        let first = LogReelClip(id: 701, displayOrder: 0, startTimeMillis: 0, endTimeMillis: 4000, location: original, thumbnailURL: nil)
        let second = LogReelClip(id: 702, displayOrder: 1, startTimeMillis: 4000, endTimeMillis: 8000, location: original, thumbnailURL: nil)
        let repository = LogDetailRepositoryStub(detail: makeDetail(clips: [first, second]))
        let vm = LogDetailViewModel(logID: 501, logDetailRepository: repository,
                                   logMediaRepository: LogMediaRepositoryStub(), playbackService: VideoPlaybackServiceStub())
        await vm.loadIfNeeded()
        vm.beginCaptionEditing()
        let selected = LogLocationDraft(latitude: 35.16, longitude: 129.16, name: "해운대", address: "부산 해운대구")
        vm.updateRepresentativeLocation(selected)
        vm.updateClipLocation(selected, clipID: 702)
        vm.updateClipLocation(selected, clipID: 999)
        XCTAssertEqual(vm.detail?.address, "서울 성동구", "선택만으로 저장된 상세 정보가 바뀌지 않습니다")
        let saved = await vm.saveCaption()
        XCTAssertTrue(saved)
        XCTAssertEqual(repository.updatedDraft?.clips?.map(\.logClipID), [702])
        XCTAssertEqual(vm.detail?.address, "부산 해운대구")
        XCTAssertEqual(vm.detail?.clips.first, first)
        XCTAssertEqual(vm.detail?.clips.last?.location.name, "해운대")
        XCTAssertEqual(vm.detail?.clips.last?.startTimeMillis, 4000)
        XCTAssertEqual(vm.detail?.clips.last?.endTimeMillis, 8000)
        XCTAssertEqual(vm.detail?.clips.last?.displayOrder, 1)
    }

    func testFailedLocationSaveKeepsDraftAndCancelRestoresOriginal() async {
        let repository = LogDetailRepositoryStub(detail: makeDetail(), updateError: APIError.missingAccessToken)
        let vm = LogDetailViewModel(logID: 501, logDetailRepository: repository,
                                   logMediaRepository: LogMediaRepositoryStub(), playbackService: VideoPlaybackServiceStub())
        await vm.loadIfNeeded()
        vm.beginCaptionEditing()
        vm.updateRepresentativeLocation(LogLocationDraft(latitude: 35.16, longitude: 129.16, address: "부산 해운대구"))
        let saved = await vm.saveCaption()
        XCTAssertFalse(saved)
        XCTAssertEqual(vm.addressDraft, "부산 해운대구")
        XCTAssertEqual(vm.detail?.address, "서울 성동구")
        vm.cancelCaptionEditing()
        XCTAssertEqual(vm.addressDraft, "서울 성동구")
        XCTAssertNil(vm.representativeLocationDraft)
        XCTAssertTrue(vm.clipLocationDrafts.isEmpty)
    }

    func testExistingEmptyCaptionCanUpdateOnlyLocation() async {
        let detail = makeDetail().replacingContent(caption: "", tags: [])
        let repository = LogDetailRepositoryStub(detail: detail)
        let vm = LogDetailViewModel(logID: 501, logDetailRepository: repository,
                                   logMediaRepository: LogMediaRepositoryStub(), playbackService: VideoPlaybackServiceStub())
        await vm.loadIfNeeded()
        vm.beginCaptionEditing()
        vm.updateRepresentativeLocation(LogLocationDraft(latitude: 35.16, longitude: 129.16, address: "부산 해운대구"))
        let saved = await vm.saveCaption()
        XCTAssertTrue(saved)
        XCTAssertNil(repository.updatedDraft?.caption)
        XCTAssertEqual(repository.updatedDraft?.address, "부산 해운대구")
    }

    func testServerClipLocationErrorShowsPlaceGuidance() {
        let presentation = LogDetailErrorPolicy.captionPresentation(for: APIError.server(
            statusCode: 400,
            response: APIErrorResponse(successFlag: false, code: "COMMON-014", message: "Validation failed",
                                       data: [FieldValidationError(field: "clips[0].location.address", rejectedValue: nil,
                                                                   message: "Location address is required.")])
        ))
        XCTAssertEqual(presentation.formMessage, "선택한 장소를 확인해 주세요. 지도에서 위치를 다시 선택할 수 있어요.")
        XCTAssertNil(presentation.captionMessage)
    }

    private func makeDetail(
        clips: [LogReelClip] = []
    ) -> LogDetail {
        LogDetail(
            id: 501,
            author: LogReelAuthor(
                id: UUID(),
                nickname: "채림",
                profileImageURL: nil
            ),
            caption: "기존 캡션",
            tags: [],
            address: "서울 성동구",
            thumbnailURL: nil,
            playbackURL: nil,
            publishedAt: Date(),
            viewCount: 12,
            clips: clips,
            likeCount: 0,
            commentCount: 0,
            isLikedByViewer: false,
            isSavedByViewer: false
        )
    }
}

private final class LogDetailRepositoryStub: LogDetailRepository {
    private let detail: LogDetail
    private let fetchError: Error?
    private let updateError: Error?

    private(set) var updatedDraft: LogUpdateDraft?
    private(set) var updatedCaption: String?
    private(set) var updatedTags: [LogTag]?

    init(
        detail: LogDetail,
        fetchError: Error? = nil,
        updateError: Error? = nil
    ) {
        self.detail = detail
        self.fetchError = fetchError
        self.updateError = updateError
    }

    func fetchDetail(
        logID: Int64
    ) async throws -> LogDetail {
        if let fetchError {
            throw fetchError
        }

        return detail
    }

    func updateLog(
        logID: Int64,
        draft: LogUpdateDraft
    ) async throws -> LogUpdateResult {
        if let updateError {
            throw updateError
        }

        updatedDraft = draft
        updatedCaption = draft.caption
        updatedTags = draft.tags
        return LogUpdateResult(
            caption: draft.caption ?? detail.caption,
            tags: draft.tags ?? detail.tags,
            address: draft.address ?? detail.address,
            updatedLocations: draft.clips ?? []
        )
    }

    func deleteLog(
        logID: Int64
    ) async throws {}
}

private final class LogMediaRepositoryStub: LogMediaRepository {
    private(set) var requestedRoutePointThumbnailURLs: [URL] = []

    func fetchThumbnailData(
        logID: Int64,
        targetSize: MaplogImageTargetSize
    ) async throws -> Data {
        Data()
    }

    func fetchPlaybackFileURL(
        logID: Int64
    ) async throws -> URL {
        URL(fileURLWithPath: "/tmp/log.mov")
    }

    func fetchRoutePointThumbnailData(
        from url: URL,
        targetSize: MaplogImageTargetSize
    ) async throws -> Data {
        requestedRoutePointThumbnailURLs.append(url)
        return Data()
    }
}

@MainActor
private final class VideoPlaybackServiceStub: VideoPlaybackService {
    let player = AVPlayer()
    private(set) var loadedURL: URL?
    private(set) var loadCallCount = 0
    private(set) var playCallCount = 0
    private(set) var pauseCallCount = 0
    var isMuted = false

    func loadVideo(at url: URL) {
        loadedURL = url
        loadCallCount += 1
    }

    func loadVideoSequence(
        from urls: [URL]
    ) async throws {}

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

    func play() {
        playCallCount += 1
    }
    func pause() {
        pauseCallCount += 1
    }
    func stop() {}
    func observeProgress(_ handler: @escaping (Double) -> Void) {}
}
