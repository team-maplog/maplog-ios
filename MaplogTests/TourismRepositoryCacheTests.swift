import XCTest
@testable import Maplog

@MainActor
final class TourismRepositoryCacheTests: XCTestCase {
    func testEveryListCategoryLoadsItsOwnContentAndClearsPreviousPage() async {
        let service = TourismCacheAPIStub()
        let viewModel = TourismListViewModel(tourismRepository: makeRepository(service))
        XCTAssertTrue(viewModel.categoryTabs.contains { $0.category == .food })
        for tab in viewModel.categoryTabs {
            viewModel.selectCategory(tab.category)
            XCTAssertTrue(viewModel.items.isEmpty)
            await viewModel.loadNextPage()
            await viewModel.loadInitialTourisms()
            XCTAssertEqual(service.requestedCategories.last, tab.category)
            XCTAssertEqual(viewModel.tourismState, .content)
            XCTAssertEqual(viewModel.items.first?.categoryTitle, tab.title)
        }
    }

    func testCacheInvalidationOffersRetryInsteadOfLeavingLoadingState() async {
        let service = TourismCacheAPIStub()
        service.invalidated = true
        let repository = makeRepository(service)
        let list = TourismListViewModel(tourismRepository: repository)
        await list.loadInitialTourisms()
        guard case .failed(let listError) = list.tourismState else { return XCTFail("Expected retry") }
        XCTAssertEqual(listError.recoveryAction, .retry)
        let detail = TourismDetailViewModel(tourismID: 1, tourismRepository: repository)
        await detail.load()
        guard case .failed(let detailError) = detail.state else { return XCTFail("Expected retry") }
        XCTAssertEqual(detailError.recoveryAction, .retry)
    }

    func testInvalidCursorRecoveryBypassesCachedFirstPage() async throws {
        let service = TourismCacheAPIStub()
        let viewModel = TourismListViewModel(tourismRepository: makeRepository(service))
        await viewModel.loadInitialTourisms()
        service.rejectCursor = true
        await viewModel.loadNextPage()
        XCTAssertEqual(service.pageCalls, 3)
        XCTAssertEqual(viewModel.tourismState, .content)
        XCTAssertFalse(viewModel.isLoadingNextPage)
        XCTAssertNil(viewModel.nextPageError)
    }

    func testPageKeysSeparateCategoryCursorAndSize() async throws {
        let service = TourismCacheAPIStub()
        let repository = makeRepository(service)
        for _ in 0..<2 {
            _ = try await repository.fetchTourisms(category: .events, cursor: nil, size: 10)
            _ = try await repository.fetchTourisms(category: .events, cursor: nil, size: 20)
            _ = try await repository.fetchTourisms(category: .festival, cursor: nil, size: 10)
            _ = try await repository.fetchTourisms(category: .events, cursor: "next", size: 10)
        }
        XCTAssertEqual(service.pageCalls, 4)
    }

    func testFirstPageReloadInvalidatesRelatedPagesOnly() async throws {
        let service = TourismCacheAPIStub()
        let repository = makeRepository(service)
        _ = try await repository.fetchTourisms(category: .events, cursor: nil, size: 10)
        _ = try await repository.fetchTourisms(category: .events, cursor: "next", size: 10)
        _ = try await repository.fetchTourisms(category: .festival, cursor: nil, size: 10)
        _ = try await repository.fetchTourisms(category: .events, cursor: nil, size: 10, policy: .reload)
        _ = try await repository.fetchTourisms(category: .events, cursor: "next", size: 10)
        _ = try await repository.fetchTourisms(category: .festival, cursor: nil, size: 10)
        XCTAssertEqual(service.pageCalls, 5)
    }

    func testPortraitLookupAndDetailScreenShareDetailResponse() async throws {
        let service = TourismCacheAPIStub()
        let repository = makeRepository(service)
        _ = try await repository.fetchPortraitImage(tourismID: 1)
        _ = try await repository.fetchTourismDetail(tourismID: 1)
        XCTAssertEqual(service.detailCalls, 1)
        _ = try await repository.fetchTourismDetail(tourismID: 1, policy: .reload)
        XCTAssertEqual(service.detailCalls, 2)
        await repository.invalidateCache()
        _ = try await repository.fetchTourismDetail(tourismID: 1)
        XCTAssertEqual(service.detailCalls, 3)
    }

