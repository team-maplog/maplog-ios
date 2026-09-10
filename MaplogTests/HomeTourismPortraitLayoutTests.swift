import Kingfisher
import SwiftUI
import XCTest
@testable import Maplog

@MainActor
final class HomeTourismPortraitLayoutTests: XCTestCase {
    func testLandscapePortraitAndMissingThumbnailKeepSameTallCardSize() async throws {
        let measurements = CardMeasurements()
        let urls = ["photo_festival", "event_gangneung_dano_hero"].map {
            URL(string: "https://example.invalid/home-portrait-regression-\($0).png")!
        }
        for (name, url) in zip(["photo_festival", "event_gangneung_dano_hero"], urls) {
            try await MaplogImageCache.shared.store(
                try XCTUnwrap(UIImage(named: name)),
                forKey: "tourism-thumbnail-\(MaplogImageCacheKey.stableURL(url))",
                toDisk: false
            )
        }
        let view = VStack(alignment: .leading, spacing: 16) {
            Text("세로 카드 확인 · 샘플").font(.headline)
            HStack(alignment: .top, spacing: 12) {
                ForEach(0..<3) { index in
                    HomeTourismCarouselCard(
                        card: HomeTourismCardViewData(
                            id: Int64(index), title: ["가로형 원본", "세로형 원본", "이미지 없음"][index],
                            locationText: "서울", periodText: "09.09 – 09.10", dDayText: nil,
                            thumbnailURL: index < urls.count ? urls[index] : nil
                        ),
                        posterURL: index < urls.count ? urls[index] : nil
                    )
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { measurements.sizes[index] = $0 }
                }
            }
            Spacer()
        }
        .padding(16)
        .environment(\.dynamicTypeSize, .large)
        .environmentObject(AuthSessionStore())
        let host = UIHostingController(rootView: view)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 510, height: 600)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            previousKeyWindow?.makeKeyAndVisible()
        }
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .seconds(2))

        let landscape = try XCTUnwrap(measurements.sizes[0])
        let portrait = try XCTUnwrap(measurements.sizes[1])
        let missing = try XCTUnwrap(measurements.sizes[2])
        XCTAssertEqual(landscape.width, 150, accuracy: 0.5)
        XCTAssertGreaterThan(landscape.height, 246)
        XCTAssertEqual(landscape.height, portrait.height, accuracy: 0.5)
        XCTAssertEqual(landscape.height, missing.height, accuracy: 0.5)

        let screenshot = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: screenshot)
        attachment.name = "Home festival portrait cards"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor
private final class CardMeasurements {
    var sizes: [Int: CGSize] = [:]
}
