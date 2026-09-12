import Foundation

enum NotificationInboxState: Equatable {
    case idle
    case initialLoading
    case content
    case empty
    case failed(ErrorPresentation)
}

@MainActor
final class NotificationInboxViewModel: ObservableObject {
    @Published private(set) var state: NotificationInboxState = .idle
    @Published private(set) var notifications: [MaplogNotification] = []
    @Published private(set) var isLoadingNextPage = false
    @Published private(set) var nextPageError: ErrorPresentation?

    private let repository: any NotificationRepository
    private let pageSize = 20
    private var nextCursor: String?
    private var hasNextPage = false

    init(repository: any NotificationRepository) {
        self.repository = repository
    }

    func loadIfNeeded() async {
        guard state == .idle else {
            return
        }

        await reload()
    }

    func reload() async {
        guard state != .initialLoading else {
            return
        }

        let preservesVisibleContent = state == .content
        if !preservesVisibleContent {
            notifications = []
            nextCursor = nil
            hasNextPage = false
            nextPageError = nil
            state = .initialLoading
        }

        do {
            let page = try await repository.fetchNotifications(
                cursor: nil,
                size: pageSize
            )

            notifications = page.notifications
            nextCursor = page.nextCursor
            hasNextPage = page.hasNext
            nextPageError = nil
            state = page.notifications.isEmpty ? .empty : .content
        } catch is CancellationError {
            if !preservesVisibleContent {
                state = .idle
            }
        } catch {
            if preservesVisibleContent {
                nextPageError = NotificationErrorPolicy.presentation(for: error)
            } else {
                state = .failed(NotificationErrorPolicy.presentation(for: error))
            }
        }
    }

    func loadNextPageIfNeeded(for notification: MaplogNotification) async {
        guard notification.id == notifications.last?.id else {
            return
        }

        await loadNextPage()
    }

    func retryNextPage() async {
        await loadNextPage()
    }

    private func loadNextPage() async {
        guard state == .content,
              hasNextPage,
              let nextCursor,
              !isLoadingNextPage
        else {
            return
        }

        isLoadingNextPage = true
        nextPageError = nil
        defer { isLoadingNextPage = false }

        do {
            let page = try await repository.fetchNotifications(
                cursor: nextCursor,
                size: pageSize
            )

            notifications.append(contentsOf: page.notifications)
            self.nextCursor = page.nextCursor
            hasNextPage = page.hasNext
        } catch is CancellationError {
            return
        } catch {
            if NotificationErrorPolicy.isCursorInvalid(error) {
                await reload()
                return
            }

            nextPageError = NotificationErrorPolicy.presentation(for: error)
        }
    }
}
