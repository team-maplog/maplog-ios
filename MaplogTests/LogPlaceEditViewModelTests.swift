import XCTest
@testable import Maplog

@MainActor
final class LogPlaceEditViewModelTests: XCTestCase {
    func testSearchMovesPinAndManualMoveClearsPreviousPlaceName() async throws {
        let repository = PlaceEditRepositoryStub()
        let vm = makeViewModel(repository)
        vm.searchQuery = "해운대"
        vm.search()
        try await wait { !vm.isSearching }
        let result = try XCTUnwrap(vm.searchResults.first)
        vm.select(result)
        XCTAssertEqual(vm.location.latitude, 35.16)
        XCTAssertNil(vm.location.address)
        XCTAssertFalse(vm.canConfirm)
        try await wait { !vm.isResolving }
        XCTAssertTrue(vm.canConfirm)
        XCTAssertEqual(vm.location.name, "해운대")
        vm.select(LogLocationDraft(latitude: 35.17, longitude: 129.17))
        XCTAssertNil(vm.location.name)
        XCTAssertFalse(vm.canConfirm)
        try await wait { !vm.isResolving }
        XCTAssertEqual(vm.location.latitude, 35.17)
        XCTAssertEqual(vm.location.address, "확인한 주소 35.17")
    }

    func testFailedResolutionCannotSaveAndCanRetry() async throws {
        let repository = PlaceEditRepositoryStub()
        repository.fails = true
        let vm = makeViewModel(repository)
        vm.select(LogLocationDraft(latitude: 35.16, longitude: 129.16))
        try await wait { !vm.isResolving }
        XCTAssertFalse(vm.canConfirm)
        XCTAssertNotNil(vm.locationError)
        repository.fails = false
        vm.select(vm.location)
        try await wait { !vm.isResolving }
        XCTAssertTrue(vm.canConfirm)
        XCTAssertNil(vm.locationError)
    }

    func testLateAddressResponseCannotReplaceNewerPin() async throws {
        let repository = PlaceEditRepositoryStub()
        repository.delaysFirstResult = true
        let vm = makeViewModel(repository)
        vm.select(LogLocationDraft(latitude: 35.1, longitude: 129.1))
        try await wait { repository.resolveCalls == 1 }
        vm.select(LogLocationDraft(latitude: 35.2, longitude: 129.2))
        try await wait { !vm.isResolving }
        // 스텁은 취소를 무시하고 오래된 응답을 반환합니다.
        try await Task.sleep(nanoseconds: 650_000_000)
        XCTAssertEqual(vm.location.latitude, 35.2)
        XCTAssertEqual(vm.location.address, "확인한 주소 35.2")
    }

    func testCancellationDoesNotConfirmUnresolvedLocation() async throws {
        let vm = makeViewModel(PlaceEditRepositoryStub())
        vm.select(LogLocationDraft(latitude: 35.1, longitude: 129.1))
        vm.cancel()
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertFalse(vm.canConfirm)
        XCTAssertNil(vm.location.address)
    }

    func testInvalidCoordinatesAndBlankAddressAreRejected() {
        XCTAssertNil(LogLocationDraft(latitude: .nan, longitude: 127, address: "서울").validatedReelLocation)
        XCTAssertNil(LogLocationDraft(latitude: 37, longitude: 181, address: "서울").validatedReelLocation)
        XCTAssertNil(LogLocationDraft(latitude: 37, longitude: 127, address: "  ").validatedReelLocation)
    }

    private func makeViewModel(_ repository: PlaceEditRepositoryStub) -> LogPlaceEditViewModel {
        LogPlaceEditViewModel(location: LogLocationDraft(latitude: 37.54, longitude: 127.04, address: "서울 성동구"), repository: repository)
    }

    private func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<150 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("장소 선택 작업이 완료되지 않았습니다")
    }
}

@MainActor
private final class PlaceEditRepositoryStub: LogLocationRepository {
    var fails = false
    var delaysFirstResult = false
    var resolveCalls = 0

    func searchLocations(query: String, near location: LogLocationDraft) async throws -> [LogLocationDraft] {
        [LogLocationDraft(latitude: 35.16, longitude: 129.16, name: "해운대", address: "검색 주소")]
    }

    func resolveLocation(latitude: Double, longitude: Double) async throws -> ResolvedLogLocation {
        resolveCalls += 1
        if delaysFirstResult && resolveCalls == 1 {
            await withCheckedContinuation { continuation in
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    continuation.resume()
                }
            }
        }
        if fails { throw APIError.missingData }
        return ResolvedLogLocation(latitude: latitude, longitude: longitude, name: nil, address: "확인한 주소 \(latitude)")
    }
}
