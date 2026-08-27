import XCTest

@testable import Maplog

final class VideoCompositionConfigurationTests: XCTestCase {
    func testThreeSplitUsesThreeVerticalSlots() {
        let frames = VideoCompositionLayout.splitThree.normalizedFrames

        XCTAssertEqual(frames.count, 3)
        XCTAssertEqual(
            frames[0],
            CGRect(x: 0, y: 0, width: 1.0 / 3.0, height: 1)
        )
        XCTAssertEqual(
            frames[1],
            CGRect(x: 1.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1)
        )
        XCTAssertEqual(
            frames[2],
            CGRect(x: 2.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1)
        )
    }

    func testTwoSplitUsesTwoVerticalSlots() {
        let frames = VideoCompositionLayout.splitTwo.normalizedFrames

        XCTAssertEqual(frames.count, 2)
        XCTAssertEqual(frames[0], CGRect(x: 0, y: 0, width: 0.5, height: 1))
        XCTAssertEqual(frames[1], CGRect(x: 0.5, y: 0, width: 0.5, height: 1))
    }

    func testCompositionAlwaysRendersAsAPortraitReel() {
        let configuration = VideoCompositionConfiguration(layout: .splitThree)

        XCTAssertEqual(
            configuration.renderSize,
            CGSize(width: 1_080, height: 1_920)
        )
        XCTAssertEqual(configuration.aspectRatio, 9.0 / 16.0)
    }

    func testSplitLayoutRequiresItsMatchingClipCount() {
        XCTAssertEqual(VideoCompositionLayout.single.requiredClipCount, 1)
        XCTAssertEqual(VideoCompositionLayout.splitTwo.requiredClipCount, 2)
        XCTAssertEqual(VideoCompositionLayout.splitThree.requiredClipCount, 3)
    }
}
