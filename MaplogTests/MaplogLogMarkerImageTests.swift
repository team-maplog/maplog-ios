import SwiftUI
import XCTest
@testable import Maplog

@MainActor
final class MaplogLogMarkerImageTests: XCTestCase {
    func testRouteUsesExploreMarkerSizeAndRetainsSequenceWithoutThumbnail() throws {
        let thumbnail = try XCTUnwrap(UIImage(named: "event_gangneung_dano_hero")?.pngData())
        for selected in [false, true] {
            for data: Data? in [thumbnail, nil, Data()] {
                let explore = MaplogLogMarkerImage.image(thumbnailData: data, isSelected: selected)
                let first = MaplogLogMarkerImage.image(thumbnailData: data, isSelected: selected, sequence: 1)
                let second = MaplogLogMarkerImage.image(thumbnailData: data, isSelected: selected, sequence: 2)
                XCTAssertEqual(first.size, explore.size)
                XCTAssertEqual(first.size, selected ? CGSize(width: 38, height: 47) : CGSize(width: 32, height: 40))
                XCTAssertNotEqual(first.pngData(), explore.pngData())
                XCTAssertNotEqual(first.pngData(), second.pngData())
            }
        }
    }

    func testCaptureControlsAndMarkerPreview() async throws {
        let thumbnail = try XCTUnwrap(UIImage(named: "event_gangneung_dano_hero")?.pngData())
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 420)
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        let content = VStack(spacing: 28) {
            Text("지도 탭 / 경로 1 · 2 · 3").foregroundStyle(.white)
            HStack(spacing: 24) {
                Image(uiImage: MaplogLogMarkerImage.image(thumbnailData: thumbnail, isSelected: false))
                ForEach(1...3, id: \.self) { sequence in
                    Image(uiImage: MaplogLogMarkerImage.image(
                        thumbnailData: sequence == 3 ? nil : thumbnail,
                        isSelected: sequence == 2, sequence: sequence
                    ))
                }
            }
            HStack(spacing: 12) {
                MaplogTabBar(selectedTab: .constant(.home), isCompact: true, isReelStyle: true)
                MaplogCaptureButton(isReelStyle: true) {}
            }.padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
        let host = UIHostingController(rootView: content)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(500))
        let screenshot = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: screenshot)
        attachment.name = "Compact numbered markers and bright controls on dark background"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
