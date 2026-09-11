import AVFoundation
import XCTest
@testable import Maplog

final class VideoExportSilentClipTests: XCTestCase {
    func testSilentClipExportsWithoutRequiringMuteInSequentialAndSplitLayouts() async throws {
        let sourceURL = try await makeSilentVideo()
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        let exporter = AVVideoExportService(textOverlayRenderer: VideoTextOverlayRenderer())

        for layout in [VideoCompositionLayout.single, .splitTwo, .splitThree] {
            let clips = (0..<layout.requiredClipCount).map { _ in
                CaptureDraftClip(
                    id: UUID(), mediaType: .video, fileURL: sourceURL,
                    capturedAt: .now, duration: 1, location: nil, timestampStyle: .none
                )
            }
            var configuration = VideoCompositionConfiguration(layout: layout)
            configuration.clipCrops[clips[0].id] = VideoClipCrop(verticalPosition: 0, zoom: 2, quarterTurns: 1)
            let result = try await exporter.export(request: VideoExportRequest(
                clips: clips, textOverlays: [], isMuted: false, compositionConfiguration: configuration
            ))
            defer { try? FileManager.default.removeItem(at: result.fileURL) }
            let asset = AVURLAsset(url: result.fileURL)
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let duration = try await asset.load(.duration)
            XCTAssertEqual(videoTracks.count, 1, "\(layout)")
            XCTAssertEqual(duration.seconds, 1, accuracy: 0.1)
        }
    }

    /// 저장소에 샘플 미디어를 추가하지 않고 실제 무음 원본을 만들어 export 경로를 검증한다.
    private func makeSilentVideo() async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 64,
            AVVideoHeightKey: 128
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: 64,
            kCVPixelBufferHeightKey as String: 128
        ])
        writer.add(input)
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)

        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 64, 128, kCVPixelFormatType_32ARGB, nil, &buffer)
        let pixelBuffer = try XCTUnwrap(buffer)
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
            memset(baseAddress, 128, CVPixelBufferGetDataSize(pixelBuffer))
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        for frame in 0..<15 {
            var attempts = 0
            while !input.isReadyForMoreMediaData && attempts < 1000 {
                try await Task.sleep(nanoseconds: 10_000_000)
                attempts += 1
            }
            guard input.isReadyForMoreMediaData else {
                XCTFail("샘플 영상 인코더가 준비되지 않았습니다: \(String(describing: writer.error))")
                writer.cancelWriting()
                throw CocoaError(.fileWriteUnknown)
            }
            XCTAssertTrue(adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 15)))
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(seconds: 1, preferredTimescale: 15))
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed, String(describing: writer.error))
        return url
    }
}
