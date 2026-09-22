import SwiftUI
import XCTest
@testable import Maplog

@MainActor
final class TourismListLayoutTests: XCTestCase {
    func testCategoryCarouselStaysVisibleAndScrollsOnPhoneSizes() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        defer {
            window.isHidden = true
            previousKeyWindow?.makeKeyAndVisible()
        }
        for size in [CGSize(width: 390, height: 844), CGSize(width: 375, height: 667)] {
            window.frame = CGRect(origin: .zero, size: size)
            let host = UIHostingController(rootView: NavigationStack {
                TourismListView(tourismRepository: ListLayoutRepositoryStub())
            })
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.frame = window.bounds
            host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(500))

            let carousel = try XCTUnwrap(scrollViews(in: host.view).first {
                $0.contentSize.width > $0.bounds.width && $0.bounds.height <= 60
            })
            let frame = carousel.convert(carousel.bounds, to: window)
            XCTAssertGreaterThanOrEqual(frame.minY, window.safeAreaInsets.top)
            XCTAssertLessThan(frame.maxY, size.height / 2)
            XCTAssertGreaterThanOrEqual(frame.height, 44)
            carousel.setContentOffset(CGPoint(x: carousel.contentSize.width - carousel.bounds.width, y: 0), animated: false)
            XCTAssertGreaterThan(carousel.contentOffset.x, 0)

            let screenshot = UIGraphicsImageRenderer(size: size).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: screenshot)
            attachment.name = "Tourism categories \(Int(size.width))x\(Int(size.height))"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func scrollViews(in view: UIView) -> [UIScrollView] {
        (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap(scrollViews)
    }
}

private struct ListLayoutRepositoryStub: TourismRepository {
    func invalidateCache() async {}
    func fetchTourisms(category: TourismCategory, cursor: String?, size: Int, policy: TourismFetchPolicy) async throws -> TourismPage {
        TourismPage(tourisms: [Tourism(id: 1, name: "서울 가을 축제", region: "서울", address: nil,
            thumbnailURL: nil, startDate: nil, endDate: nil, category: .festival)], hasNext: false, nextCursor: nil)
    }
    func fetchPortraitImage(tourismID: Int64, policy: TourismFetchPolicy) async throws -> TourismPortraitImage? { nil }
    func fetchTourismDetail(tourismID: Int64, policy: TourismFetchPolicy) async throws -> TourismDetail { throw APIError.missingData }
}
