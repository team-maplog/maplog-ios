import XCTest

@testable import Maplog

final class VideoCompositionConfigurationTests: XCTestCase {
    func testDragMovesContentWithFingerAndClampsAtEdges() {
        let crop = VideoClipCrop()
        let source = CGSize(width: 1080, height: 1920)
        let slot = CGSize(width: 300, height: 150)
        let down = crop.moved(by: CGSize(width: 0, height: 10000), sourceSize: source, slotSize: slot)
        let up = crop.moved(by: CGSize(width: 0, height: -10000), sourceSize: source, slotSize: slot)
        XCTAssertEqual(down.verticalPosition, 0)
        XCTAssertEqual(up.verticalPosition, 1)
        XCTAssertEqual(down.horizontalPosition, 0.5)
    }

    func testFourQuarterTurnsRestoreOriginalOrientation() {
        XCTAssertEqual(VideoClipCrop(quarterTurns: 4), VideoClipCrop())
        XCTAssertEqual(VideoClipCrop(quarterTurns: -1).quarterTurns, 3)
        let crop = VideoClipCrop(quarterTurns: 1)
        let moved = crop.moved(by: CGSize(width: 20, height: 30),
                               sourceSize: CGSize(width: 1920, height: 1080),
                               slotSize: CGSize(width: 300, height: 150))
        XCTAssertEqual(moved.quarterTurns, 1)
    }

    func testClockwiseRotationMapsSourceCornersInsideDestination() throws {
        let placement = try VideoCompositionPlacement.make(
            naturalSize: CGSize(width: 64, height: 128), sourceTransform: .identity,
            in: CGRect(x: 0, y: 0, width: 128, height: 64), contentMode: .fit,
            crop: VideoClipCrop(quarterTurns: 1)
        )
        let topLeft = CGPoint.zero.applying(placement.transform)
        let bottomLeft = CGPoint(x: 0, y: 128).applying(placement.transform)
        XCTAssertEqual(topLeft.x, 128, accuracy: 0.001)
        XCTAssertEqual(topLeft.y, 0, accuracy: 0.001)
        XCTAssertEqual(bottomLeft.x, 0, accuracy: 0.001)
        XCTAssertEqual(bottomLeft.y, 0, accuracy: 0.001)
    }

    func testRotatedFillCropCoversSlotWithoutLeavingSource() throws {
        let source = CGRect(x: 0, y: 0, width: 1080, height: 1920)
        let slot = CGRect(x: 0, y: 640, width: 1080, height: 640)
        for turns in 0..<4 {
            let placement = try VideoCompositionPlacement.make(
                naturalSize: source.size, sourceTransform: .identity, in: slot, contentMode: .fill,
                crop: VideoClipCrop(horizontalPosition: 1, verticalPosition: 0, zoom: 1.5, quarterTurns: turns)
            )
            let rect = try XCTUnwrap(placement.sourceCropRect)
            XCTAssertTrue(source.insetBy(dx: -0.001, dy: -0.001).contains(rect))
            let rendered = rect.applying(placement.transform)
            XCTAssertEqual(rendered.minX, slot.minX, accuracy: 0.001)
            XCTAssertEqual(rendered.minY, slot.minY, accuracy: 0.001)
            XCTAssertEqual(rendered.width, slot.width, accuracy: 0.001)
            XCTAssertEqual(rendered.height, slot.height, accuracy: 0.001)
        }
    }

    func testCropCanReachBothEdgesWithoutLeavingSourceBounds() {
        let bounds = CGRect(x: 10, y: 20, width: 1920, height: 1080)
        let left = VideoClipCrop(horizontalPosition: 0).sourceRect(in: bounds, destinationAspectRatio: 0.5)
        let right = VideoClipCrop(horizontalPosition: 1).sourceRect(in: bounds, destinationAspectRatio: 0.5)
        XCTAssertEqual(left.minX, bounds.minX)
        XCTAssertEqual(right.maxX, bounds.maxX)
        XCTAssertEqual(left.width / left.height, 0.5, accuracy: 0.0001)
        XCTAssertTrue(bounds.contains(left))
        XCTAssertTrue(bounds.contains(right))
    }

