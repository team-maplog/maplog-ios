import Foundation
import XCTest
@testable import Maplog

final class ProfileResponseDTOTests: XCTestCase {
    func testDecodesNilBio() throws {
        let data = Data(
            """
            {
              "userId": "A0C09D75-1DB4-4E65-BEEF-5975994401D3",
              "nickname": "채림",
              "profileImageUrl": null,
              "bio": null,
              "followerCount": 0,
              "followingCount": 0,
              "logCount": 0
            }
            """.utf8
        )

        let dto = try JSONDecoder().decode(
            MyProfileResponseDTO.self,
            from: data
        )

        XCTAssertNil(dto.bio)
    }
}
