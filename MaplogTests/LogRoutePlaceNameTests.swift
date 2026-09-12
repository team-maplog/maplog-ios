import XCTest
@testable import Maplog

@MainActor
final class LogRoutePlaceNameTests: XCTestCase {
    func testNullPlaceNamePreservesAllPointsThroughMapLoading() async throws {
        let service = RoutePlaceNameAPIStub(data: try responseData(placeName: NSNull()))
        let repository = DefaultLogRouteRepository(apiService: service)
        let route = try await repository.fetchRoute(logID: 2)

        XCTAssertEqual(route.points.map(\.clipID), [21, 22])
        XCTAssertNil(route.points[1].placeName)
        XCTAssertEqual(route.points[1].latitude, 35.1796)
        XCTAssertEqual(route.points[1].longitude, 129.0756)
        XCTAssertEqual(route.points[1].startTimeMillis, 1000)
        XCTAssertEqual(route.points[1].endTimeMillis, 2000)

        let viewModel = HomeMapPanelViewModel(
            logRouteRepository: repository,
            logMediaRepository: RoutePlaceNameMediaStub()
        )
        await viewModel.loadRoute(for: 2)

        guard case let .content(viewData) = viewModel.state else {
            return XCTFail("장소명이 없어도 경로가 content 상태여야 합니다.")
        }
        XCTAssertEqual(viewData.points.map(\.id), [21, 22])
        XCTAssertEqual(viewData.points[0].placeName, "서울역")
        XCTAssertEqual(viewData.points[1].placeName, "이름 없는 장소")
        XCTAssertEqual(viewData.points[1].address, "부산광역시 중구")
        viewModel.selectPoint(id: 22)
        XCTAssertEqual(viewModel.selectedPoint?.latitude, 35.1796)
    }

    func testMissingOrBlankPlaceNameIsOptionalButNamedPointIsPreserved() async throws {
        for value: Any? in [nil, "", "  \n ", "  부산역  "] {
            let repository = DefaultLogRouteRepository(
                apiService: RoutePlaceNameAPIStub(data: try responseData(placeName: value))
            )
            let route = try await repository.fetchRoute(logID: 2)
            XCTAssertEqual(route.points.count, 2)
            XCTAssertEqual(route.points[0].placeName, "서울역")
            XCTAssertEqual(route.points[1].placeName, value as? String == "  부산역  " ? "부산역" : nil)
        }
    }

    func testWrongPlaceNameTypeStillFailsDecoding() throws {
        let data = try responseData(placeName: 123)
        XCTAssertThrowsError(try JSONDecoder().decode(APIResponse<LogRouteResponseDTO>.self, from: data)) { error in
            guard case let DecodingError.typeMismatch(_, context) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(context.codingPath.last?.stringValue, "placeName")
        }
    }

    func testNullNameDoesNotBypassCoordinateValidation() async throws {
        let repository = DefaultLogRouteRepository(
            apiService: RoutePlaceNameAPIStub(data: try responseData(placeName: NSNull(), latitude: 91))
        )
        do {
            _ = try await repository.fetchRoute(logID: 2)
            XCTFail("잘못된 좌표는 여전히 거부해야 합니다.")
        } catch {
            XCTAssertEqual(error as? LogRouteRepositoryError, .invalidCoordinate(clipID: 22))
        }
    }

    private func responseData(placeName: Any?, latitude: Double = 35.1796) throws -> Data {
        var second: [String: Any] = [
            "clipId": 22, "sequence": 2, "startTimeMillis": 1000, "endTimeMillis": 2000,
            "address": "부산광역시 중구", "latitude": latitude, "longitude": 129.0756,
            "thumbnailUrl": NSNull()
        ]
        second["placeName"] = placeName
        return try JSONSerialization.data(withJSONObject: [
            "successFlag": true, "code": "SUCCESS-002", "message": "조회 성공",
            "data": ["logId": 2, "points": [
                ["clipId": 21, "sequence": 1, "startTimeMillis": 0, "endTimeMillis": 1000,
                 "placeName": "서울역", "address": "서울특별시 용산구",
                 "latitude": 37.5547, "longitude": 126.9707, "thumbnailUrl": NSNull()],
                second
            ]]
        ])
    }
}

private struct RoutePlaceNameAPIStub: LogRouteAPIService {
    let data: Data

    func fetchRoute(logID: Int64) async throws -> LogRouteResponseDTO {
        let response = try JSONDecoder().decode(APIResponse<LogRouteResponseDTO>.self, from: data)
        return try XCTUnwrap(response.data)
    }
}

private struct RoutePlaceNameMediaStub: LogMediaRepository {
    func fetchThumbnailData(logID: Int64, targetSize: MaplogImageTargetSize) async throws -> Data {
        throw URLError(.unsupportedURL)
    }

    func fetchPlaybackFileURL(logID: Int64) async throws -> URL {
        throw URLError(.unsupportedURL)
    }

    func fetchRoutePointThumbnailData(from url: URL, targetSize: MaplogImageTargetSize) async throws -> Data {
        throw URLError(.unsupportedURL)
    }
}
