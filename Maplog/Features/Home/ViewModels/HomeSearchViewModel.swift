import Foundation

enum HomeSearchState: Equatable {
    case idle
    case initialLoading
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

    private let searchRepository: any HomeSearchRepository
    private let logMediaRepository: any LogMediaRepository
    private let pageSize = 20

    private var nextCursor: String?
    private var hasNext = false
    private var activeQuery = ""
    private var activeRequestID = UUID()

    init(
        searchRepository: any HomeSearchRepository,
        logMediaRepository: any LogMediaRepository
    ) {
        self.searchRepository = searchRepository
        self.logMediaRepository = logMediaRepository
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

    func loadNextPageIfNeeded(
        for item: HomeSearchItem
    ) async {
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
            // 카드 이미지 하나의 실패는 검색 결과 전체 실패가 아니므로 placeholder를 유지합니다.
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
