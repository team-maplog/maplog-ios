import AVFoundation
import Foundation
import XCTest
@testable import Maplog

@MainActor
final class ClipEditorViewModelTests: XCTestCase {
    func testUndoAfterAddingAndTypingTextRemovesTheNewOverlay() async throws {
        let viewModel = await makePreparedViewModel()

        viewModel.addTextOverlayToCurrentClip()
        let overlayID = try XCTUnwrap(viewModel.selectedTextOverlay?.id)

        viewModel.beginTextEditing(id: overlayID)
        viewModel.updateTextOverlayText(id: overlayID, text: "성수에서 만난 오후")
        viewModel.endTextEditing(id: overlayID)
        viewModel.undoLastTextOverlayEdit()

        XCTAssertTrue(viewModel.textOverlays.isEmpty)
        XCTAssertFalse(viewModel.canUndoTextOverlayEdit)
    }

    func testUndoRestoresThePreviousTextStyle() async {
        let viewModel = await makePreparedViewModel()

        viewModel.addTextOverlayToCurrentClip()
        viewModel.updateSelectedTextColor(.coral)

        XCTAssertEqual(viewModel.selectedTextOverlay?.style.color, .coral)

        viewModel.undoLastTextOverlayEdit()

        XCTAssertEqual(viewModel.selectedTextOverlay?.style.color, .white)
    }

    func testUndoRestoresExistingTextAfterKeyboardEditing() async throws {
        let viewModel = await makePreparedViewModel()
        viewModel.addTextOverlayToCurrentClip()
        let id = try XCTUnwrap(viewModel.selectedTextOverlayID)
        viewModel.beginTextEditing(id: id)
        viewModel.updateTextOverlayText(id: id, text: "원래 글자")
        viewModel.endTextEditing(id: id)
        viewModel.beginTextEditing(id: id)
        viewModel.updateTextOverlayText(id: id, text: "수정한 글자")
        viewModel.endTextEditing(id: id)
        viewModel.undoLastTextOverlayEdit()
        XCTAssertEqual(viewModel.selectedTextOverlay?.text, "원래 글자")
    }

    func testUndoRestoresDraggedTextPosition() async throws {
        let viewModel = await makePreparedViewModel()
        viewModel.addTextOverlayToCurrentClip()
        let id = try XCTUnwrap(viewModel.selectedTextOverlayID)
        let original = viewModel.selectedTextOverlay?.position
        viewModel.updateTextOverlayPosition(id: id, position: ClipOverlayPosition(x: 0.2, y: 0.7))
        viewModel.undoLastTextOverlayEdit()
        XCTAssertEqual(viewModel.selectedTextOverlay?.position, original)
    }

    func testCropIsUsedByBothPreviewAndExport() async throws {
        let playback = ClipEditorVideoPlaybackServiceStub()
        let exporter = ClipEditorVideoExportServiceStub()
        let viewModel = await makePreparedViewModel(layout: .splitTwo, playback: playback, exporter: exporter)
        let clipID = try XCTUnwrap(viewModel.timelineItems.first?.id)
        let crop = VideoClipCrop(horizontalPosition: 0.2, verticalPosition: 0.8, zoom: 2, quarterTurns: 1)
        await viewModel.updateCrop(crop, for: clipID)
        XCTAssertEqual(playback.lastConfiguration?.clipCrops[clipID], crop)
        XCTAssertFalse(viewModel.isUpdatingCrop)
        await viewModel.exportVideo()
        let exportedRequest = await exporter.lastRequest
        XCTAssertEqual(exportedRequest?.compositionConfiguration.clipCrops[clipID], crop)
    }

    func testSingleClipRotationReachesPreviewAndExport() async throws {
        let playback = ClipEditorVideoPlaybackServiceStub()
        let exporter = ClipEditorVideoExportServiceStub()
        let viewModel = await makePreparedViewModel(playback: playback, exporter: exporter)
        let id = try XCTUnwrap(viewModel.timelineItems.first?.id)
        await viewModel.selectCropClip(id)
        XCTAssertEqual(viewModel.selectedCropClipID, id)
        XCTAssertFalse(viewModel.isPreviewPlaying)
        await viewModel.updateCrop(VideoClipCrop(quarterTurns: 1), for: id)
        XCTAssertEqual(playback.lastConfiguration?.clipCrops[id]?.quarterTurns, 1)
        await viewModel.exportVideo()
        let request = await exporter.lastRequest
        XCTAssertEqual(request?.compositionConfiguration.clipCrops[id]?.quarterTurns, 1)
        viewModel.togglePreviewPlayback()
        XCTAssertNil(viewModel.selectedCropClipID)
    }

    func testFailedCropRestoresPreviousConfiguration() async throws {
        let playback = ClipEditorVideoPlaybackServiceStub()
        let viewModel = await makePreparedViewModel(layout: .splitTwo, playback: playback)
        let clipID = try XCTUnwrap(viewModel.timelineItems.first?.id)
        playback.shouldFailNextComposition = true
        await viewModel.updateCrop(VideoClipCrop(zoom: 2), for: clipID)
        XCTAssertEqual(viewModel.crop(for: clipID), VideoClipCrop())
        XCTAssertEqual(playback.lastConfiguration?.clipCrops[clipID], VideoClipCrop())
        XCTAssertNotNil(viewModel.cropError)
        XCTAssertFalse(viewModel.isUpdatingCrop)
    }

    private func makePreparedViewModel(
        layout: VideoCompositionLayout = .single,
        playback: ClipEditorVideoPlaybackServiceStub? = nil,
        exporter: ClipEditorVideoExportServiceStub = ClipEditorVideoExportServiceStub()
    ) async -> ClipEditorViewModel {
        let viewModel = ClipEditorViewModel(
            input: ClipEditorInput(clips: (0..<layout.requiredClipCount).map { _ in
                CaptureDraftClip(
                    id: UUID(),
                    mediaType: .video,
                    fileURL: URL(fileURLWithPath: "/tmp/editor-test.mov"),
                    capturedAt: .now,
                    duration: 3,
                    location: nil,
                    timestampStyle: .none
                )
            }, compositionConfiguration: VideoCompositionConfiguration(layout: layout)),
            videoThumbnailService: ClipEditorVideoThumbnailServiceStub(),
            videoPlaybackService: playback ?? ClipEditorVideoPlaybackServiceStub(),
            videoExportService: exporter
        )

        await viewModel.prepare()
        return viewModel
    }
}

@MainActor
private final class ClipEditorVideoPlaybackServiceStub: VideoPlaybackService {
    let player = AVPlayer()
    var isMuted = false
    var lastConfiguration: VideoCompositionConfiguration?
    var shouldFailNextComposition = false

    func loadVideo(at url: URL) {}
    func loadVideoSequence(from urls: [URL]) async throws {}

    func loadVideoComposition(
        from clips: [CaptureDraftClip],
        configuration: VideoCompositionConfiguration
    ) async throws {
        if shouldFailNextComposition {
            shouldFailNextComposition = false
            throw VideoPlaybackServiceError.sourceVideoUnavailable
        }
        lastConfiguration = configuration
    }

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

private struct ClipEditorVideoThumbnailServiceStub: VideoThumbnailService {
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

private actor ClipEditorVideoExportServiceStub: VideoExportService {
    var lastRequest: VideoExportRequest?
    func export(request: VideoExportRequest) async throws -> VideoExportResult {
        lastRequest = request
        return VideoExportResult(
            fileURL: URL(fileURLWithPath: "/tmp/editor-export.mov"),
            duration: 3
        )
    }
}