    func testZoomedCropCanReachTopAndBottomOfPortraitSource() {
        let bounds = CGRect(x: 0, y: 0, width: 1080, height: 1920)
        let top = VideoClipCrop(verticalPosition: 0, zoom: 2).sourceRect(in: bounds, destinationAspectRatio: 1.5)
        let bottom = VideoClipCrop(verticalPosition: 1, zoom: 2).sourceRect(in: bounds, destinationAspectRatio: 1.5)
        XCTAssertEqual(top.minY, 0)
        XCTAssertEqual(bottom.maxY, 1920)
        XCTAssertEqual(top.width, 540)
        XCTAssertEqual(top.height, 360)
        XCTAssertTrue(bounds.contains(bottom))
    }

    func testInvalidCropValuesAreClamped() {
        let crop = VideoClipCrop(horizontalPosition: -1, verticalPosition: 4, zoom: 0)
        XCTAssertEqual(crop.horizontalPosition, 0)
        XCTAssertEqual(crop.verticalPosition, 1)
        XCTAssertEqual(crop.zoom, 1)
        XCTAssertEqual(VideoClipCrop(zoom: .nan).zoom, 1)
    }

    func testThreeSplitInVerticalSceneUsesThreeStackedSlots() {
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

    func testThreeSplitInHorizontalSceneUsesThreeSideBySideSlots() {
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

    func testTwoSplitInVerticalSceneUsesTwoStackedSlots() {
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

    func testHorizontalSceneIsCenteredInsidePortraitReel() {
        let configuration = VideoCompositionConfiguration(
            layout: .splitThree,
            sceneOrientation: .horizontal
        )

        XCTAssertEqual(
            configuration.sceneFrame,
            CGRect(x: 0, y: 656.25, width: 1_080, height: 607.5)
        )
    }

    func testSplitLayoutRequiresItsMatchingClipCount() {
        XCTAssertEqual(VideoCompositionLayout.single.requiredClipCount, 1)
        XCTAssertEqual(VideoCompositionLayout.splitTwo.requiredClipCount, 2)
        XCTAssertEqual(VideoCompositionLayout.splitThree.requiredClipCount, 3)
    }

    func testVerticalSplitCaptureFrameMatchesOneDestinationSlot() {
        let twoSplit = VideoCompositionConfiguration(layout: .splitTwo)
        let threeSplit = VideoCompositionConfiguration(layout: .splitThree)

        XCTAssertEqual(
            twoSplit.captureFrameAspectRatio(for: 0),
            9.0 / 8.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(twoSplit.captureFrameRatioTitle, "9:8")

        XCTAssertEqual(
            threeSplit.captureFrameAspectRatio(for: 2),
            27.0 / 16.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(threeSplit.captureFrameRatioTitle, "27:16")
    }

    func testHorizontalSplitCaptureFrameMatchesOneDestinationSlot() {
        let configuration = VideoCompositionConfiguration(
            layout: .splitThree,
            sceneOrientation: .horizontal
        )

        XCTAssertEqual(
            configuration.captureFrameAspectRatio(for: 1),
            16.0 / 27.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(configuration.captureFrameRatioTitle, "16:27")
    }

    func testSplitTimelineStartsEverySelectedClipTogether() {
        let clips = [
            makeClip(duration: 5),
            makeClip(duration: 3),
            makeClip(duration: 4)
        ]
        let timeline = ClipEditorTimeline(
            clips: clips,
            compositionConfiguration: VideoCompositionConfiguration(
                layout: .splitThree
            )
        )

        XCTAssertEqual(timeline.segments.count, 3)
        XCTAssertTrue(timeline.segments.allSatisfy { $0.startTime == 0 })
        XCTAssertTrue(timeline.segments.allSatisfy { $0.endTime == 3 })
        XCTAssertEqual(timeline.totalDuration, 3)
    }

    private func makeClip(duration: TimeInterval) -> CaptureDraftClip {
        CaptureDraftClip(
            id: UUID(),
            mediaType: .video,
            fileURL: URL(fileURLWithPath: "/tmp/clip.mov"),
            capturedAt: .now,
            duration: duration,
            location: nil,
            timestampStyle: .none
        )
    }
}
