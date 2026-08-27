import XCTest

@testable import Maplog

final class VideoCompositionConfigurationTests: XCTestCase {
    func testPortraitThreeSplitUsesOneLargeTopSlotAndTwoLowerSlots() {
        let frames = VideoCompositionLayout.splitThree.normalizedFrames(
            for: .portrait
        )

        XCTAssertEqual(frames.count, 3)
        XCTAssertEqual(frames[0], CGRect(x: 0, y: 0, width: 1, height: 0.5))
        XCTAssertEqual(frames[1], CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5))
        XCTAssertEqual(frames[2], CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5))
    }

    func testLandscapeTwoSplitUsesSideBySideSlots() {
        let frames = VideoCompositionLayout.splitTwo.normalizedFrames(
            for: .landscape
        )

        XCTAssertEqual(frames.count, 2)
        XCTAssertEqual(frames[0], CGRect(x: 0, y: 0, width: 0.5, height: 1))
        XCTAssertEqual(frames[1], CGRect(x: 0.5, y: 0, width: 0.5, height: 1))
    }

    func testSplitLayoutRequiresItsMatchingClipCount() {
        XCTAssertEqual(VideoCompositionLayout.single.requiredClipCount, 1)
        XCTAssertEqual(VideoCompositionLayout.splitTwo.requiredClipCount, 2)
        XCTAssertEqual(VideoCompositionLayout.splitThree.requiredClipCount, 3)
    }
}
