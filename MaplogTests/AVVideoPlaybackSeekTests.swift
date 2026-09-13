import AVFoundation
import XCTest
@testable import Maplog

@MainActor
final class AVVideoPlaybackSeekTests: XCTestCase {
    func testFreshLoadSeeksToRouteTimeThenAdvances() async throws {
        let url = try await makeSilentVideo()
        defer { try? FileManager.default.removeItem(at: url) }
        let service = AVVideoPlaybackService()
        defer { service.stop() }
        service.loadVideo(at: url)
        let completed = expectation(description: "Seek completes before play")
        service.seek(to: 2) { finished in
            XCTAssertTrue(finished)
            completed.fulfill()
        }
        await fulfillment(of: [completed], timeout: 8)
        XCTAssertEqual(service.player.currentTime().seconds, 2, accuracy: 0.15)
        service.play()
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertGreaterThan(service.player.currentTime().seconds, 2.15)
        service.pause()
        let next = expectation(description: "Paused player seeks to next route point")
        service.seek(to: 4) { finished in
            XCTAssertTrue(finished)
            next.fulfill()
        }
        await fulfillment(of: [next], timeout: 8)
        XCTAssertEqual(service.player.currentTime().seconds, 4, accuracy: 0.15)
        service.play()
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertGreaterThan(service.player.currentTime().seconds, 4.15)
    }

    func testStoppingPreviousScreenDoesNotStopIndependentDetailPlayback() async throws {
        let url = try await makeSilentVideo()
        defer { try? FileManager.default.removeItem(at: url) }
        let previous = AVVideoPlaybackService()
        let detail = AVVideoPlaybackService()
        defer { previous.stop(); detail.stop() }
        XCTAssertFalse(previous.player === detail.player)
        previous.loadVideo(at: url)
        detail.loadVideo(at: url)
        let ready = expectation(description: "Detail is ready")
        detail.seek(to: 1) { finished in
            XCTAssertTrue(finished)
            ready.fulfill()
        }
        await fulfillment(of: [ready], timeout: 8)
        detail.play()
        previous.stop()
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertNotNil(detail.player.currentItem)
        XCTAssertGreaterThan(detail.player.currentTime().seconds, 1.15)
    }

    func testURLVideoLoopKeepsTheSamePlayerItem() async throws {
        let url = try await makeSilentVideo(frameCount: 6)
        defer { try? FileManager.default.removeItem(at: url) }

        let service = AVVideoPlaybackService()
        defer { service.stop() }

        service.loadVideo(at: url)
        let initialItem = try XCTUnwrap(service.player.currentItem)
        service.play()

        try await Task.sleep(for: .seconds(1.2))

        XCTAssertTrue(service.player.currentItem === initialItem)
        XCTAssertGreaterThan(service.player.currentTime().seconds, 0.05)
    }

    private func makeSilentVideo(
        frameCount: Int = 90
    ) async throws -> URL {
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

        for frame in 0..<frameCount {
            var attempts = 0
            // 시뮬레이터의 첫 인코더 초기화는 재사용보다 오래 걸릴 수 있습니다.
            while !input.isReadyForMoreMediaData && writer.status == .writing && attempts < 1_000 {
                try await Task.sleep(nanoseconds: 10_000_000)
                attempts += 1
            }
            guard input.isReadyForMoreMediaData else {
                writer.cancelWriting()
                try? FileManager.default.removeItem(at: url)
                throw NSError(domain: "PlaybackTestFixture", code: 1)
            }
            XCTAssertTrue(adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 15)))
        }
        input.markAsFinished()
        writer.endSession(
            atSourceTime: CMTime(
                value: Int64(frameCount),
                timescale: 15
            )
        )
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed, String(describing: writer.error))
        return url
    }
}
