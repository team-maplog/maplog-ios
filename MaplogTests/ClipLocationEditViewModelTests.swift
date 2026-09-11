import XCTest
@testable import Maplog

@MainActor
final class ClipLocationEditViewModelTests: XCTestCase {
    func testMissingLocationStartsUnselectedAndCanBeManuallyResolved() async throws {
        let repository = LocationSelectionRepositoryStub()
        let viewModel = makeViewModel(repository: repository)
        XCTAssertNil(viewModel.selectedLocation)
        XCTAssertFalse(viewModel.canSave)
        XCTAssertFalse(viewModel.canRestoreCapturedLocation)

        viewModel.selectLocation(latitude: 33.4, longitude: 126.5)
        XCTAssertFalse(viewModel.canSave)
        try await waitForResolution(viewModel)

        XCTAssertTrue(viewModel.canSave)
        XCTAssertEqual(viewModel.makeUpdatedClipLocation().location?.latitude, 33.4)
        XCTAssertEqual(viewModel.makeUpdatedClipLocation().location?.address, "제주 테스트 주소")
    }

    func testFailedAddressResolutionCannotBeSavedAndCanRetry() async throws {
        let repository = LocationSelectionRepositoryStub()
        repository.shouldFail = true
        let viewModel = makeViewModel(repository: repository)
        viewModel.selectLocation(latitude: 33.4, longitude: 126.5)
        try await waitForResolution(viewModel)
        XCTAssertFalse(viewModel.canSave)
        XCTAssertNotNil(viewModel.locationResolutionError)

        repository.shouldFail = false
        viewModel.retryLocationResolution()
        try await waitForResolution(viewModel)
        XCTAssertTrue(viewModel.canSave)
        XCTAssertNil(viewModel.locationResolutionError)
    }

    func testLatestSelectionWinsWhenCoordinatesChangeQuickly() async throws {
        let viewModel = makeViewModel(repository: LocationSelectionRepositoryStub())
        viewModel.selectLocation(latitude: 33.4, longitude: 126.5)
        viewModel.selectLocation(latitude: 35.1, longitude: 129.0)
        try await waitForResolution(viewModel)
        XCTAssertEqual(viewModel.selectedLocation?.latitude, 35.1)
        XCTAssertEqual(viewModel.selectedLocation?.longitude, 129.0)
    }

    func testSearchSelectionMovesPinAndManualRefinementUsesNewAddress() async throws {
        let viewModel = makeViewModel(repository: LocationSelectionRepositoryStub())
        viewModel.searchQuery = "장소"
        viewModel.searchLocations()
        try await waitForSearch(viewModel)
        let result = try XCTUnwrap(viewModel.searchResults.first)
        viewModel.selectSearchResult(result)
        XCTAssertEqual(viewModel.mapLocation.latitude, 35.1)
        XCTAssertFalse(viewModel.canSave, "검색 주소를 검증 없이 저장하면 안 됩니다")
        try await waitForResolution(viewModel)
        XCTAssertEqual(viewModel.selectedLocation?.name, "검색한 장소")
        XCTAssertTrue(viewModel.canSave)
        viewModel.selectLocation(latitude: 35.1002, longitude: 129.0003)
        XCTAssertNil(viewModel.selectedLocation?.name, "손으로 옮긴 좌표에 이전 상호를 남기지 않습니다")
        try await waitForResolution(viewModel)
        XCTAssertEqual(viewModel.makeUpdatedClipLocation().location?.latitude, 35.1002)
    }

    func testFailedSearchCanRetryWithoutChangingSelectedPin() async throws {
        let repository = LocationSelectionRepositoryStub()
        repository.shouldFail = true
        let viewModel = makeViewModel(repository: repository)
        viewModel.searchQuery = "장소"
        viewModel.searchLocations()
        try await waitForSearch(viewModel)
        XCTAssertNotNil(viewModel.searchMessage)
        XCTAssertNil(viewModel.selectedLocation)
        repository.shouldFail = false
        viewModel.searchLocations()
        try await waitForSearch(viewModel)
        XCTAssertNil(viewModel.searchMessage)
        XCTAssertEqual(viewModel.searchResults.count, 1)
    }

    func testEditingQueryCancelsAndClearsPreviousResults() async throws {
        let viewModel = makeViewModel(repository: LocationSelectionRepositoryStub())
        viewModel.searchQuery = "첫 검색"
        viewModel.searchLocations()
        viewModel.searchQuery = "새 검색"
        await Task.yield()
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertTrue(viewModel.searchResults.isEmpty)
        XCTAssertNil(viewModel.searchMessage)
        XCTAssertNil(viewModel.selectedLocation)
    }

    private func waitForSearch(_ viewModel: ClipLocationEditViewModel) async throws {
        for _ in 0..<200 where viewModel.isSearching {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertFalse(viewModel.isSearching)
    }

    private func waitForResolution(_ viewModel: ClipLocationEditViewModel) async throws {
        for _ in 0..<200 where viewModel.isResolvingLocation {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertFalse(viewModel.isResolvingLocation, "주소 조회가 제한 시간 안에 완료되어야 합니다")
    }

    private func makeViewModel(repository: any LogLocationRepository) -> ClipLocationEditViewModel {
        ClipLocationEditViewModel(
            clipLocation: LogComposeClipLocationDraft(
                clipID: UUID(), videoURL: URL(fileURLWithPath: "/tmp/clip.mov"),
                startTime: 0, endTime: 3, location: nil
            ),
            logLocationRepository: repository
        )
    }
}

private final class LocationSelectionRepositoryStub: LogLocationRepository {
    func searchLocations(query: String, near location: LogLocationDraft) async throws -> [LogLocationDraft] {
        if shouldFail { throw URLError(.notConnectedToInternet) }
        return [LogLocationDraft(latitude: 35.1, longitude: 129.0, name: "검색한 장소", address: "검색 주소")]
    }

    var shouldFail = false
    func resolveLocation(latitude: Double, longitude: Double) async throws -> ResolvedLogLocation {
        if shouldFail { throw URLError(.notConnectedToInternet) }
        return ResolvedLogLocation(latitude: latitude, longitude: longitude, name: nil, address: "제주 테스트 주소")
    }
}
