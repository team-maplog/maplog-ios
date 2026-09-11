import SwiftUI
import XCTest
@testable import Maplog

@MainActor
final class DirectCropPreviewTests: XCTestCase {
    func testCropPreviewShowsTopOfSourceAfterDraggingDown() throws {
        let image = try render(crop: VideoClipCrop(verticalPosition: 0))
        assertColor(in: image, x: 150, y: 100, red: true)
        assertColor(in: image, x: 150, y: 200, red: true)
    }

    func testClockwisePreviewPutsSourceTopOnRight() throws {
        let image = try render(crop: VideoClipCrop(quarterTurns: 1))
        assertColor(in: image, x: 75, y: 150, red: false)
        assertColor(in: image, x: 225, y: 150, red: true)
    }

    func testEmptyTextCanvasPassesTouchesOnlyInClipSelectionMode() {
        let canvas = EditorTextOverlayCanvasUIView(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        XCTAssertTrue(canvas.hitTest(CGPoint(x: 100, y: 100), with: nil) === canvas)
        canvas.passesBackgroundTouches = true
        XCTAssertNil(canvas.hitTest(CGPoint(x: 100, y: 100), with: nil))
    }

    private func render(crop: VideoClipCrop) throws -> UIImage {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 128)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 64, width: 64, height: 64))
        }
        let id = UUID()
        var configuration = VideoCompositionConfiguration(layout: .splitTwo)
        configuration.clipCrops[id] = crop
        let renderer = ImageRenderer(content: ClipEditorDirectCropView(
            configuration: configuration, clipIDs: [id, UUID()], selectedID: id,
            frameData: source.pngData(), isUpdating: false, onSelect: { _ in }, onCommit: { _, _ in }
        ).frame(width: 300, height: 600).background(.black))
        renderer.scale = 1
        return try XCTUnwrap(renderer.uiImage)
    }

    private func assertColor(in image: UIImage, x: Int, y: Int, red: Bool,
                             file: StaticString = #filePath, line: UInt = #line) {
        guard let cgImage = image.cgImage else { return XCTFail("Missing image", file: file, line: line) }
        var pixel = [UInt8](repeating: 0, count: 4)
        let space = CGColorSpaceCreateDeviceRGB()
        pixel.withUnsafeMutableBytes { bytes in
            let context = CGContext(data: bytes.baseAddress, width: 1, height: 1,
                                    bitsPerComponent: 8, bytesPerRow: 4, space: space,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.translateBy(x: -CGFloat(x), y: CGFloat(y + 1 - cgImage.height))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        }
        XCTAssertGreaterThan(pixel[red ? 0 : 2], 200, file: file, line: line)
        XCTAssertLessThan(pixel[red ? 2 : 0], 40, file: file, line: line)
    }
}
