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

    func testDecodesPublicProfileFollowState() throws {
        let data = Data(
            """
            {
              "userId": "A0C09D75-1DB4-4E65-BEEF-5975994401D3",
              "nickname": "slow.seoul",
              "profileImageUrl": "/api/v1/files/31",
              "bio": "서울의 느린 산책을 기록합니다.",
              "followerCount": 14,
              "followingCount": 9,
              "logCount": 21,
              "followedByViewer": true,
              "createdAt": "2026-07-10T09:00:00"
            }
            """.utf8
        )

        let dto = try JSONDecoder().decode(
            PublicProfileResponseDTO.self,
            from: data
        )

        XCTAssertEqual(dto.nickname, "slow.seoul")
        XCTAssertTrue(dto.followedByViewer)
        XCTAssertEqual(dto.logCount, 21)
    }
}
