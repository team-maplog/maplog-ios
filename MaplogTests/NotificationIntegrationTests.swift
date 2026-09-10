import Foundation
import XCTest
@testable import Maplog

@MainActor
final class NotificationIntegrationTests: XCTestCase {
    func testSignOutUnregistersBeforeServerLogoutAndSessionDeletion() async {
        let events = Events()
        let session = SessionStub(events: events)
        let repository = PushRepositoryStub(events: events)
        let store = TokenStoreStub()
        let coordinator = makeCoordinator(repository, session, store)
        let model = SignOutViewModel(
            authRepository: AuthStub(events: events), authSessionStore: session, pushSession: coordinator
        )
        await model.signOut()
        XCTAssertEqual(events.values, ["unregister", "logout", "endSession"])
        XCTAssertFalse(session.isAuthenticated)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(store.token, "test-fcm")

        session.isAuthenticated = true
        await coordinator.syncCachedTokenIfAuthenticated()
        XCTAssertEqual(repository.registrations.last?.fcmToken, "test-fcm")
    }

    func testUnregisterFailurePreservesSessionAndDoesNotCallServerLogout() async {
        let events = Events()
        let session = SessionStub(events: events)
        let repository = PushRepositoryStub(events: events)
        repository.unregisterError = URLError(.notConnectedToInternet)
        let model = SignOutViewModel(
            authRepository: AuthStub(events: events), authSessionStore: session,
            pushSession: makeCoordinator(repository, session, TokenStoreStub())
        )
        await model.signOut()
        XCTAssertFalse(events.values.contains("logout"))
        XCTAssertTrue(session.isAuthenticated)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(model.recoveryAction, .retry)
    }

    func testServerLogoutFailureRegistersDeviceAgain() async {
        let events = Events()
        let session = SessionStub(events: events)
        let repository = PushRepositoryStub(events: events)
        let auth = AuthStub(events: events)
        auth.error = URLError(.notConnectedToInternet)
        let model = SignOutViewModel(
            authRepository: auth, authSessionStore: session,
            pushSession: makeCoordinator(repository, session, TokenStoreStub())
        )
        await model.signOut()
        XCTAssertEqual(events.values, ["unregister", "logout", "register"])
        XCTAssertTrue(session.isAuthenticated)
        XCTAssertNotNil(model.errorMessage)
    }

    func testSignOutWaitsForRegistrationAndSuppressesTokenRefreshUntilLogout() async {
        let events = Events()
        let session = SessionStub(events: events)
        let repository = PushRepositoryStub(events: events)
        repository.holdsRegistration = true
        let store = TokenStoreStub()
        let coordinator = makeCoordinator(repository, session, store)
        let registration = Task { await coordinator.syncCachedTokenIfAuthenticated() }
        while repository.pendingRegistration == nil { await Task.yield() }
        let logout = Task { try await coordinator.prepareForSignOut() }
        await Task.yield()
        await coordinator.receiveFCMRegistrationToken("new-test-fcm")
        XCTAssertEqual(events.values, ["register"])
        repository.pendingRegistration?.resume()
        repository.pendingRegistration = nil
        await registration.value
        do { try await logout.value } catch { XCTFail("Unexpected signout failure") }
        XCTAssertEqual(events.values, ["register", "unregister"])
        XCTAssertEqual(store.token, "new-test-fcm")
        session.isAuthenticated = false
        await coordinator.resumeAfterSignOutAttempt()
        XCTAssertEqual(repository.registrations.count, 1)
    }

    func testPayloadRoutesCommentsAndProfilesAndFallsBackForInvalidValues() {
        let events = Events()
        var routes: [MaplogNotificationDestination] = []
        let coordinator = PushNotificationCoordinator(
            notificationRepository: PushRepositoryStub(events: events),
            authenticationState: SessionStub(events: events), tokenStore: TokenStoreStub(),
            onNavigate: { routes.append($0) }
        )
        let userID = UUID()
        coordinator.handleRemoteNotification(userInfo: ["route": "LOG_DETAIL", "logId": "12", "commentId": "34"])
        coordinator.handleRemoteNotification(userInfo: ["data": ["route": "USER_PROFILE", "actorUserId": userID.uuidString]])
        coordinator.handleRemoteNotification(userInfo: ["route": "LOG_DETAIL", "logId": "-1"])
        coordinator.handleRemoteNotification(userInfo: ["route": "LOG_DETAIL", "logId": "12", "commentId": "bad"])
        coordinator.handleRemoteNotification(userInfo: ["schemaVersion": "2", "route": "LOG_DETAIL", "logId": "12"])
        coordinator.handleRemoteNotification(userInfo: [:])
        XCTAssertEqual(routes, [.logDetail(logID: 12, commentID: 34), .userProfile(userID: userID), .inbox, .inbox, .inbox, .inbox])
    }

