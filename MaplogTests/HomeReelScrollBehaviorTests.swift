import XCTest
@testable import Maplog

final class HomeReelScrollBehaviorTests: XCTestCase {
    func testPartialDragsSettleAtReelBoundariesAfterVariableHeightIntro() {
        for intro: CGFloat in [320, 458.6666667, 620] {
            for height: CGFloat in [667, 844, 874, 956] {
                let behavior = HomeReelScrollBehavior(introHeight: intro, pageHeight: height)
                let maximum = intro + height * 4
                for page in 0...4 {
                    let boundary = intro + CGFloat(page) * height
                    for displacement: CGFloat in [-146, -30, 0, 30, 146] {
                        XCTAssertEqual(
                            behavior.alignedOffset(proposedOffset: boundary + displacement, maximumOffset: maximum),
                            boundary, accuracy: 0.001
                        )
                    }
                }
            }
        }
    }

    func testHomeReturnAndFastSwipeAndEndBounds() {
        let behavior = HomeReelScrollBehavior(introHeight: 460, pageHeight: 874)
        XCTAssertEqual(behavior.alignedOffset(proposedOffset: -100, maximumOffset: 3082), 0)
        XCTAssertEqual(behavior.alignedOffset(proposedOffset: 200, maximumOffset: 3082), 0)
        XCTAssertEqual(behavior.alignedOffset(proposedOffset: 250, maximumOffset: 3082), 460)
        XCTAssertEqual(behavior.alignedOffset(proposedOffset: 1950, maximumOffset: 3082), 2208)
        XCTAssertEqual(behavior.alignedOffset(proposedOffset: 5000, maximumOffset: 3082), 3082)
        XCTAssertEqual(behavior.alignedOffset(proposedOffset: 800, maximumOffset: 460), 460)
    }
}
