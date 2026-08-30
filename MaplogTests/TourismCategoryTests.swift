//
//  TourismCategoryTests.swift
//  MaplogTests
//
//  Created by Codex on 8/30/26.
//

import Foundation
import XCTest
@testable import Maplog

final class TourismCategoryTests: XCTestCase {
    func testTourismDetailDecodesPlaceCategoriesFromMapAPI() throws {
        let expectedCategories: [(rawValue: String, category: TourismCategory)] = [
            ("ACCOMMODATION", .accommodation),
            ("FOOD", .food),
            ("SHOPPING", .shopping)
        ]

        for expected in expectedCategories {
            let detail = try JSONDecoder().decode(
                TourismDetailDTO.self,
                from: makeTourismDetailData(category: expected.rawValue)
            )

            XCTAssertEqual(detail.category, expected.category)
        }
    }

    private func makeTourismDetailData(category: String) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "tourismId": 301,
                "category": category,
                "common": ["name": "테스트 장소"],
                "repeatInfo": [],
                "images": []
            ]
        )
    }
}
