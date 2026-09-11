import Foundation

/// 발행된 게시물의 장소 선택 초안. 주소 확인이 끝난 위치만 상위 수정 화면에 전달합니다.
@MainActor
final class LogPlaceEditViewModel: ObservableObject {
    @Published var searchQuery = "" {
        didSet { cancelSearch() }
    }
    @Published private(set) var location: LogLocationDraft
    @Published private(set) var searchResults: [LogLocationDraft] = []
    @Published private(set) var searchMessage: String?
    @Published private(set) var isSearching = false
    @Published private(set) var isResolving = false
    @Published private(set) var locationError: ErrorPresentation?

    private let repository: any LogLocationRepository
    private var searchTask: Task<Void, Never>?
    private var resolveTask: Task<Void, Never>?
    private var searchID = UUID()
    private var selectionID = UUID()

    init(location: LogLocationDraft, repository: any LogLocationRepository) {
        self.location = location
        self.repository = repository
    }

    var canConfirm: Bool {
        !isResolving && locationError == nil && location.validatedReelLocation != nil
    }

    func search() {
        cancelSearch()
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        let id = UUID()
        searchID = id
        isSearching = true
        let near = location
        searchTask = Task { [weak self] in
            guard let self else { return }
            defer { if self.searchID == id { self.isSearching = false } }
            do {
                let results = try await self.repository.searchLocations(query: query, near: near)
                guard !Task.isCancelled, self.searchID == id else { return }
                self.searchResults = results
                self.searchMessage = results.isEmpty ? "검색 결과가 없어요. 다른 장소명이나 주소로 검색해 주세요." : nil
            } catch {
                guard !Task.isCancelled, self.searchID == id else { return }
                self.searchMessage = "장소를 검색하지 못했어요. 연결을 확인하고 다시 검색해 주세요."
            }
        }
    }

    func select(_ selected: LogLocationDraft) {
        cancelSearch()
        resolveTask?.cancel()
        let id = UUID()
        selectionID = id
        // 새 핀에 이전 주소가 남아 저장되는 것을 막고, 서버에서 주소를 다시 확인합니다.
        location = LogLocationDraft(latitude: selected.latitude, longitude: selected.longitude, name: selected.name)
        locationError = nil
        isResolving = true
        resolveTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
                let result = try await self.repository.resolveLocation(
                    latitude: selected.latitude, longitude: selected.longitude
                )
                guard !Task.isCancelled, self.selectionID == id else { return }
                self.location = LogLocationDraft(
                    latitude: result.latitude, longitude: result.longitude,
                    name: selected.name ?? result.name, address: result.address
                )
                if self.location.validatedReelLocation == nil {
                    self.locationError = ErrorPresentation(message: "이 위치의 주소를 확인할 수 없어요. 다른 위치를 선택해 주세요.", recoveryAction: .none)
                }
                self.isResolving = false
            } catch {
                guard !Task.isCancelled, self.selectionID == id else { return }
                self.isResolving = false
                self.locationError = LogLocationErrorPolicy.presentation(for: error)
            }
        }
    }

    func resolveIfNeeded() {
        if location.validatedReelLocation == nil { select(location) }
    }

    func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
        searchID = UUID()
        isSearching = false
        searchResults = []
        searchMessage = nil
    }

    func cancel() {
        cancelSearch()
        resolveTask?.cancel()
        resolveTask = nil
        selectionID = UUID()
        isResolving = false
    }
}
