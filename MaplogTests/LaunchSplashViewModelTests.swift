import XCTest
@testable import Maplog

@MainActor
final class LaunchSplashViewModelTests: XCTestCase {
    func testFastDestinationStillFinishesEntranceBeforeRevealing() {
        let model = LaunchSplashViewModel()
        model.destinationDidBecomeReady()
        XCTAssertEqual(model.stage, .presenting)
        model.entranceDidFinish()
        XCTAssertEqual(model.stage, .revealing)
        model.revealDidFinish()
        XCTAssertFalse(model.isVisible)
    }

    func testEntranceWaitsForSessionButDoesNotNeedHomeResponse() {
        let model = LaunchSplashViewModel()
        model.entranceDidFinish()
        XCTAssertEqual(model.stage, .presenting)
        // 세션 분기 완료만 전달합니다. 홈 조회 완료 신호는 필요하지 않습니다.
        model.destinationDidBecomeReady()
        XCTAssertEqual(model.stage, .revealing)
    }

    func testFinishingAnimationCannotBypassUnresolvedSession() {
        let model = LaunchSplashViewModel()
        model.entranceDidFinish()
        model.revealDidFinish()
        XCTAssertEqual(model.stage, .presenting)
    }

    func testDestinationChangeDuringRevealDoesNotRestartEntrance() {
        let model = LaunchSplashViewModel()
        model.entranceDidFinish()
        model.destinationDidBecomeReady()
        XCTAssertEqual(model.stage, .revealing)
        model.destinationDidBecomeReady()
        XCTAssertEqual(model.stage, .revealing)
        model.revealDidFinish()
        XCTAssertFalse(model.isVisible)
    }

    func testRepeatedReadinessAfterCompletionDoesNotShowSplashAgain() {
        let model = LaunchSplashViewModel()
        model.entranceDidFinish()
        model.destinationDidBecomeReady()
        model.revealDidFinish()
        model.destinationDidBecomeReady()
        model.entranceDidFinish()
        XCTAssertFalse(model.isVisible)
    }
}
