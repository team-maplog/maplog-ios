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

    func testSlowDestinationRemainsCoveredUntilReadyOrDeadlineSignal() {
        let model = LaunchSplashViewModel()
        model.entranceDidFinish()
        XCTAssertEqual(model.stage, .presenting)
        // RootView sends the same readiness signal when the home wait limit expires.
        model.destinationDidBecomeReady()
        XCTAssertEqual(model.stage, .revealing)
    }

    func testFinishingAnimationCannotBypassUnresolvedSession() {
        let model = LaunchSplashViewModel()
        model.entranceDidFinish()
        model.revealDidFinish()
        XCTAssertEqual(model.stage, .presenting)
    }

    func testRestoredSessionDoesNotRestartVisibleEntrance() {
        let model = LaunchSplashViewModel()
        let id = model.presentationID
        model.entranceDidFinish()
        model.prepareForHome()
        XCTAssertEqual(model.presentationID, id)
        model.destinationDidBecomeReady()
        XCTAssertEqual(model.stage, .revealing)
    }

    func testLoginStartsNewPresentationAfterOnboarding() {
        let model = LaunchSplashViewModel()
        model.entranceDidFinish()
        model.destinationDidBecomeReady()
        model.revealDidFinish()
        let previousID = model.presentationID
        model.prepareForHome()
        XCTAssertNotEqual(model.presentationID, previousID)
        XCTAssertEqual(model.stage, .presenting)
        model.entranceDidFinish()
        XCTAssertEqual(model.stage, .presenting)
        model.destinationDidBecomeReady()
        XCTAssertEqual(model.stage, .revealing)
    }

    func testLateDataAfterTimeoutDoesNotShowSplashAgain() {
        let model = LaunchSplashViewModel()
        model.entranceDidFinish()
        model.destinationDidBecomeReady()
        model.revealDidFinish()
        model.destinationDidBecomeReady()
        model.entranceDidFinish()
        XCTAssertFalse(model.isVisible)
    }
}
