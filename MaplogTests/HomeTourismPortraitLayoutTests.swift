import SwiftUI
import XCTest
@testable import Maplog

@MainActor
final class HomeTourismPortraitLayoutTests: XCTestCase {
    func testLoadedImagesKeepTheirOwnAspectRatioWithoutFixedHeight() async throws {
        let measurements = CardMeasurements()
        let fixture = try XCTUnwrap(UIImage(named: "event_gangneung_dano_hero"))
        let images = [
            TourismPortraitImage(url: URL(string: "https://example.invalid/portrait.png")!,
                data: try XCTUnwrap(fixture.pngData()), width: Int(fixture.size.width), height: Int(fixture.size.height))!,
            TourismPortraitImage(url: URL(string: "https://example.invalid/tall.png")!,
                data: TourismPortraitImageTests.imageData(size: CGSize(width: 200, height: 400)), width: 200, height: 400)!
        ]
        let view = VStack(alignment: .leading, spacing: 16) {
            Text("세로 카드 확인 · 샘플").font(.headline)
            HStack(alignment: .top, spacing: 12) {
                ForEach(0..<2) { index in
                    HomeTourismCarouselCard(
                        card: HomeTourismCardViewData(
                            id: Int64(index), title: ["세로형 원본", "긴 세로형 원본"][index],
                            locationText: "서울", periodText: "09.09 – 09.10", dDayText: nil,
                            poster: images[index]
                        )
                    )
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { measurements.sizes[index] = $0 }
                }
            }
            Spacer()
        }
        .padding(16)
        .environment(\.dynamicTypeSize, .large)
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

        let portrait = try XCTUnwrap(measurements.sizes[0])
        let tallPortrait = try XCTUnwrap(measurements.sizes[1])
        XCTAssertEqual(portrait.width, 150, accuracy: 0.5)
        XCTAssertEqual(tallPortrait.width, 150, accuracy: 0.5)
        let expectedDifference = 150 / images[1].aspectRatio - 150 / images[0].aspectRatio
        XCTAssertEqual(tallPortrait.height - portrait.height, expectedDifference, accuracy: 1)

        let screenshot = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: screenshot)
        attachment.name = "Home festival original image proportions"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor
private final class CardMeasurements {
    var sizes: [Int: CGSize] = [:]
}
