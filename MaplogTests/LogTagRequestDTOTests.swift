import Foundation
import XCTest
@testable import Maplog

final class LogTagRequestDTOTests: XCTestCase {
    func testCreateRequestEncodesOnlyCaptionHashtagsInTags() throws {
        let request = LogCreateRequestDTO(
            caption: "성수에서 보낸 오후 #성수동 #한강산책",
            tags: ["성수동", "한강산책"],
            address: "서울 성동구 성수동",
            videoFileId: 10,
            thumbnailTimeMillis: nil,
            clips: []
        )

        let json = try jsonObject(from: request)

        XCTAssertEqual(json["tags"] as? [String], ["성수동", "한강산책"])
        XCTAssertNil(json["customTags"])
        XCTAssertNil(json["thumbnailTimeMillis"])
    }

    func testUpdateRequestDistinguishesOmittedAndEmptyTags() throws {
        let unchangedTagsRequest = UpdateLogRequestDTO(
            caption: "새 캡션",
            tags: nil
        )
        let clearTagsRequest = UpdateLogRequestDTO(
            caption: "새 캡션",
            tags: []
        )

        let unchangedJSON = try jsonObject(from: unchangedTagsRequest)
        let clearedJSON = try jsonObject(from: clearTagsRequest)

        XCTAssertNil(unchangedJSON["tags"])
        XCTAssertEqual(clearedJSON["tags"] as? [String], [])
    }

    private func jsonObject<T: Encodable>(
        from value: T
    ) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }
}