    func testMappingFailureIsNotCached() async throws {
        let service = TourismCacheAPIStub()
        service.startDate = "invalid-date"
        let repository = makeRepository(service)
        do {
            _ = try await repository.fetchTourisms(category: .events, cursor: nil, size: 10)
            XCTFail("Invalid DTO must fail")
        } catch is TourismRepositoryError { }
        service.startDate = "2026-09-12"
        let page = try await repository.fetchTourisms(category: .events, cursor: nil, size: 10)
        XCTAssertEqual(page.tourisms.count, 1)
        XCTAssertEqual(service.pageCalls, 2)
    }

    func testInvalidArgumentsNeverReachService() async throws {
        let service = TourismCacheAPIStub()
        let repository = makeRepository(service)
        for size in [0, 101] {
            do {
                _ = try await repository.fetchTourisms(category: .events, cursor: nil, size: size)
                XCTFail("Invalid size must fail")
            } catch APIError.invalidRequest { }
        }
        do {
            _ = try await repository.fetchTourismDetail(tourismID: 0)
            XCTFail("Invalid ID must fail")
        } catch APIError.invalidRequest { }
        XCTAssertEqual(service.pageCalls, 0)
        XCTAssertEqual(service.detailCalls, 0)
    }

    func testListRefreshFailurePreservesVisibleRowsAndOffersRetry() async throws {
        let service = TourismCacheAPIStub()
        let viewModel = TourismListViewModel(tourismRepository: makeRepository(service))
        await viewModel.loadInitialTourisms()
        XCTAssertEqual(viewModel.items.map(\.id), [1])
        service.shouldFail = true
        await viewModel.refresh()
        XCTAssertEqual(viewModel.tourismState, .content)
        XCTAssertEqual(viewModel.items.map(\.id), [1])
        XCTAssertNotNil(viewModel.refreshError)
        XCTAssertEqual(viewModel.refreshError?.recoveryAction, .retry)
        XCTAssertEqual(service.pageCalls, 2)
        service.shouldFail = false
        await viewModel.refresh()
        XCTAssertNil(viewModel.refreshError)
        XCTAssertEqual(service.pageCalls, 3)
    }

    func testNewListViewModelReusesRepositoryCache() async throws {
        let service = TourismCacheAPIStub()
        let repository = makeRepository(service)
        await TourismListViewModel(tourismRepository: repository).loadInitialTourisms()
        let reopened = TourismListViewModel(tourismRepository: repository)
        await reopened.loadInitialTourisms()
        XCTAssertEqual(reopened.items.map(\.id), [1])
        XCTAssertEqual(service.pageCalls, 1)
    }

    private func makeRepository(_ service: TourismCacheAPIStub) -> DefaultTourismRepository {
        DefaultTourismRepository(apiService: service, imageDataLoader: TourismCacheImageStub())
    }
}

private final class TourismCacheAPIStub: TourismAPIService {
    var requestedCategories: [TourismCategory] = []
    var pageCalls = 0
    var detailCalls = 0
    var startDate: String? = nil
    var shouldFail = false
    var rejectCursor = false
    var invalidated = false
    func fetchTourisms(category: TourismCategory, cursor: String?, size: Int) async throws -> TourismPageDTO {
        requestedCategories.append(category)
        pageCalls += 1
        if invalidated { throw TourismRepositoryError.requestInvalidated }
        if rejectCursor, cursor != nil {
            throw APIError.server(statusCode: 400, response: APIErrorResponse(
                successFlag: false, code: "CURSOR-001", message: "Test invalid cursor", data: nil
            ))
        }
        if shouldFail {
            throw APIError.server(statusCode: 502, response: APIErrorResponse(
                successFlag: false, code: "TOUR-002", message: "Test upstream failure", data: nil
            ))
        }
        return TourismPageDTO(content: [TourismDTO(
            tourismId: 1, name: "테스트 축제", region: "서울", address: nil,
            thumbnailURL: nil, startDate: startDate, endDate: nil, category: category
        )], hasNext: cursor == nil, nextCursor: cursor == nil ? "next" : nil)
    }
    func fetchTourismDetail(tourismID: Int64) async throws -> TourismDetailDTO {
        detailCalls += 1
        if invalidated { throw TourismRepositoryError.requestInvalidated }
        return try JSONDecoder().decode(TourismDetailDTO.self, from: Data("""
        {"tourismId": \(tourismID), "category": "EVENTS", "common": {"name": "축제"}, "repeatInfo": [], "images": []}
        """.utf8))
    }
}
@MainActor
private final class TourismCacheImageStub: ImageDataLoading {
    func imageData(from url: URL, cacheKey: String, targetSize: MaplogImageTargetSize) async throws -> Data {
        XCTFail("This metadata test should not download images")
        return Data()
    }
}
