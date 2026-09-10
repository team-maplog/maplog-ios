import AVFoundation
import SwiftUI
import XCTest
@testable import Maplog

@MainActor
final class HomeReelLayoutTests: XCTestCase {
    func testReelInformationClearsPlaybackBarAndPreviewShowsAuthor() async throws {
        let reel = HomeReelViewData(
            id: 1, authorID: UUID(), authorName: "test1", authorProfileImageURL: nil,
            caption: "", address: "경북 포항시 북구 죽도동 556-200",
            thumbnailURL: nil, playbackURL: nil, publishedAt: Date(),
            viewCount: 1, likeCount: 0, commentCount: 0,
            isLikedByViewer: false, isSavedByViewer: false, clips: []
        )
        let thumbnail = try XCTUnwrap(UIImage(named: "event_gangneung_dano_hero")?.pngData())
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        defer {
            window.isHidden = true
            previousKeyWindow?.makeKeyAndVisible()
        }

        for showsMetadata in [false, true] {
            let measurement = ReelAuthorMeasurement()
            let view = HomeReelPage(
                reel: reel, thumbnailData: thumbnail, isLoadingThumbnail: false,
                authorProfileImageData: nil, player: nil, isLoadingPlayback: false,
                playbackProgress: 0.3, onPlayToggle: {}, onSeek: { _ in },
                isPlaying: false, isUpdatingLike: false, isUpdatingSave: false,
                onToggleLike: {}, onToggleSave: {}, onShowComments: {},
                onShowAuthorProfile: {}, onShare: {},
                cornerRadius: showsMetadata ? 0 : 18,
                previewHorizontalInset: showsMetadata ? 0 : 16,
                previewBottomInset: showsMetadata ? 0 : 394,
                showsMetadata: showsMetadata
            )
            .overlayPreferenceValue(HomeReelAuthorAnchorPreferenceKey.self) { anchors in
                GeometryReader { proxy in
                    Color.clear
                        .onGeometryChange(for: CGRect.self) { _ in
                            anchors[reel.id].map { proxy[$0] } ?? .zero
                        } action: { measurement.frame = $0 }
                }
                .allowsHitTesting(false)
            }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { measurement.pageSize = $0 }
            .environment(\.dynamicTypeSize, .large)
            .environment(\.colorScheme, .light)
            .ignoresSafeArea()
            let host = UIHostingController(rootView: view)
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.frame = window.bounds
            host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(500))

            XCTAssertEqual(measurement.pageSize, CGSize(width: 390, height: 844))
            let author = try XCTUnwrap(measurement.frame)
            XCTAssertGreaterThan(author.height, 0)
            // 작성자 다음의 한 줄 장소와 간격을 포함해도 재생 바보다 충분히 위에 남아야 한다.
            let playbackTop = 844 - VideoRenderCanvas.reelBottomTrayHeight + MaplogSpacing.large
            XCTAssertLessThan(author.maxY + 30, playbackTop - 24)

            let screenshot = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            if !showsMetadata {
                // 네 모서리 바깥과 카드 아래는 흰색이며, 원래 스크롤 페이지 높이는 유지해야 한다.
                for point in [CGPoint(x: 17, y: 1), CGPoint(x: 373, y: 1),
                              CGPoint(x: 17, y: 449), CGPoint(x: 373, y: 449),
                              CGPoint(x: 195, y: 460), CGPoint(x: 5, y: 200)] {
                    XCTAssertTrue(try isWhite(screenshot, at: point), "Expected white card margin at \(point)")
                }
                XCTAssertFalse(try isWhite(screenshot, at: CGPoint(x: 195, y: 200)))
            }
            let attachment = XCTAttachment(image: screenshot)
            attachment.name = showsMetadata ? "Reel metadata above playback" : "Rounded home preview with author"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func isWhite(_ image: UIImage, at point: CGPoint) throws -> Bool {
        let source = try XCTUnwrap(image.cgImage)
        let crop = try XCTUnwrap(source.cropping(to: CGRect(
            x: point.x * image.scale, y: point.y * image.scale, width: 1, height: 1
        )))
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return pixel[0] > 248 && pixel[1] > 248 && pixel[2] > 248
    }
}

@MainActor
private final class ReelAuthorMeasurement {
    var frame: CGRect?
    var pageSize: CGSize?
}