    func testProfileResolutionUsesNextPageAndMatchingActorID() async {
        let events = Events()
        let repository = PushRepositoryStub(events: events)
        let id = UUID()
        repository.pages = [
            MaplogNotificationPage(notifications: [notification(actorID: UUID())], hasNext: true, nextCursor: "next"),
            MaplogNotificationPage(notifications: [notification(actorID: id)], hasNext: false, nextCursor: nil)
        ]
        let model = NotificationProfileViewModel(userID: id, repository: repository)
        await model.load()
        guard case let .content(user) = model.state else { return XCTFail("Expected resolved profile") }
        XCTAssertEqual(user.id, id)
        XCTAssertEqual(user.nickname, "여행자")
        XCTAssertEqual(repository.cursors, [nil, "next"])
    }

    func testProfileResolutionStopsForRepeatedCursorAndCanRetry() async {
        let repository = PushRepositoryStub(events: Events())
        repository.pages = Array(repeating: MaplogNotificationPage(notifications: [], hasNext: true, nextCursor: "same"), count: 2)
        let id = UUID()
        let model = NotificationProfileViewModel(userID: id, repository: repository)
        await model.load()
        guard case let .failed(error) = model.state else { return XCTFail("Expected cursor error") }
        XCTAssertEqual(error.recoveryAction, .retry)
        XCTAssertEqual(repository.cursors.count, 2)
        repository.pages = [MaplogNotificationPage(notifications: [notification(actorID: id)], hasNext: false, nextCursor: nil)]
        await model.load()
        guard case .content = model.state else { return XCTFail("Expected retry success") }
    }

    func testMissingProfileShowsUnavailableState() async {
        let repository = PushRepositoryStub(events: Events())
        let model = NotificationProfileViewModel(userID: UUID(), repository: repository)
        await model.load()
        guard case let .failed(error) = model.state else { return XCTFail("Expected unavailable profile") }
        XCTAssertEqual(error.recoveryAction, ErrorPresentation.RecoveryAction.none)
    }

    private func makeCoordinator(_ repository: PushRepositoryStub, _ session: SessionStub, _ store: TokenStoreStub) -> PushNotificationCoordinator {
        PushNotificationCoordinator(notificationRepository: repository, authenticationState: session, tokenStore: store, onNavigate: { _ in })
    }

    private func notification(actorID: UUID) -> MaplogNotification {
        MaplogNotification(id: UUID().uuidString, kind: .follow, title: "팔로우", message: "", actor: MaplogNotificationActor(id: actorID, nickname: "여행자", profileImageURL: nil), createdAt: nil, isRead: false, destination: .userProfile(userID: actorID))
    }
}

private final class Events { var values: [String] = [] }

@MainActor
private final class SessionStub: AuthSessionManaging, AuthenticationStateProviding {
    var isAuthenticated = true
    let events: Events
    init(events: Events) { self.events = events }
    func startSession(with token: AuthToken) throws { isAuthenticated = true }
    func replaceTokens(with token: AuthToken) throws {}
    func endSession() throws { events.values.append("endSession"); isAuthenticated = false }
    func currentAccessToken() throws -> String? { nil }
    func currentRefreshToken() throws -> String? { nil }
}

private final class TokenStoreStub: PushNotificationTokenStoring {
    var token: String? = "test-fcm"
    func deviceID() throws -> String { "test-device" }
    func fcmToken() throws -> String? { token }
    func saveFCMToken(_ token: String) throws { self.token = token }
    func removeFCMToken() throws { token = nil }
}

private final class PushRepositoryStub: NotificationRepository {
    let events: Events
    var registrations: [FCMTokenRegistration] = []
    var unregisterError: Error?
    var holdsRegistration = false
    var pendingRegistration: CheckedContinuation<Void, Never>?
    var pages: [MaplogNotificationPage] = []
    var cursors: [String?] = []
    init(events: Events) { self.events = events }
    func registerFCMToken(_ registration: FCMTokenRegistration) async throws {
        registrations.append(registration)
        events.values.append("register")
        if holdsRegistration { await withCheckedContinuation { pendingRegistration = $0 } }
    }
    func unregisterFCMToken(deviceID: String) async throws {
        events.values.append("unregister")
        if let unregisterError { throw unregisterError }
    }
    func fetchNotifications(cursor: String?, size: Int) async throws -> MaplogNotificationPage {
        cursors.append(cursor)
        return pages.isEmpty ? MaplogNotificationPage(notifications: [], hasNext: false, nextCursor: nil) : pages.removeFirst()
    }
}

private final class AuthStub: AuthRepository {
    let events: Events
    var error: Error?
    init(events: Events) { self.events = events }
    func signOut() async throws { events.values.append("logout"); if let error { throw error } }
    func signIn(credentials: SignInCredentials) async throws -> AuthToken { throw APIError.missingAccessToken }
    func signUp(credentials: SignUpCredentials) async throws -> AuthToken { throw APIError.missingAccessToken }
    func reissueToken() async throws -> AuthToken { throw APIError.missingAccessToken }
}
