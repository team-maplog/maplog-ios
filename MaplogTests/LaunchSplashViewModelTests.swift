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

    func testEntranceWaitsForTourismResultBeforeRevealingHome() {
        let model = LaunchSplashViewModel()
        model.entranceDidFinish()
        XCTAssertEqual(model.stage, .presenting)
        // 카드 모션이 끝나도 관광 조회 결과가 준비되기 전에는 홈을 열지 않습니다.
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
