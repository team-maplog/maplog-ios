import SwiftUI
import XCTest
@testable import Maplog

@MainActor
final class HomeTourismPortraitLayoutTests: XCTestCase {
    func testPostersShareHeightAndShortTitlesDoNotReserveSecondLine() async throws {
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
                ForEach(0..<3) { index in
                    HomeTourismCarouselCard(
                        card: HomeTourismCardViewData(
                            id: Int64(index), title: ["축제", "축제", "두 줄 제목\n둘째 줄"][index],
                            locationText: "서울", periodText: "09.09", dDayText: nil,
                            poster: images[index == 2 ? 0 : index]
                        )
                    )
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { measurements.sizes[index] = $0 }
                }
            }
            Spacer()
        }
        .padding(16)
        .overlay {
            Text("축제")
                .font(.subheadline.weight(.semibold))
                .fixedSize()
                .onGeometryChange(for: CGSize.self) { $0.size } action: { measurements.sizes[3] = $0 }
                .hidden()
        }
        .overlay {
            Text("축제\n축제")
                .font(.subheadline.weight(.semibold))
                .fixedSize()
                .onGeometryChange(for: CGSize.self) { $0.size } action: { measurements.sizes[4] = $0 }
                .hidden()
        }
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
        let twoLineTitle = try XCTUnwrap(measurements.sizes[2])
        XCTAssertEqual(portrait.width, 200 * images[0].aspectRatio, accuracy: 0.5)
        XCTAssertEqual(tallPortrait.width, 200 * images[1].aspectRatio, accuracy: 0.5)
        XCTAssertEqual(portrait.height, tallPortrait.height, accuracy: 1)
        XCTAssertEqual(twoLineTitle.width, portrait.width, accuracy: 0.5)
        // 이미지와 메타데이터가 같아도 두 줄 제목만 실제 한 줄 높이만큼 더 차지해야 한다.
        let titleLine = try XCTUnwrap(measurements.sizes[3])
        let twoTitleLines = try XCTUnwrap(measurements.sizes[4])
        XCTAssertEqual(twoLineTitle.height - portrait.height,
                       twoTitleLines.height - titleLine.height, accuracy: 1)

        let screenshot = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: screenshot)
        attachment.name = "Home festival equal image heights and natural titles"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor
private final class CardMeasurements {
    var sizes: [Int: CGSize] = [:]
}
