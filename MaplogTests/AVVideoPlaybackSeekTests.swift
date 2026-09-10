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

        for frame in 0..<90 {
            var attempts = 0
            while !input.isReadyForMoreMediaData && attempts < 200 {
                try await Task.sleep(nanoseconds: 10_000_000)
                attempts += 1
            }
            XCTAssertTrue(input.isReadyForMoreMediaData)
            XCTAssertTrue(adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 15)))
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(seconds: 6, preferredTimescale: 15))
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed, String(describing: writer.error))
        return url
    }
}
