import XCTest
@testable import Maplog

final class MaplogImageCacheKeyTests: XCTestCase {
    func testStableURLIgnoresExpiringAuthenticationQueryItems() throws {
        let firstURL = try XCTUnwrap(
            URL(
                string: "https://images.example.com/log.jpg?width=640&token=first&expires=100&signature=old"
            )
        )
        let refreshedURL = try XCTUnwrap(
            URL(
                string: "https://images.example.com/log.jpg?signature=new&expires=200&width=640&token=second"
            )
        )

        XCTAssertEqual(
            MaplogImageCacheKey.stableURL(firstURL),
            MaplogImageCacheKey.stableURL(refreshedURL)
        )
    }

    func testStableURLKeepsImageTransformQueryItems() throws {
        let smallImageURL = try XCTUnwrap(
            URL(string: "https://images.example.com/log.jpg?width=320&token=value")
        )
        let largeImageURL = try XCTUnwrap(
            URL(string: "https://images.example.com/log.jpg?width=640&token=value")
        )

        XCTAssertNotEqual(
            MaplogImageCacheKey.stableURL(smallImageURL),
            MaplogImageCacheKey.stableURL(largeImageURL)
        )
    }
}
