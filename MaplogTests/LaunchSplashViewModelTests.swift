import XCTest
@testable import Maplog

@MainActor
final class LaunchSplashViewModelTests: XCTestCase {
    func testResolvedDestinationRevealsImmediatelyWithoutEntranceOrHomeSignal() {
        let model = LaunchSplashViewModel()
        model.destinationDidBecomeReady()
        XCTAssertEqual(model.stage, .revealing)
        XCTAssertEqual(LaunchSplashViewModel.revealDuration, .milliseconds(150))
        model.revealDidFinish()
        XCTAssertFalse(model.isVisible)
    }

    func testUnresolvedSessionCannotBeBypassedByAnimationCompletion() {
        let model = LaunchSplashViewModel()
        model.revealDidFinish()
        XCTAssertEqual(model.stage, .presenting)
    }

    func testLoginAndLocationCompletionDoNotStartAnotherSplash() {
        let model = LaunchSplashViewModel()
        model.destinationDidBecomeReady()
        model.revealDidFinish()
        // 로그인과 위치 권한 단계가 끝나도 시작 화면을 다시 열지 않습니다.
        model.destinationDidBecomeReady()
        model.destinationDidBecomeReady()
        XCTAssertFalse(model.isVisible)
    }

    func testRepeatedReadyEventsDoNotRestartTransition() {
        let model = LaunchSplashViewModel()
        model.destinationDidBecomeReady()
        model.destinationDidBecomeReady()
        XCTAssertEqual(model.stage, .revealing)
        model.revealDidFinish()
        model.revealDidFinish()
        XCTAssertEqual(model.stage, .finished)
    }
}
