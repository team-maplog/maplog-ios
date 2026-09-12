import XCTest
@testable import Maplog

final class HomeReelMetadataLayoutTests: XCTestCase {
    func testProfileMovesWithFirstReelWhileScrollingBothDirections() {
        // 다른 릴스가 들어올 때도 첫 릴스의 프로필은 실제 작성자 행 위치를 따라야 한다.
        for pageTop: CGFloat in [0, -200, -600, -874, -600, -200, 0] {
            let authorY: CGFloat = 660 + pageTop
            XCTAssertEqual(
                HomeReelMetadataLayout.verticalOffset(
                    sourceY: 730, authorY: authorY, pageTop: pageTop, revealProgress: 1
                ),
                authorY, accuracy: 0.001
            )
        }
    }

    func testRetainedOffscreenFirstReelDoesNotDisplayOverlay() {
        // LazyVStack이 첫 페이지의 anchor를 보관해도 화면 밖에서는 표시하지 않는다.
        XCTAssertFalse(HomeReelMetadataLayout.isVisible(pageTop: -874, viewportHeight: 874))
        XCTAssertFalse(HomeReelMetadataLayout.isVisible(pageTop: -1748, viewportHeight: 874))
        XCTAssertFalse(HomeReelMetadataLayout.isVisible(pageTop: 874, viewportHeight: 874))
        XCTAssertTrue(HomeReelMetadataLayout.isVisible(pageTop: -200, viewportHeight: 874))
        XCTAssertTrue(HomeReelMetadataLayout.isVisible(pageTop: 0, viewportHeight: 874))
        XCTAssertTrue(HomeReelMetadataLayout.isVisible(pageTop: 400, viewportHeight: 874))
    }

    func testHomePreviewStillInterpolatesContinuouslyIntoFirstReel() {
        XCTAssertEqual(HomeReelMetadataLayout.verticalOffset(
            sourceY: 730, authorY: 1097, pageTop: 437, revealProgress: 0.5
        ), 695)
        XCTAssertEqual(HomeReelMetadataLayout.verticalOffset(
            sourceY: 730, authorY: 660, pageTop: 0, revealProgress: 1
        ), 660)
        XCTAssertEqual(HomeReelMetadataLayout.verticalOffset(
            sourceY: 730, authorY: 659, pageTop: -1, revealProgress: 1
        ), 659)
    }
}
