import XCTest

@testable import Maplog

final class OAuthHandoffCodeTests: XCTestCase {
    func testExpectedUniversalLinkExtractsTrimmedSingleHandoffCode() throws {
        let callbackURL = try XCTUnwrap(
            URL(string: "https://maplog.millenniumrhino.com/auth/ios?handoffCode=%20one-time-code%20")
        )

        let handoffCode = try OAuthHandoffCode(callbackURL: callbackURL)

        XCTAssertEqual(handoffCode.value, "one-time-code")
    }

    func testUnexpectedHostIsRejected() throws {
        let callbackURL = try XCTUnwrap(
            URL(string: "https://untrusted.example/auth/ios?handoffCode=one-time-code")
        )

        XCTAssertThrowsError(try OAuthHandoffCode(callbackURL: callbackURL)) { error in
            XCTAssertEqual(error as? OAuthCallbackError, .unexpectedCallback)
        }
    }

    func testRepeatedHandoffCodeIsRejected() throws {
        let callbackURL = try XCTUnwrap(
            URL(
                string: "https://maplog.millenniumrhino.com/auth/ios?handoffCode=first&handoffCode=second"
            )
        )

        XCTAssertThrowsError(try OAuthHandoffCode(callbackURL: callbackURL)) { error in
            XCTAssertEqual(error as? OAuthCallbackError, .missingHandoffCode)
        }
    }
}
