import Foundation
import XCTest
@testable import Maplog

@MainActor
final class HomeSearchViewModelTests: XCTestCase {
    func testSubmitSearchThenLoadNextPageAppendsItems() async {
        let repository = HomeSearchRepositoryStub(
            pagesByCursor: [
                nil: makePage(
                    items: [makeItem(id: 1)],
                    hasNext: true,
                    nextCursor: "next"
                ),
                "next": makePage(
                    items: [makeItem(id: 2)],
                    hasNext: false,
                    nextCursor: nil
                )
            ]
        )
        let viewModel = HomeSearchViewModel(
            searchRepository: repository,
            logMediaRepository: LogMediaRepositoryStub(),
            logReelRepository: LogReelRepositoryStub()
        )

        viewModel.updateQuery("성수")
        await viewModel.submitSearch()

        XCTAssertEqual(viewModel.state, .content)
        XCTAssertEqual(viewModel.items.map(\.serverID), [1])

        await viewModel.loadNextPageIfNeeded(for: makeItem(id: 1))

        XCTAssertEqual(viewModel.items.map(\.serverID), [1, 2])
        XCTAssertEqual(repository.requestedCursors, [nil, "next"])
    }

    func testChangingScopeStartsNewSearchWithoutOldCursor() async {
        let repository = HomeSearchRepositoryStub(
            pagesByScope: [
                .all: makePage(
                    items: [makeItem(id: 1)],
                    hasNext: true,
                    nextCursor: "all-next"
                ),
                .tourism: makePage(
                    scope: .tourism,
                    items: [makeItem(id: 2, kind: .tourism)],
                    hasNext: false,
                    nextCursor: nil
                )
            ]
        )
        let viewModel = HomeSearchViewModel(
            searchRepository: repository,
            logMediaRepository: LogMediaRepositoryStub(),
            logReelRepository: LogReelRepositoryStub()
        )

        viewModel.updateQuery("성수")
        await viewModel.submitSearch()
        await viewModel.selectScope(.tourism)

        XCTAssertEqual(viewModel.selectedScope, .tourism)
        XCTAssertEqual(viewModel.items.map(\.kind), [.tourism])
        XCTAssertTrue(
            repository.requests.contains {
                $0.scope == .tourism && $0.cursor == nil && $0.size == 20
            }
        )
    }

    func testBlankOrTooLongQueryDoesNotRequestSearch() async {
        let repository = HomeSearchRepositoryStub()
        let viewModel = HomeSearchViewModel(
            searchRepository: repository,
            logMediaRepository: LogMediaRepositoryStub(),
            logReelRepository: LogReelRepositoryStub()
        )

        viewModel.updateQuery("   ")
        await viewModel.submitSearch()

        viewModel.updateQuery(String(repeating: "가", count: 51))
        await viewModel.submitSearch()

        XCTAssertEqual(repository.requests, [])
        XCTAssertEqual(
            viewModel.inputValidationMessage,
            "검색어는 50자 이하로 입력해 주세요."
        )
    }

    func testInitialExploreLoadsRecentLogs() async {
        let recentLog = LogReel(
            id: 7,
            author: LogReelAuthor(
                id: UUID(),
                nickname: "maplogger",
                profileImageURL: nil
            ),
            caption: "성수 산책",
            tags: [],
            address: "서울 성동구 성수동",
            thumbnailURL: URL(string: "https://example.com/thumbnail.jpg"),
            playbackURL: nil,
            publishedAt: Date(),
            viewCount: 0,
            clips: [],
            likeCount: 0,
            commentCount: 0,
            isLikedByViewer: false,
            isSavedByViewer: false
        )
        let viewModel = HomeSearchViewModel(
            searchRepository: HomeSearchRepositoryStub(),
            logMediaRepository: LogMediaRepositoryStub(),
            logReelRepository: LogReelRepositoryStub(reels: [recentLog])
        )

        await viewModel.loadRecentLogsIfNeeded()

        XCTAssertEqual(viewModel.exploreState, .content)
        XCTAssertEqual(viewModel.recentLogs, [recentLog])
    }

    private func makePage(
        scope: HomeSearchScope = .all,
        items: [HomeSearchItem],
        hasNext: Bool,
        nextCursor: String?
    ) -> HomeSearchPage {
        HomeSearchPage(
            query: "성수",
            scope: scope,
            totalCount: items.count,
            items: items,
            hasNext: hasNext,
            nextCursor: nextCursor
        )
    }

    private func makeItem(
        id: Int64,
        kind: HomeSearchItem.Kind = .log
    ) -> HomeSearchItem {
        HomeSearchItem(
            kind: kind,
            serverID: id,
            title: "성수 검색 결과",
            subtitle: "서울 성동구 성수동",
            thumbnailURL: nil,
            publishedAt: nil,
            author: nil,
            likeCount: nil,
            commentCount: nil,
            category: nil,
            startDate: nil,
            endDate: nil
        )
    }
}

private final class HomeSearchRepositoryStub: HomeSearchRepository {
    private let pagesByCursor: [String?: HomeSearchPage]
    private let pagesByScope: [HomeSearchScope: HomeSearchPage]
    private(set) var requests: [HomeSearchRequest] = []

    var requestedCursors: [String?] {
        requests
            .filter { $0.size == 20 }
            .map(\.cursor)
    }

    init(
        pagesByCursor: [String?: HomeSearchPage] = [:],
        pagesByScope: [HomeSearchScope: HomeSearchPage] = [:]
    ) {
        self.pagesByCursor = pagesByCursor
        self.pagesByScope = pagesByScope
    }

    func search(
        request: HomeSearchRequest
    ) async throws -> HomeSearchPage {
        requests.append(request)

        if request.size == 1 {
            return HomeSearchPage(
                query: request.query,
                scope: request.scope,
                totalCount: 1,
                items: [],
                hasNext: false,
                nextCursor: nil
            )
        }

        if let page = pagesByCursor[request.cursor] {
            return page
        }

        if let page = pagesByScope[request.scope] {
            return page
        }

        return HomeSearchPage(
            query: request.query,
            scope: request.scope,
            totalCount: 0,
            items: [],
            hasNext: false,
            nextCursor: nil
        )
    }
}

private final class LogMediaRepositoryStub: LogMediaRepository {
    func fetchThumbnailData(logID: Int64) async throws -> Data {
        Data()
    }

    func fetchPlaybackFileURL(logID: Int64) async throws -> URL {
        URL(fileURLWithPath: "/tmp/log.mov")
    }

    func fetchRoutePointThumbnailData(from url: URL) async throws -> Data {
        Data()
    }
}

private final class LogReelRepositoryStub: LogReelRepository {
    private let reels: [LogReel]

    init(reels: [LogReel] = []) {
        self.reels = reels
    }

    func fetchReels(
        cursor: String?,
        size: Int
    ) async throws -> LogReelPage {
        LogReelPage(
            reels: reels,
            hasNext: false,
            nextCursor: nil
        )
    }

    func fetchSavedLogs(
        cursor: String?,
        size: Int
    ) async throws -> LogReelPage {
        LogReelPage(
            reels: [],
            hasNext: false,
            nextCursor: nil
        )
    }
}
