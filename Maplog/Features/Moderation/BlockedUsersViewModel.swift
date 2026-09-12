import Foundation

@MainActor
final class BlockedUsersViewModel: ObservableObject {
    @Published private(set) var users: [BlockedUser] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var hasNext = false
    @Published private(set) var unblockingID: UUID?
    @Published private(set) var error: ErrorPresentation?
    @Published private(set) var nextPageError: ErrorPresentation?
    private let repository: any ContentModerationRepository
    private var nextPage = 1
    private var didUnblock = false

    init(repository: any ContentModerationRepository) { self.repository = repository }

    func reload() async {
        guard !isLoading, unblockingID == nil else { return }
        isLoading = true
        error = nil
        nextPageError = nil
        defer { isLoading = false }
        do {
            let result = try await repository.fetchBlockedUsers(page: 1)
            try Task.checkCancellation()
            users = result.users
            nextPage = result.page + 1
            hasNext = result.hasNext
            hasLoaded = true
        } catch is CancellationError {
            return
        } catch {
            self.error = LogCommentErrorPolicy.actionPresentation(for: error, actionName: "차단 목록을 조회")
        }
    }

    func loadNextPage() async {
        guard hasNext, !isLoading, unblockingID == nil else { return }
        isLoading = true
        nextPageError = nil
        defer { isLoading = false }
        do {
            let result = try await repository.fetchBlockedUsers(page: nextPage)
            try Task.checkCancellation()
            let existing = Set(users.map(\.id))
            users.append(contentsOf: result.users.filter { !existing.contains($0.id) })
            nextPage = result.page + 1
            hasNext = result.hasNext
        } catch is CancellationError {
            return
        } catch {
            nextPageError = LogCommentErrorPolicy.actionPresentation(for: error, actionName: "차단 목록을 더 조회")
        }
    }

    func unblock(_ user: BlockedUser) async {
        guard unblockingID == nil, !isLoading else { return }
        unblockingID = user.id
        error = nil
        do {
            try await repository.unblockUser(id: user.id)
            users.removeAll { $0.id == user.id }
            didUnblock = true
            // 번호 기반 페이지는 삭제 후 앞당겨진다. 1페이지부터 다시 조회해야 사용자를 건너뛰지 않는다.
            hasNext = false
            unblockingID = nil
            await reload()
        } catch {
            unblockingID = nil
            self.error = LogCommentErrorPolicy.actionPresentation(for: error, actionName: "차단을 해제")
        }
    }

    func finishManagingBlocks() {
        guard didUnblock else { return }
        didUnblock = false
        // 여러 명을 연속 해제할 수 있도록, 목록에서 나갈 때 기존 화면/캐시 갱신을 실행한다.
        NotificationCenter.default.post(name: .maplogUserBlockDidChange, object: nil)
    }
}
