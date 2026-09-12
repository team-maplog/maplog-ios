import Foundation
import XCTest
@testable import Maplog

@MainActor
final class NotificationInboxViewModelTests: XCTestCase {
    func testLoadsFirstPageThenAppendsNextPage() async {
        let firstNotification = makeNotification(id: "first")
        let secondNotification = makeNotification(id: "second")
        let repository = NotificationRepositoryStub(
            pages: [
                MaplogNotificationPage(
                    notifications: [firstNotification],
                    hasNext: true,
                    nextCursor: "next"
                ),
                MaplogNotificationPage(
                    notifications: [secondNotification],
                    hasNext: false,
                    nextCursor: nil
                )
            ]
        )
        let viewModel = NotificationInboxViewModel(repository: repository)

        await viewModel.loadIfNeeded()
        await viewModel.loadNextPageIfNeeded(for: firstNotification)

        XCTAssertEqual(viewModel.state, .content)
        XCTAssertEqual(viewModel.notifications.map(\.id), ["first", "second"])
        XCTAssertEqual(repository.requestedCursors, [nil, "next"])
    }

    func testNextPageFailureKeepsExistingNotifications() async {
        let notification = makeNotification(id: "first")
        let repository = NotificationRepositoryStub(
            results: [
                .success(
                    MaplogNotificationPage(
                        notifications: [notification],
                        hasNext: true,
                        nextCursor: "next"
                    )
                ),
                .failure(URLError(.notConnectedToInternet))
            ]
        )
        let viewModel = NotificationInboxViewModel(repository: repository)

        await viewModel.loadIfNeeded()
        await viewModel.loadNextPageIfNeeded(for: notification)

        XCTAssertEqual(viewModel.state, .content)
        XCTAssertEqual(viewModel.notifications, [notification])
        XCTAssertNotNil(viewModel.nextPageError)
    }

    private func makeNotification(id: String) -> MaplogNotification {
        MaplogNotification(
            id: id,
            kind: .comment,
            title: "여행자님이 댓글을 남겼어요.",
            message: "성수 산책 너무 좋아 보여요!",
            actor: nil,
            createdAt: .now,
            isRead: false,
            destination: .logDetail(logID: 10, commentID: nil)
        )
    }
}

private final class NotificationRepositoryStub: NotificationRepository {
    private var results: [Result<MaplogNotificationPage, Error>]
    private(set) var requestedCursors: [String?] = []

    init(pages: [MaplogNotificationPage]) {
        results = pages.map(Result.success)
    }

    init(results: [Result<MaplogNotificationPage, Error>]) {
        self.results = results
    }

    func registerFCMToken(_ registration: FCMTokenRegistration) async throws {}

    func unregisterFCMToken(deviceID: String) async throws {}

    func fetchNotifications(
        cursor: String?,
        size: Int
    ) async throws -> MaplogNotificationPage {
        requestedCursors.append(cursor)

        guard !results.isEmpty else {
            return MaplogNotificationPage(
                notifications: [],
                hasNext: false,
                nextCursor: nil
            )
        }

        return try results.removeFirst().get()
    }
}
