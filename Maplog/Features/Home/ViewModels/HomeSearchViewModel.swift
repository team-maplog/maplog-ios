import Foundation

enum HomeSearchState: Equatable {
    case idle
    case initialLoading
    case content
    case empty
    case failed(ErrorPresentation)
}

enum HomeSearchExploreState: Equatable {
    case idle
    case loading
    case content
    case empty
    case failed(ErrorPresentation)
}

@MainActor
final class HomeSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var selectedScope: HomeSearchScope = .all
    @Published private(set) var state: HomeSearchState = .idle
    @Published private(set) var items: [HomeSearchItem] = []
    @Published private(set) var scopeCounts: [HomeSearchScope: Int] = [:]
    @Published private(set) var isLoadingNextPage = false
    @Published private(set) var nextPageError: ErrorPresentation?
    @Published private(set) var thumbnailDataByItemID: [String: Data] = [:]
    @Published private(set) var loadingThumbnailItemIDs = Set<String>()
    @Published private(set) var isPrefetchingSearchThumbnails = false

    @Published private(set) var exploreState: HomeSearchExploreState = .idle
    @Published private(set) var recentLogs: [LogReel] = []
    @Published private(set) var recentThumbnailDataByLogID: [Int64: Data] = [:]
    @Published private(set) var loadingRecentThumbnailLogIDs = Set<Int64>()
    @Published private(set) var isPrefetchingRecentThumbnails = false

    private let searchRepository: any HomeSearchRepository
    private let logMediaRepository: any LogMediaRepository
    private let logReelRepository: any LogReelRepository
    private let pageSize = 20
    private let recentLogPageSize = 24

    private var nextCursor: String?
    private var hasNext = false
    private var activeQuery = ""
    private var activeRequestID = UUID()

    init(
        searchRepository: any HomeSearchRepository,
        logMediaRepository: any LogMediaRepository,
        logReelRepository: any LogReelRepository
    ) {
        self.searchRepository = searchRepository
        self.logMediaRepository = logMediaRepository
        self.logReelRepository = logReelRepository
    }

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var inputValidationMessage: String? {
        if trimmedQuery.isEmpty {
            return nil
        }

        guard trimmedQuery.count <= 50 else {
            return "검색어는 50자 이하로 입력해 주세요."
        }

        return nil
    }

    var canSubmit: Bool {
        !trimmedQuery.isEmpty && inputValidationMessage == nil
    }

    func updateQuery(_ value: String) {
        query = value

        // 이전 검색의 cursor는 새 검색어와 절대 섞이면 안 됩니다.
        guard trimmedQuery != activeQuery else {
            return
        }

        invalidateResults()
    }

    func selectScope(_ scope: HomeSearchScope) async {
        guard selectedScope != scope else {
            return
        }

        selectedScope = scope
        invalidateResults()

        guard canSubmit else {
            return
        }

        await loadInitialSearch()
    }

    func submitSearch() async {
        guard canSubmit else {
            return
        }

        await loadInitialSearch()
    }

    func retryInitialSearch() async {
        guard canSubmit else {
            return
        }

        await loadInitialSearch()
    }

    func loadRecentLogsIfNeeded() async {
        guard exploreState == .idle else {
            return
        }

        exploreState = .loading

        do {
            let page = try await logReelRepository.fetchReels(
                cursor: nil,
                size: recentLogPageSize
            )

            guard !Task.isCancelled else {
                return
            }

            recentLogs = page.reels
            exploreState = page.reels.isEmpty ? .empty : .content
        } catch is CancellationError {
            exploreState = .idle
        } catch {
            exploreState = .failed(
                HomeSearchErrorPolicy.explorePresentation(for: error)
            )
        }
    }

    func retryRecentLogs() async {
        exploreState = .idle
        await loadRecentLogsIfNeeded()
    }

    func loadNextPageIfNeeded(
        for item: HomeSearchItem
    ) async {
        // 이미지 로딩과 관계없이 마지막 검색 결과에서 다음 페이지를 요청합니다.
        guard item.id == items.last?.id else {
            return
        }

        await loadNextPage()
    }

    func retryNextPage() async {
        guard nextPageError != nil else {
            return
        }

        await loadNextPage()
    }

    func thumbnailData(for item: HomeSearchItem) -> Data? {
        thumbnailDataByItemID[item.id]
    }

    func isLoadingThumbnail(for item: HomeSearchItem) -> Bool {
        loadingThumbnailItemIDs.contains(item.id)
    }

    func loadThumbnails(for items: [HomeSearchItem]) async {
        guard !items.isEmpty else {
            return
        }

        isPrefetchingSearchThumbnails = true

        defer {
            isPrefetchingSearchThumbnails = false
        }

        for item in items {
            guard !Task.isCancelled else {
                return
            }

            await loadThumbnail(for: item)
        }
    }

    func loadThumbnail(for item: HomeSearchItem) async {
        guard let thumbnailURL = item.thumbnailURL,
              thumbnailDataByItemID[item.id] == nil,
              !loadingThumbnailItemIDs.contains(item.id)
        else {
            return
        }

        loadingThumbnailItemIDs.insert(item.id)

        defer {
            loadingThumbnailItemIDs.remove(item.id)
        }

        do {
            let data = try await logMediaRepository
                .fetchRoutePointThumbnailData(from: thumbnailURL)

            guard !Task.isCancelled else {
                return
            }

            thumbnailDataByItemID[item.id] = data
        } catch {
            // 사진 요청이 실패해도 장소명과 주소로 결과에 접근할 수 있습니다.
            return
        }
    }

    func recentThumbnailData(for log: LogReel) -> Data? {
        recentThumbnailDataByLogID[log.id]
    }

    func loadRecentThumbnails() async {
        guard !recentLogs.isEmpty else {
            return
        }

        isPrefetchingRecentThumbnails = true

        defer {
            isPrefetchingRecentThumbnails = false
        }

        for log in recentLogs {
            guard !Task.isCancelled else {
                return
            }

            await loadRecentThumbnail(for: log)
        }
    }

    private func loadRecentThumbnail(for log: LogReel) async {
        guard log.thumbnailURL != nil,
              recentThumbnailDataByLogID[log.id] == nil,
              !loadingRecentThumbnailLogIDs.contains(log.id)
        else {
            return
        }

        loadingRecentThumbnailLogIDs.insert(log.id)

        defer {
            loadingRecentThumbnailLogIDs.remove(log.id)
        }

        do {
            let data = try await logMediaRepository.fetchThumbnailData(
                logID: log.id,
                targetSize: .listThumbnail
            )

            guard !Task.isCancelled else {
                return
            }

            recentThumbnailDataByLogID[log.id] = data
        } catch {
            // 최근 로그도 이미지를 정상적으로 받은 카드만 보여 줍니다.
            return
        }
    }

    private func loadInitialSearch() async {
        let requestedQuery = trimmedQuery
        let requestedScope = selectedScope
        let requestID = UUID()

        activeRequestID = requestID
        activeQuery = requestedQuery
        items = []
        nextCursor = nil
        hasNext = false
        nextPageError = nil
        isLoadingNextPage = false
        scopeCounts = [:]
        thumbnailDataByItemID = [:]
        loadingThumbnailItemIDs = []
        isPrefetchingSearchThumbnails = false
        state = .initialLoading

        do {
            let page = try await searchRepository.search(
                request: HomeSearchRequest(
                    query: requestedQuery,
                    scope: requestedScope,
                    cursor: nil,
                    size: pageSize,
                    sort: .relevance
                )
            )

            guard isCurrent(
                requestID: requestID,
                query: requestedQuery,
                scope: requestedScope
            ) else {
                return
            }

            applyInitial(page)
            refreshScopeCounts(
                for: requestedQuery,
                selectedScope: requestedScope,
                requestID: requestID
            )
        } catch is CancellationError {
            return
        } catch {
            guard isCurrent(
                requestID: requestID,
                query: requestedQuery,
                scope: requestedScope
            ) else {
                return
            }

            state = .failed(
                HomeSearchErrorPolicy.initialPresentation(for: error)
            )
        }
    }

    private func loadNextPage() async {
        guard state == .content,
              !isLoadingNextPage,
              hasNext,
              let nextCursor
        else {
            return
        }

        let requestedQuery = activeQuery
        let requestedScope = selectedScope
        let requestID = activeRequestID

        isLoadingNextPage = true
        nextPageError = nil

        defer {
            isLoadingNextPage = false
        }

        do {
            let page = try await searchRepository.search(
                request: HomeSearchRequest(
                    query: requestedQuery,
                    scope: requestedScope,
                    cursor: nextCursor,
                    size: pageSize,
                    sort: .relevance
                )
            )

            guard isCurrent(
                requestID: requestID,
                query: requestedQuery,
                scope: requestedScope
            ) else {
                return
            }

            items.append(contentsOf: page.items)
            self.nextCursor = page.nextCursor
            hasNext = page.hasNext
            isPrefetchingSearchThumbnails = !page.items.isEmpty
        } catch is CancellationError {
            return
        } catch {
            guard isCurrent(
                requestID: requestID,
                query: requestedQuery,
                scope: requestedScope
            ) else {
                return
            }

            // 다른 검색 조건의 cursor를 재시도하지 않도록, 같은 조건으로 첫 페이지부터 다시 시작합니다.
            if HomeSearchErrorPolicy.isCursorInvalid(error) {
                await loadInitialSearch()
                return
            }

            nextPageError = HomeSearchErrorPolicy.nextPagePresentation(
                for: error
            )
        }
    }

    private func applyInitial(_ page: HomeSearchPage) {
        items = page.items
        nextCursor = page.nextCursor
        hasNext = page.hasNext
        isPrefetchingSearchThumbnails = !page.items.isEmpty

        if let totalCount = page.totalCount {
            scopeCounts[selectedScope] = totalCount
        }

        state = page.items.isEmpty ? .empty : .content
    }

    private func refreshScopeCounts(
        for query: String,
        selectedScope: HomeSearchScope,
        requestID: UUID
    ) {
        Task {
            // 선택 탭은 이미 목록 API 응답의 totalCount를 받았으므로,
            // 나머지 두 탭만 size=1 요청으로 숫자를 보완합니다.
            for scope in HomeSearchScope.allCases where scope != selectedScope {
                let page = await countPage(query: query, scope: scope)

                guard activeRequestID == requestID,
                      activeQuery == query
                else {
                    return
                }

                if let totalCount = page?.totalCount {
                    scopeCounts[scope] = totalCount
                }
            }
        }
    }

    private func countPage(
        query: String,
        scope: HomeSearchScope
    ) async -> HomeSearchPage? {
        try? await searchRepository.search(
            request: HomeSearchRequest(
                query: query,
                scope: scope,
                cursor: nil,
                size: 1,
                sort: .relevance
            )
        )
    }

    private func invalidateResults() {
        activeRequestID = UUID()
        activeQuery = ""
        items = []
        nextCursor = nil
        hasNext = false
        nextPageError = nil
        isLoadingNextPage = false
        thumbnailDataByItemID = [:]
        loadingThumbnailItemIDs = []
        isPrefetchingSearchThumbnails = false
        state = .idle
    }

    private func isCurrent(
        requestID: UUID,
        query: String,
        scope: HomeSearchScope
    ) -> Bool {
        !Task.isCancelled
            && activeRequestID == requestID
            && activeQuery == query
            && selectedScope == scope
    }
}
