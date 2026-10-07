import AVFoundation
import XCTest
@testable import Maplog

@MainActor
final class AVVideoLoopIntentTests: XCTestCase {
    func testLateLoopSeekCannotResumeAfterPause() async throws {
        try await assertLateCompletionDoesNotPlay { service in service.pause() }
    }

    func testLateLoopSeekCannotResumeAfterPauseAndExplicitPlay() async throws {
        try await assertLateCompletionDoesNotPlay { service in
            service.pause()
            service.play()
        }
    }

    func testLateLoopSeekCannotResumeAfterUserSeek() async throws {
        try await assertLateCompletionDoesNotPlay { service in service.seek(to: 2) }
    }

    func testLateLoopSeekCannotResumeAfterStop() async throws {
        try await assertLateCompletionDoesNotPlay { service in service.stop() }
    }

    func testLateLoopSeekCannotResumeAfterReplacingVideo() async throws {
        try await assertLateCompletionDoesNotPlay { service in
            service.loadVideo(at: URL(fileURLWithPath: "/tmp/replacement.mov"))
            service.play()
        }
    }

    func testCurrentLoopCompletionResumesPlayback() async throws {
        let player = ControlledLoopPlayer()
        let service = AVVideoPlaybackService(player: player)
        defer { service.stop() }
        service.loadVideo(at: URL(fileURLWithPath: "/tmp/loop-fixture.mov"))
        service.play()
        try await startLoop(service: service, player: player)
        let resumed = expectation(description: "Current loop resumes")
        player.onPlay = { resumed.fulfill() }
        player.completeLoop(true)
        await fulfillment(of: [resumed], timeout: 1)
    }

    func testEndNotificationWhilePausedDoesNotStartLoopSeek() async throws {
        let player = ControlledLoopPlayer()
        let service = AVVideoPlaybackService(player: player)
        defer { service.stop() }
        service.loadVideo(at: URL(fileURLWithPath: "/tmp/loop-fixture.mov"))
        let noSeek = expectation(description: "Paused item is not restarted")
        noSeek.isInverted = true
        player.onSeek = { noSeek.fulfill() }
        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: try XCTUnwrap(service.player.currentItem))
        await fulfillment(of: [noSeek], timeout: 0.15)
    }

    private func assertLateCompletionDoesNotPlay(_ interveningAction: (AVVideoPlaybackService) -> Void) async throws {
        let player = ControlledLoopPlayer()
        let service = AVVideoPlaybackService(player: player)
        defer { service.stop() }
        service.loadVideo(at: URL(fileURLWithPath: "/tmp/loop-fixture.mov"))
        service.play()
        try await startLoop(service: service, player: player)
        interveningAction(service)
        let noPlay = expectation(description: "Obsolete loop must not issue play")
        noPlay.isInverted = true
        player.onPlay = { noPlay.fulfill() }
        player.completeLoop(true)
        await fulfillment(of: [noPlay], timeout: 0.15)
    }

    private func startLoop(service: AVVideoPlaybackService, player: ControlledLoopPlayer) async throws {
        let started = expectation(description: "Loop seek starts")
        player.onSeek = { started.fulfill() }
        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: try XCTUnwrap(service.player.currentItem))
        await fulfillment(of: [started], timeout: 1)
        player.onSeek = nil
    }
}

/// AVFoundation 완료 순서를 제어한다. 실제 디코딩/재생은 기존 SeekTests에서 검증한다.
private final class ControlledLoopPlayer: AVQueuePlayer, @unchecked Sendable {
    var onSeek: (() -> Void)?
    var onPlay: (() -> Void)?
    private var loopCompletion: (@Sendable (Bool) -> Void)?
    override func seek(to time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime,
                       completionHandler: @escaping @Sendable (Bool) -> Void) {
        loopCompletion = completionHandler
        onSeek?()
    }
    override func play() { onPlay?() }
    override func pause() { }
    func completeLoop(_ finished: Bool) {
        let completion = loopCompletion
        loopCompletion = nil
        completion?(finished)
    }
}
