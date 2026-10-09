import XCTest
@testable import Maplog

final class MaplogImageCacheKeyTests: XCTestCase {
    func testSameLogThumbnailOnDifferentServersHasDifferentCacheKeys() throws {
        let development = try XCTUnwrap(URL(string: "https://dev-api.example.com/api/v1/logs/7/thumbnail"))
        let production = try XCTUnwrap(URL(string: "https://api.example.com/api/v1/logs/7/thumbnail"))

        XCTAssertNotEqual(MaplogImageCacheKey.stableURL(development), MaplogImageCacheKey.stableURL(production))
        XCTAssertNotEqual(MaplogImageCacheKey.stableURL(development), "log-thumbnail-7")
    }

    func testStableURLDoesNotKeepCredentialsOrFragment() throws {
        let url = try XCTUnwrap(URL(string: "https://user:password@images.example.com/log.jpg?token=secret&width=640#private"))

        XCTAssertEqual(MaplogImageCacheKey.stableURL(url), "image-url:https://images.example.com/log.jpg?width=640")
    }

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
