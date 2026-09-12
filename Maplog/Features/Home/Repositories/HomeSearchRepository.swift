import Foundation

protocol HomeSearchRepository {
    func search(
        request: HomeSearchRequest
    ) async throws -> HomeSearchPage
}
