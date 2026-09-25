import XCTest
@testable import Maplog

@MainActor
final class SocialConnectionsViewModelTests: XCTestCase {
    func testDisconnectRemovesAccountAfterSuccess() async {
        let repository = SocialConnectionRepositoryStub()
        let viewModel = SocialConnectionsViewModel(repository: repository)
        await viewModel.load()
        await viewModel.disconnect(viewModel.connections[0])
        XCTAssertTrue(viewModel.connections.isEmpty)
        XCTAssertEqual(repository.disconnectedProvider, "google")
        XCTAssertNil(viewModel.disconnectingProvider)
    }

    func testLastLoginMethodErrorKeepsAccountAndExplainsReason() async {
        let repository = SocialConnectionRepositoryStub()
        repository.disconnectFailure = APIError.server(statusCode: 400, response: APIErrorResponse(successFlag: false, code: "OAUTH-008", message: "server text", data: nil))
        let viewModel = SocialConnectionsViewModel(repository: repository)
        await viewModel.load()
        await viewModel.disconnect(viewModel.connections[0])
        XCTAssertEqual(viewModel.connections.count, 1)
        XCTAssertEqual(viewModel.disconnectError?.recoveryAction, ErrorPresentation.RecoveryAction.none)
        XCTAssertTrue(viewModel.disconnectError?.message.contains("마지막 로그인") == true)
    }

    func testProviderRevokeFailureCanRetry() {
        let error = APIError.server(statusCode: 502, response: APIErrorResponse(successFlag: false, code: "OAUTH-007", message: "server text", data: nil))
        XCTAssertEqual(SocialConnectionErrorPolicy.disconnectPresentation(for: error).recoveryAction, .retry)
    }

    func testLoadsConnectedAccounts() async {
        let repository = SocialConnectionRepositoryStub()
        let viewModel = SocialConnectionsViewModel(repository: repository)
        await viewModel.load()
        XCTAssertEqual(viewModel.connections.first?.provider, "google")
        XCTAssertTrue(viewModel.hasLoaded)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testRefreshFailureKeepsExistingAccountsAndCanRetry() async {
        let repository = SocialConnectionRepositoryStub()
        let viewModel = SocialConnectionsViewModel(repository: repository)
        await viewModel.load()
        repository.shouldFail = true
        await viewModel.load()
        XCTAssertEqual(viewModel.connections.count, 1)
        XCTAssertEqual(viewModel.error?.recoveryAction, .retry)
        repository.shouldFail = false
        await viewModel.load()
        XCTAssertNil(viewModel.error)
    }

    func testEmptyListIsLoadedState() async {
        let repository = SocialConnectionRepositoryStub()
        repository.items = []
        let viewModel = SocialConnectionsViewModel(repository: repository)
        await viewModel.load()
        XCTAssertTrue(viewModel.hasLoaded)
        XCTAssertTrue(viewModel.connections.isEmpty)
    }
}

private final class SocialConnectionRepositoryStub: SocialConnectionRepository {
    func connectionRedirectURL(provider: String) async throws -> URL {
        throw APIError.invalidResponse
    }

    var disconnectFailure: Error?
    var disconnectedProvider: String?
    func disconnect(provider: String) async throws {
        if let disconnectFailure { throw disconnectFailure }
        disconnectedProvider = provider
    }
    var shouldFail = false
    var items = [SocialConnection(provider: "google", isConnected: true, createdAt: nil, updatedAt: nil)]
    func fetchConnections() async throws -> [SocialConnection] {
        if shouldFail { throw APIError.invalidResponse }
        return items
    }
}
