import XCTest
@testable import Maplog

@MainActor
final class SocialConnectionsViewModelTests: XCTestCase {
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
    var shouldFail = false
    var items = [SocialConnection(provider: "google", isConnected: true, createdAt: nil, updatedAt: nil)]
    func fetchConnections() async throws -> [SocialConnection] {
        if shouldFail { throw APIError.invalidResponse }
        return items
    }
}
