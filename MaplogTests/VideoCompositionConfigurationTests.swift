import XCTest

@testable import Maplog

final class VideoCompositionConfigurationTests: XCTestCase {
    func testThreeSplitInVerticalDirectionUsesThreeStackedSlots() {
        let frames = VideoCompositionLayout.splitThree.normalizedFrames(
            for: .vertical
        )

        XCTAssertEqual(frames.count, 3)
        XCTAssertEqual(
            frames[0],
            CGRect(x: 0, y: 0, width: 1, height: 1.0 / 3.0)
        )
        XCTAssertEqual(
            frames[1],
            CGRect(x: 0, y: 1.0 / 3.0, width: 1, height: 1.0 / 3.0)
        )
        XCTAssertEqual(
            frames[2],
            CGRect(x: 0, y: 2.0 / 3.0, width: 1, height: 1.0 / 3.0)
        )
    }

    func testThreeSplitInHorizontalDirectionUsesThreeSideBySideSlots() {
        let frames = VideoCompositionLayout.splitThree.normalizedFrames(
            for: .horizontal
        )

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

    func testTwoSplitInVerticalDirectionUsesTwoStackedSlots() {
        let frames = VideoCompositionLayout.splitTwo.normalizedFrames(
            for: .vertical
        )

        XCTAssertEqual(frames.count, 2)
        XCTAssertEqual(frames[0], CGRect(x: 0, y: 0, width: 1, height: 0.5))
        XCTAssertEqual(frames[1], CGRect(x: 0, y: 0.5, width: 1, height: 0.5))
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
