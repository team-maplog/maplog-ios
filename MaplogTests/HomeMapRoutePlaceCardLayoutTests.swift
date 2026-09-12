import SwiftUI
import XCTest
@testable import Maplog

@MainActor
final class HomeMapRoutePlaceCardLayoutTests: XCTestCase {
    func testCardFitsPagerAtNarrowWidthAndLargeText() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        let thumbnail = try XCTUnwrap(UIImage(named: "event_gangneung_dano_hero")?.pngData())

        for largeText in [false, true] {
            let width: CGFloat = largeText ? 390 : 320
            window.frame = CGRect(x: 0, y: 0, width: width, height: 500)
            let measurement = CardMeasurement()
            let point = HomeMapRoutePointViewData(
                clipID: 2, sequence: 2, startTimeMillis: 12_000, endTimeMillis: 20_000,
                placeName: largeText ? "이름 없는 장소" : "뚝섬한강공원",
                address: "서울특별시 광진구 강변북로 139",
                latitude: 37.53, longitude: 127.06, thumbnailURL: nil
            )
            let view = HomeMapRoutePlaceCard(
                point: point, logID: 2, thumbnailData: largeText ? nil : thumbnail,
                isLoadingThumbnail: false, onPlay: { _ in }
            )
            .onGeometryChange(for: CGSize.self) { $0.size } action: { measurement.size = $0 }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.maplogMapLightCanvas)
            .environment(\.dynamicTypeSize, largeText ? .accessibility1 : .large)
            .environment(\.colorScheme, .light)
            let host = UIHostingController(rootView: view)
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.frame = window.bounds
            host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(500))

            let size = try XCTUnwrap(measurement.size)
            XCTAssertEqual(size.width, width - 40, accuracy: 1)
            let traits = UITraitCollection(preferredContentSizeCategory: largeText ? .accessibilityMedium : .large)
            let pagerHeight = UIFontMetrics(forTextStyle: .body).scaledValue(for: 142, compatibleWith: traits)
            XCTAssertLessThanOrEqual(size.height, pagerHeight)
            let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = largeText ? "Route card large text without thumbnail" : "Route card narrow screen"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}

@MainActor
private final class CardMeasurement {
    var size: CGSize?
}
