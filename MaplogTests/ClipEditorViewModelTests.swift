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

    private func makePreparedViewModel() async -> ClipEditorViewModel {
        let viewModel = ClipEditorViewModel(
            input: ClipEditorInput(clips: [
                CaptureDraftClip(
                    id: UUID(),
                    mediaType: .video,
                    fileURL: URL(fileURLWithPath: "/tmp/editor-test.mov"),
                    capturedAt: .now,
                    duration: 3,
                    location: nil,
                    timestampStyle: .none
                )
            ]),
            videoThumbnailService: ClipEditorVideoThumbnailServiceStub(),
            videoPlaybackService: ClipEditorVideoPlaybackServiceStub(),
            videoExportService: ClipEditorVideoExportServiceStub()
        )

        await viewModel.prepare()
        return viewModel
    }
}

@MainActor
private final class ClipEditorVideoPlaybackServiceStub: VideoPlaybackService {
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

private struct ClipEditorVideoExportServiceStub: VideoExportService {
    func export(request: VideoExportRequest) async throws -> VideoExportResult {
        VideoExportResult(
            fileURL: URL(fileURLWithPath: "/tmp/editor-export.mov"),
            duration: 3
        )
    }
}
